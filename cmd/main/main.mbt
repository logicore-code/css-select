// css-select CLI: match a CSS selector against an indented element tree.
//
// Usage:
//   moon run cmd/main -- "ul li.item.active" "div#root\n  ul#nav\n    li.item.active"

fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("usage: css-select <selector> [tree-as-string]")
    return
  }
  let selector = args[1]
  let tree_text =
    if args.length() >= 3 {
      args[2]
    } else {
      "div#root.container\n  h1.title\n  ul#nav\n    li.item.active\n    li.item\n    li.item\n  p.content\n    a[href=/home]"
    }

  match @lib.parse_selectors(selector) {
    Err(e) => eprintln("selector parse error: \{e.message}")
    Ok(list) => {
      let root = parse_tree(tree_text)
      let matched = collect_matches(root, list)
      println("selector: \{selector}")
      println("matches: \{matched.length()}")
      for m in matched {
        println("  - \{m}")
      }
    }
  }
}

fn parse_tree(text : String) -> @lib.DomNode {
  let lines = text.split("\n")
  let stack : Array[(Int, @lib.DomNode)] = []
  let mut root : @lib.DomNode? = None
  for line in lines {
    let trimmed = line.trim()
    if trimmed == "" {
      continue
    }
    let indent = line.length() - trimmed.length()
    let node = parse_element_line(String::from_array(trimmed.to_array()))
    while stack.length() > 0 && stack[stack.length() - 1].0 >= indent {
      let _ = stack.pop()
    }
    if stack.length() == 0 {
      root = Some(node)
    } else {
      let parent = stack[stack.length() - 1].1
      let _ = parent.append(node)
    }
    stack.push((indent, node))
  }
  match root {
    None => @lib.DomNode::new("div")
    Some(r) => r
  }
}

fn parse_element_line(s : String) -> @lib.DomNode {
  let chars = s.to_array()
  let n = chars.length()
  let mut tag_end = 0
  while tag_end < n {
    let c = chars[tag_end]
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' {
      tag_end += 1
    } else {
      break
    }
  }
  let tag = if tag_end == 0 { "div" } else { s.substring(start=0, end=tag_end) }
  let node = @lib.DomNode::new(tag)
  let classes : Array[String] = []
  let mut i = tag_end
  while i < n {
    let c = chars[i]
    if c == '#' {
      let mut j = i + 1
      while j < n && chars[j] != '#' && chars[j] != '.' && chars[j] != '[' {
        j += 1
      }
      let _ = node.set("id", s.substring(start=i + 1, end=j))
      i = j
    } else if c == '.' {
      let mut j = i + 1
      while j < n && chars[j] != '#' && chars[j] != '.' && chars[j] != '[' {
        j += 1
      }
      classes.push(s.substring(start=i + 1, end=j))
      i = j
    } else if c == '[' {
      // Find closing ] by scanning chars.
      let mut close = i + 1
      while close < n && chars[close] != ']' {
        close += 1
      }
      if close < n {
        // Inside is s[i+1:close], look for '='.
        let mut eq_pos = i + 1
        while eq_pos < close && chars[eq_pos] != '=' {
          eq_pos += 1
        }
        if eq_pos < close {
          let name = s.substring(start=i + 1, end=eq_pos)
          let value = s.substring(start=eq_pos + 1, end=close).trim()
          let _ = node.set(name, String::from_array(value.to_array()))
        }
      }
      i = close + 1
    } else {
      i += 1
    }
  }
  if classes.length() > 0 {
    let sb = StringBuilder::new()
    for idx in 0..<classes.length() {
      if idx > 0 {
        sb.write_char(' ')
      }
      sb.write_string(classes[idx])
    }
    let _ = node.set("class", sb.to_string())
  }
  node
}

fn collect_matches(node : @lib.DomNode, list : @lib.SelectorList) -> Array[String] {
  let out : Array[String] = []
  if @lib.matches_list(node, list) {
    out.push(node.ty())
  }
  let mut i = 0
  while i < node.child_count() {
    let sub = collect_matches(node.child_at(i), list)
    for s in sub {
      out.push(s)
    }
    i += 1
  }
  out
}
