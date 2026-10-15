// SelectableNode implementation for DomNode.

impl SelectableNode for DomNode with fn ty(self) {
  self.tag
}

impl SelectableNode for DomNode with fn get_attr(self, name : String) {
  self.attrs.get(name)
}

impl SelectableNode for DomNode with fn parent(self) {
  self.parent_node
}

impl SelectableNode for DomNode with fn children(self) {
  self.child_nodes
}

impl SelectableNode for DomNode with fn sibling_index(self) {
  self.sibling_idx
}

impl SelectableNode for DomNode with fn type_sibling_index(self) {
  self.type_idx
}
