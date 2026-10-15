// A tiny in-memory DOM tree used for tests, examples, and as a reference
// implementation of `SelectableNode`. It is intentionally minimal: users can
// implement `SelectableNode` against their own tree (e.g. an HTML parser or a
// WASM DOM wrapper).

/// A single element node in a minimal DOM tree.
pub struct DomNode {
  tag : String
  attrs : Map[String, String]
  mut parent_node : DomNode?
  child_nodes : Array[DomNode]
  mut sibling_idx : Int
  mut type_idx : Int
}

pub fn DomNode::new(tag : String) -> DomNode {
  {
    tag: tag.to_lower(),
    attrs: Map([], capacity=4),
    parent_node: None,
    child_nodes: [],
    sibling_idx: 0,
    type_idx: 0,
  }
}

pub fn DomNode::set(self : DomNode, name : String, value : String) -> DomNode {
  self.attrs[name.to_lower()] = value
  self
}

pub fn DomNode::append(self : DomNode, child : DomNode) -> DomNode {
  child.parent_node = Some(self)
  child.sibling_idx = self.child_nodes.length()
  let mut same_type = 0
  for c in self.child_nodes {
    if c.tag == child.tag {
      same_type += 1
    }
  }
  child.type_idx = same_type
  self.child_nodes.push(child)
  self
}

pub fn DomNode::child_at(self : DomNode, i : Int) -> DomNode { self.child_nodes[i] }

pub fn DomNode::child_count(self : DomNode) -> Int { self.child_nodes.length() }
