///|
/// An operator with ordered child IDs. Operators must be immutable map keys.
pub(all) struct Node[Op] {
  op : Op
  children : Array[Int32]
} derive(Eq, Hash)

///|
pub fn[Op] Node::Node(op : Op, children~ : Array[Int32] = []) -> Node[Op] {
  { op, children: children.copy(), }
}

///|
/// A topologically ordered expression DAG; the last node is its root.
pub struct Expr[Op] {
  nodes : Array[Node[Op]]
}

///|
pub fn[Op] Expr::Expr() -> Expr[Op] {
  { nodes: [], }
}

///|
/// Appends a node. Every child must refer to an earlier node.
pub fn[Op] Expr::add(self : Expr[Op], node : Node[Op]) -> Int32 {
  let id = self.nodes.length()
  for child in node.children {
    guard child >= 0 && child < id else {
      abort("expression child must precede its parent")
    }
  }
  self.nodes.push(Node(node.op, children=node.children))
  id
}

///|
pub fn[Op] Expr::length(self : Expr[Op]) -> Int32 {
  self.nodes.length()
}

///|
pub fn[Op] Expr::root(self : Expr[Op]) -> Int32 {
  guard !self.nodes.is_empty() else { abort("empty expression has no root") }
  self.nodes.length() - 1
}

///|
/// Returns a detached copy of the node's child array.
pub fn[Op] Expr::node(self : Expr[Op], id : Int32) -> Node[Op] {
  let node = self.nodes[id]
  Node(node.op, children=node.children)
}

///|
struct Class {
  members : Array[Int32]
  parents : Array[Int32]
}

///|
/// E-graph with hash-consing, path compression, and deferred congruence repair.
/// IDs are local to this graph. Call rebuild after mutations before querying.
pub struct EGraph[Op] {
  nodes : Array[Node[Op]]
  leaders : Array[Int32]
  classes : Array[Class]
  memo : Map[Node[Op], Int32]
  pending : Array[Int32]
  mut clean : Bool
  mut revision : Int32
}

///|
pub fn[Op : Eq + Hash] EGraph::EGraph() -> EGraph[Op] {
  {
    nodes: [],
    leaders: [],
    classes: [],
    memo: Map([]),
    pending: [],
    clean: true,
    revision: 0,
  }
}

///|
pub fn[Op] EGraph::is_clean(self : EGraph[Op]) -> Bool {
  self.clean
}

///|
/// Number of allocated node IDs, including nodes merged into other classes.
pub fn[Op] EGraph::allocated_size(self : EGraph[Op]) -> Int32 {
  self.nodes.length()
}

///|
fn[Op] EGraph::require_clean(self : EGraph[Op]) -> Unit {
  guard self.clean else { abort("call rebuild before querying an e-graph") }
}

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with Hash::{hash, hash_combine}
