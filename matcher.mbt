// Matching engine: test a node against a parsed selector.
//
// The matcher is generic over any tree that implements `SelectableNode`, so it
// works against the bundled demo DOM or against the user's own tree (e.g. a
// WASM DOM wrapper, an HTML parser's node, a test fixture).

/// Trait a document node must implement to be matched against selectors.
///
/// All implementations should treat element tag names as already lowercased
/// (HTML matching is case-insensitive); the matcher compares them verbatim.
pub trait SelectableNode {
  /// Local/tag name of the element, e.g. `"div"`.
  fn ty(Self) -> String
  /// Look up an attribute by name (already lowercased by the caller).
  fn get_attr(Self, String) -> String?
  /// Parent element, if any.
  fn parent(Self) -> Self?
  /// Element children, in document order.
  fn children(Self) -> Array[Self]
  /// 0-based position among the parent's element children.
  fn sibling_index(Self) -> Int
  /// 0-based position among the parent's element children with the same tag.
  fn type_sibling_index(Self) -> Int
}

// Public entry points ----------------------------------------------------------------

/// Does `node` match any complex selector in the list?
pub fn[T : SelectableNode] matches_list(node : T, list : SelectorList) -> Bool {
  for sel in list {
    if matches(node, sel) {
      return true
    }
  }
  false
}

/// Collect all nodes in the subtree rooted at `root` that match the selector list.
pub fn[T : SelectableNode] query_all(root : T, list : SelectorList) -> Array[T] {
  let out : Array[T] = []
  query_walk(root, list, out)
  out
}

fn[T : SelectableNode] query_walk(node : T, list : SelectorList, out : Array[T]) -> Unit {
  if matches_list(node, list) {
    out.push(node)
  }
  for c in node.children() {
    query_walk(c, list, out)
  }
}

/// Does `node` match this single complex selector?
pub fn[T : SelectableNode] matches(node : T, complex : ComplexSelector) -> Bool {
  if !matches_compound(node, complex.subject) {
    return false
  }
  // Walk ancestor constraints, closest first.
  let mut current : T = node
  for (comb, target) in complex.ancestors {
    match comb {
      Descendant => {
        match find_descendant_ancestor(current, target) {
          None => return false
          Some(next) => current = next
        }
      }
      Child => {
        match current.parent() {
          None => return false
          Some(p) => {
            if !matches_compound(p, target) {
              return false
            }
            current = p
          }
        }
      }
      AdjacentSibling => {
        match prev_sibling(current) {
          None => return false
          Some(s) => {
            if !matches_compound(s, target) {
              return false
            }
            current = s
          }
        }
      }
      GeneralSibling => {
        match find_prev_sibling(current, target) {
          None => return false
          Some(s) => current = s
        }
      }
    }
  }
  true
}

// Compound matching ------------------------------------------------------------------

fn[T : SelectableNode] matches_compound(node : T, compound : CompoundSelector) -> Bool {
  for simple in compound.simples {
    if !matches_simple(node, simple) {
      return false
    }
  }
  true
}

fn[T : SelectableNode] matches_simple(node : T, simple : SimpleSelector) -> Bool {
  match simple {
    Type(name) => node.ty() == name.to_lower()
    Universal => true
    Class(name) => {
      // Class attribute is a whitespace-separated list.
      match node.get_attr("class") {
        None => false
        Some(cls) => has_whitespace_token(cls, name)
      }
    }
    Id(name) => {
      match node.get_attr("id") {
        None => false
        Some(id) => id == name
      }
    }
    Attr(a) => matches_attr(node, a)
    Pseudo(p) => matches_pseudo(node, p)
  }
}

fn[T : SelectableNode] matches_attr(node : T, a : AttributeSelector) -> Bool {
  let actual = node.get_attr(a.name.to_lower())
  match a.op {
    Exists => actual.is_some()
    Equals => {
      match actual {
        None => false
        Some(v) => attr_eq(v, a.value, a.icase)
      }
    }
    Includes => {
      match actual {
        None => false
        Some(v) => has_whitespace_token(v, a.value)
      }
    }
    DashMatch => {
      match actual {
        None => false
        Some(v) => {
          if attr_eq(v, a.value, a.icase) {
            true
          } else {
            v.starts_with(a.value + "-")
          }
        }
      }
    }
    Prefix => {
      match actual {
        None => false
        Some(v) => {
          if a.icase {
            v.to_lower().starts_with(a.value.to_lower())
          } else {
            v.starts_with(a.value)
          }
        }
      }
    }
    Suffix => {
      match actual {
        None => false
        Some(v) => {
          if a.icase {
            v.to_lower().ends_with(a.value.to_lower())
          } else {
            v.ends_with(a.value)
          }
        }
      }
    }
    Substring => {
      match actual {
        None => false
        Some(v) => {
          if a.icase {
            v.to_lower().contains(a.value.to_lower())
          } else {
            v.contains(a.value)
          }
        }
      }
    }
  }
}

