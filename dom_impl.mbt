// SelectableNode implementation for DomNode.

pub impl SelectableNode for DomNode with fn ty(self : DomNode) -> String {
  self.tag
}

pub impl SelectableNode for DomNode with fn get_attr(self : DomNode, name : String) -> String? {
  self.attrs.get(name)
}

pub impl SelectableNode for DomNode with fn parent(self : DomNode) -> DomNode? {
  self.parent_node
}

pub impl SelectableNode for DomNode with fn children(self : DomNode) -> Array[DomNode] {
  self.child_nodes
}

pub impl SelectableNode for DomNode with fn sibling_index(self : DomNode) -> Int {
  self.sibling_idx
}

pub impl SelectableNode for DomNode with fn type_sibling_index(self : DomNode) -> Int {
  self.type_idx
}
