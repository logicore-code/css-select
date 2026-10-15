// Integration tests: parse a selector and match it against a small DOM tree.

// Build the fixture tree:
//
// div#root.container
//   h1.title
//   ul#nav
//     li.item.active
//     li.item
//     li.item
//   p.content
//     a[href="/home"]
fn build_tree() -> DomNode {
  let root = DomNode::new("div").set("id", "root").set("class", "container")
  let h1 = DomNode::new("h1").set("class", "title")
  let ul = DomNode::new("ul").set("id", "nav")
  let li1 = DomNode::new("li").set("class", "item active")
  let li2 = DomNode::new("li").set("class", "item")
  let li3 = DomNode::new("li").set("class", "item")
  let p = DomNode::new("p").set("class", "content")
  let a = DomNode::new("a").set("href", "/home")
  let _ = root.append(h1)
  let _ = root.append(ul)
  let _ = ul.append(li1)
  let _ = ul.append(li2)
  let _ = ul.append(li3)
  let _ = root.append(p)
  let _ = p.append(a)
  root
}

/// Parse `sel` and return true if `node` matches.
fn matches(sel : String, node : DomNode) -> Bool {
  match parse_selectors(sel) {
    Err(_) => false
    Ok(list) => matches_list(node, list)
  }
}

test "type and id" {
  let root = build_tree()
  assert_true(matches("div", root))
  assert_true(matches("#root", root))
  assert_true(matches("div#root", root))
  assert_true(!matches("span", root))
}

test "class selector" {
  let root = build_tree()
  let h1 = root.child_at(0)
  assert_true(matches(".title", h1))
  assert_true(matches("h1.title", h1))
}

test "descendant combinator" {
  let root = build_tree()
  let li1 = root.child_at(1).child_at(0)
  assert_true(matches("ul li", li1))
  assert_true(matches("#nav .item", li1))
  assert_true(!matches("div > li", li1))
}

test "child combinator" {
  let root = build_tree()
  let li1 = root.child_at(1).child_at(0)
  assert_true(matches("ul > li", li1))
  assert_true(!matches("div > li", li1))
}

test "class and attribute" {
  let root = build_tree()
  let li1 = root.child_at(1).child_at(0)
  assert_true(matches("li.item.active", li1))
  assert_true(!matches("li.item.active", root.child_at(1).child_at(1)))
  let a = root.child_at(2).child_at(0)
  assert_true(matches("a[href='/home']", a))
  assert_true(matches("a[href^='/']", a))
  assert_true(!matches("a[href='/about']", a))
}

test "nth-child" {
  let root = build_tree()
  let li1 = root.child_at(1).child_at(0)
  let li2 = root.child_at(1).child_at(1)
  let li3 = root.child_at(1).child_at(2)
  assert_true(matches("li:nth-child(1)", li1))
  assert_true(matches("li:first-child", li1))
  assert_true(!matches("li:nth-child(1)", li2))
  assert_true(matches("li:nth-child(odd)", li1))
  assert_true(!matches("li:nth-child(odd)", li2))
  assert_true(matches("li:nth-child(odd)", li3))
  assert_true(matches("li:last-child", li3))
}

test "not and is" {
  let root = build_tree()
  let li1 = root.child_at(1).child_at(0)
  assert_true(matches("li:not(.active)", root.child_at(1).child_at(1)))
  assert_true(!matches("li:not(.active)", li1))
  assert_true(matches("li:is(.active, .x)", li1))
}

test "adjacent and general sibling" {
  let root = build_tree()
  let li2 = root.child_at(1).child_at(1)
  let li3 = root.child_at(1).child_at(2)
  // .item + .item matches li2 and li3 (each preceded by an .item).
  assert_true(matches("li.item + li.item", li2))
  assert_true(matches("li.item + li.item", li3))
  assert_true(!matches("li.item + li.item", root.child_at(1).child_at(0)))
}

test "universal" {
  let root = build_tree()
  assert_true(matches("*", root))
  assert_true(matches("div *", root.child_at(1).child_at(0)))
}

test "error selector returns false" {
  let root = build_tree()
  assert_true(!matches("div >", root))
  assert_true(!matches("", root))
}

test "attribute contains and prefix" {
  let root = build_tree()
  let a = root.child_at(2).child_at(0)
  assert_true(matches("a[href^='/']", a))
  assert_true(matches("a[href$='home']", a))
  assert_true(matches("a[href*='hom']", a))
}

test "nth-child even and negative" {
  let root = build_tree()
  let li2 = root.child_at(1).child_at(1)
  assert_true(matches("li:nth-child(even)", li2))
  assert_true(!matches("li:nth-child(even)", root.child_at(1).child_at(0)))
}

test "general sibling" {
  let root = build_tree()
  let li3 = root.child_at(1).child_at(2)
  assert_true(matches("li.item ~ li.item", li3))
}

test "root and empty pseudo" {
  let root = build_tree()
  assert_true(matches(":root", root))
  let a = root.child_at(2).child_at(0)
  assert_true(matches(":empty", a))
}
