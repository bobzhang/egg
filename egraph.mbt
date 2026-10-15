///|
/// Finds a representative, compressing the path. Existing IDs remain valid.
pub fn[Op] EGraph::find(self : EGraph[Op], id : Int32) -> Int32 {
  guard id >= 0 && id < self.leaders.length() else {
    abort("invalid e-class ID")
  }
  let mut current = id
  while self.leaders[current] != current {
    let parent = self.leaders[current]
    self.leaders[current] = self.leaders[parent]
    current = self.leaders[current]
  }
  current
}

///|
fn[Op] EGraph::canonical(self : EGraph[Op], node : Node[Op]) -> Node[Op] {
  Node(node.op, children=node.children.map(id => self.find(id)))
}

///|
pub fn[Op : Eq + Hash] EGraph::add(self : EGraph[Op], node : Node[Op]) -> Int32 {
  let node = self.canonical(node)
  if self.memo.get(node) is Some(id) {
    return self.find(id)
  }
  let id = self.nodes.length()
  self.nodes.push(node)
  self.leaders.push(id)
  self.classes.push({ members: [id], parents: [], })
  for child in node.children {
    self.classes[child].parents.push(id)
  }
  self.memo[node] = id
  self.clean = false
  self.revision += 1
  id
}

///|
pub fn[Op : Eq + Hash] EGraph::add_expr(
  self : EGraph[Op],
  expr : Expr[Op],
) -> Int32 {
  let mapped = []
  for node in expr.nodes {
    mapped.push(
      self.add(
        Node(node.op, children=node.children.map(child => mapped[child])),
      ),
    )
  }
  mapped[expr.root()]
}

///|
/// Union classes, deferring parent congruences until rebuild.
/// Returns false when both IDs already denote the same class.
pub fn[Op] EGraph::union(
  self : EGraph[Op],
  left : Int32,
  right : Int32,
) -> Bool {
  let mut a = self.find(left)
  let mut b = self.find(right)
  if a == b {
    return false
  }
  // As in egg, move the smaller parent list to reduce repair work.
  if self.classes[a].parents.length() < self.classes[b].parents.length() {
    let swap = a
    a = b
    b = swap
  }
  self.leaders[b] = a
  for parent in self.classes[b].parents {
    self.pending.push(parent)
  }
  for node_id in self.classes[b].members {
    self.classes[a].members.push(node_id)
  }
  for parent in self.classes[b].parents {
    self.classes[a].parents.push(parent)
  }
  self.classes[b].members.clear()
  self.classes[b].parents.clear()
  self.clean = false
  self.revision += 1
  true
}

///|
/// Restores congruence and hash-cons uniqueness. Returns extra congruence unions.
pub fn[Op : Eq + Hash] EGraph::rebuild(self : EGraph[Op]) -> Int32 {
  let mut unions = 0
  while self.pending.pop() is Some(id) {
    let node = self.canonical(self.nodes[id])
    if self.memo.get(node) is Some(other) {
      if self.union(id, other) {
        unions += 1
      }
    }
    self.memo[node] = self.find(id)
  }
  // Drop stale noncanonical keys so edits do not retain obsolete hash entries.
  self.memo.clear()
  for id, original in self.nodes {
    self.memo[self.canonical(original)] = self.find(id)
  }
  self.clean = true
  unions
}

///|
pub fn[Op : Eq + Hash] EGraph::lookup(
  self : EGraph[Op],
  node : Node[Op],
) -> Int32? {
  self.require_clean()
  self.memo.get(self.canonical(node)).map(id => self.find(id))
}

///|
pub fn[Op : Eq + Hash] EGraph::lookup_expr(
  self : EGraph[Op],
  expr : Expr[Op],
) -> Int32? {
  self.require_clean()
  let mapped = []
  for node in expr.nodes {
    match
      self.lookup(
        Node(node.op, children=node.children.map(child => mapped[child])),
      ) {
      None => return None
      Some(id) => mapped.push(id)
    }
  }
  Some(mapped[expr.root()])
}

///|
pub fn[Op] EGraph::class_ids(self : EGraph[Op]) -> Array[Int32] {
  self.require_clean()
  let result = []
  for id in 0..<self.leaders.length() {
    if self.find(id) == id {
      result.push(id)
    }
  }
  result
}

///|
pub fn[Op] EGraph::number_of_classes(self : EGraph[Op]) -> Int32 {
  self.class_ids().length()
}

///|
/// Number of distinct canonical e-nodes after rebuild.
pub fn[Op] EGraph::total_size(self : EGraph[Op]) -> Int32 {
  self.require_clean()
  self.memo.length()
}

///|
/// Returns detached, canonicalized nodes, deduplicated within the class.
pub fn[Op : Eq + Hash] EGraph::class_nodes(
  self : EGraph[Op],
  id : Int32,
) -> Array[Node[Op]] {
  self.require_clean()
  let result = []
  let seen : Map[Node[Op], Bool] = Map([])
  for node_id in self.classes[self.find(id)].members {
    let node = self.canonical(self.nodes[node_id])
    if !seen.contains(node) {
      seen[node] = true
      result.push(node)
    }
  }
  result
}
