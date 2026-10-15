///|
pub(all) struct Extraction[Op] {
  cost : Int64
  expression : Expr[Op]
}

///|
/// AST size counts repeated children separately, even when the output DAG shares
/// their storage. Costs overflow explicitly rather than silently wrapping.
pub fn[Op] ast_size(_node : Node[Op], children : Array[Int64]) -> Int64 {
  let mut result = 1L
  for child in children {
    guard child >= 0L && child <= 9223372036854775807L - result else {
      abort("AST size exceeds Int64")
    }
    result += child
  }
  result
}

///|
pub fn[Op] ast_depth(_node : Node[Op], children : Array[Int64]) -> Int64 {
  let mut result = 0L
  for child in children {
    if child > result {
      result = child
    }
  }
  guard result < 9223372036854775807L else { abort("AST depth exceeds Int64") }
  result + 1L
}

///|
/// Finds a cheapest finite expression. Costs must be deterministic, monotone in
/// child costs, nonnegative, and strictly greater than each child cost. This
/// excludes cyclic solutions. None means no finite representative was found.
pub fn[Op : Eq + Hash] EGraph::extract(
  self : EGraph[Op],
  root : Int32,
  cost~ : (Node[Op], Array[Int64]) -> Int64 = ast_size,
) -> Extraction[Op]? {
  self.require_clean()
  let root = self.find(root)
  let costs : Map[Int32, Int64] = Map([])
  let best : Map[Int32, Node[Op]] = Map([])
  let ids = self.class_ids()
  let mut changed = true
  while changed {
    changed = false
    for id in ids {
      for node in self.class_nodes(id) {
        let child_costs = []
        for child in node.children {
          if costs.get(self.find(child)) is Some(value) {
            child_costs.push(value)
          }
        }
        if child_costs.length() == node.children.length() {
          let value = cost(
            Node(node.op, children=node.children),
            child_costs.copy(),
          )
          guard value >= 0L && child_costs.all(child => value > child) else {
            abort("extraction cost must exceed every child cost")
          }
          let improve = match costs.get(id) {
            None => true
            Some(old) => value < old
          }
          if improve {
            costs[id] = value
            best[id] = node
            changed = true
          }
        }
      }
    }
  }
  guard costs.get(root) is Some(value) else { return None }
  // Iterative DAG reconstruction avoids stack growth and exponential cloning.
  let expression = Expr()
  let emitted : Map[Int32, Int32] = Map([])
  let pending = [(root, false)]
  while pending.pop() is Some((id, expanded)) {
    if emitted.contains(id) {
      continue
    }
    let node = best[id]
    if expanded {
      emitted[id] = expression.add(
        Node(
          node.op,
          children=node.children.map(child => emitted[self.find(child)]),
        ),
      )
    } else {
      pending.push((id, true))
      for child in node.children.rev() {
        pending.push((self.find(child), false))
      }
    }
  }
  Some({ cost: value, expression, })
}