fn attr_eq(actual : String, expected : String, icase : Bool) -> Bool {
  if icase {
    actual.to_lower() == expected.to_lower()
  } else {
    actual == expected
  }
}

/// Does `s` contain `tok` as a whitespace-separated token?
fn has_whitespace_token(s : String, tok : String) -> Bool {
  for part in s.split(" ") {
    if part == tok {
      return true
    }
  }
  false
}

// Pseudo-class matching ----------------------------------------------------------------

fn[T : SelectableNode] matches_pseudo(node : T, p : PseudoClass) -> Bool {
  match p {
    Root => node.parent().is_none()
    Empty => {
      // No element children.
      node.children().length() == 0
    }
    FirstChild => node.sibling_index() == 0
    LastChild => {
      match node.parent() {
        None => true
        Some(parent) => node.sibling_index() == parent.children().length() - 1
      }
    }
    OnlyChild => {
      match node.parent() {
        None => true
        Some(parent) => parent.children().length() == 1
      }
    }
    FirstOfType => node.type_sibling_index() == 0
    LastOfType => {
      match node.parent() {
        None => true
        Some(parent) => {
          let ty = node.ty()
          let mut count = 0
          for c in parent.children() {
            if c.ty() == ty {
              count += 1
            }
          }
          node.type_sibling_index() == count - 1
        }
      }
    }
    OnlyOfType => {
      match node.parent() {
        None => true
        Some(parent) => {
          let ty = node.ty()
          let mut count = 0
          for c in parent.children() {
            if c.ty() == ty {
              count += 1
            }
          }
          count == 1
        }
      }
    }
    NthChild(n) => nth_match(node.sibling_index(), n)
    NthLastChild(n) => {
      match node.parent() {
        None => false
        Some(parent) => {
          let idx_from_end = parent.children().length() - 1 - node.sibling_index()
          nth_match(idx_from_end, n)
        }
      }
    }
    NthOfType(n) => nth_match(node.type_sibling_index(), n)
    NthLastOfType(n) => {
      match node.parent() {
        None => false
        Some(parent) => {
          let ty = node.ty()
          let mut count = 0
          for c in parent.children() {
            if c.ty() == ty {
              count += 1
            }
          }
          let idx_from_end = count - 1 - node.type_sibling_index()
          nth_match(idx_from_end, n)
        }
      }
    }
    Enabled => {
      match node.get_attr("disabled") {
        None => true
        Some(_) => false
      }
    }
    Disabled => node.get_attr("disabled").is_some()
    Checked => {
      node.get_attr("checked").is_some() || node.get_attr("selected").is_some()
    }
    Focus => node.get_attr("data-focus").is_some()
    Hover => node.get_attr("data-hover").is_some()
    Lang(want) => {
      match node.get_attr("lang") {
        None => false
        Some(have) => {
          let have_l = have.to_lower()
          have_l == want || have_l.starts_with(want + "-")
        }
      }
    }
    Not(selectors) => !matches_list(node, selectors)
    Is(selectors) => matches_list(node, selectors)
  }
}

/// Does 0-based `i` satisfy `a*n + b` for some n >= 0?
fn nth_match(i : Int, n : Nth) -> Bool {
  // 1-based position = i + 1.
  let pos = i + 1
  if n.a == 0 {
    return pos == n.b
  }
  // pos = a*k + b  =>  (pos - b) must be non-negative and divisible by a.
  let diff = pos - n.b
  let step = if n.a < 0 { -n.a } else { n.a }
  if diff < 0 {
    return false
  }
  diff % step == 0
}

// Tree walking helpers ----------------------------------------------------------------

fn[T : SelectableNode] find_descendant_ancestor(node : T, target : CompoundSelector) -> T? {
  let mut cur = node.parent()
  while cur.is_some() {
    let p = cur.unwrap()
    if matches_compound(p, target) {
      return Some(p)
    }
    cur = p.parent()
  }
  None
}

fn[T : SelectableNode] prev_sibling(node : T) -> T? {
  let idx = node.sibling_index()
  if idx == 0 {
    return None
  }
  match node.parent() {
    None => None
    Some(parent) => Some(parent.children()[idx - 1])
  }
}

fn[T : SelectableNode] find_prev_sibling(node : T, target : CompoundSelector) -> T? {
  match node.parent() {
    None => None
    Some(parent) => {
      let kids = parent.children()
      let mut i = node.sibling_index() - 1
      while i >= 0 {
        if matches_compound(kids[i], target) {
          return Some(kids[i])
        }
        i -= 1
      }
      None
    }
  }
}
