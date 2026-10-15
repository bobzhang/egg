///|
/// Immutable pattern trees. Variable names conventionally start with '?'.
pub(all) enum Pattern[Op] {
  Variable(String)
  Apply(Op, Array[Pattern[Op]])
}

///|
pub(all) struct Match {
  eclass : Int32
  subst : Map[String, Int32]
}

///|
pub(all) struct SearchResult {
  matches : Array[Match]
  truncated : Bool
}

///|
/// Parses patterns up to 256 levels deep. A '?name' leaf is a variable.
pub fn Pattern::parse(text : String) -> Pattern[String] raise ParseError {
  let expr = Expr::parse(text)
  let patterns = []
  let depths = []
  for node in expr.nodes {
    let mut depth = 1
    for id in node.children {
      if depths[id] + 1 > depth {
        depth = depths[id] + 1
      }
    }
    guard depth <= 256 else { raise ParseError("pattern nesting exceeds 256") }
    depths.push(depth)
    if node.op.has_prefix("?") {
      guard node.children.is_empty() && node.op.length() > 1 else {
        raise ParseError("invalid pattern variable")
      }
      patterns.push(Variable(node.op))
    } else {
      patterns.push(Apply(node.op, node.children.map(id => patterns[id])))
    }
  }
  patterns[expr.root()]
}

///|
pub fn[Op] Pattern::variables(self : Pattern[Op]) -> Array[String] {
  let result = []
  let pending = [self]
  while pending.pop() is Some(p) {
    match p {
      Variable(name) => if !result.contains(name) { result.push(name) }
      Apply(_, children) =>
        for child in children {
          pending.push(child)
        }
    }
  }
  result
}

///|
priv struct SearchBudget {
  mut steps : Int32
  mut truncated : Bool
}

///|
fn[Op : Eq + Hash] match_pattern(
  graph : EGraph[Op],
  pattern : Pattern[Op],
  id : Int32,
  subst : Map[String, Int32],
  budget : SearchBudget,
  emit : (Map[String, Int32]) -> Bool,
) -> Bool {
  if budget.steps <= 0 {
    budget.truncated = true
    return false
  }
  budget.steps -= 1
  let id = graph.find(id)
  match pattern {
    Variable(name) =>
      match subst.get(name) {
        Some(bound) => if graph.find(bound) == id { emit(subst) } else { true }
        None => {
          let next = subst.copy()
          next[name] = id
          emit(next)
        }
      }
    Apply(op, children) => {
      for node in graph.class_nodes(id) {
        if op == node.op && children.length() == node.children.length() {
          if !match_children(
              graph,
              children,
              node.children,
              0,
              subst,
              budget,
              emit,
            ) {
            return false
          }
        }
      }
      true
    }
  }
}

///|
fn[Op : Eq + Hash] match_children(
  graph : EGraph[Op],
  patterns : Array[Pattern[Op]],
  ids : Array[Int32],
  index : Int32,
  subst : Map[String, Int32],
  budget : SearchBudget,
  emit : (Map[String, Int32]) -> Bool,
) -> Bool {
  if index == patterns.length() {
    return emit(subst)
  }
  match_pattern(graph, patterns[index], ids[index], subst, budget, next => {
    match_children(graph, patterns, ids, index + 1, next, budget, emit)
  })
}

///|
/// Searches a clean graph. Limits are conservative: reaching either limit marks
/// the result truncated, so a runner cannot falsely report saturation.
pub fn[Op : Eq + Hash] Pattern::search(
  self : Pattern[Op],
  graph : EGraph[Op],
  limit~ : Int32 = 10000,
  steps~ : Int32 = 1000000,
  eclass? : Int32,
) -> SearchResult {
  graph.require_clean()
  guard limit > 0 && steps > 0 else { return { matches: [], truncated: true, } }
  let matches = []
  let budget = { steps, truncated: false, }
  let ids = match eclass {
    Some(id) => [graph.find(id)]
    None => graph.class_ids()
  }
  for id in ids {
    let seen : Array[Map[String, Int32]] = []
    let finished = match_pattern(graph, self, id, Map([]), budget, subst => {
      if !seen.any(old => old == subst) {
        seen.push(subst)
        matches.push({ eclass: id, subst, })
      }
      if matches.length() >= limit {
        budget.truncated = true
        false
      } else {
        true
      }
    })
    if !finished {
      break
    }
  }
  { matches, truncated: budget.truncated, }
}

///|
fn[Op : Eq + Hash] instantiate(
  graph : EGraph[Op],
  pattern : Pattern[Op],
  subst : Map[String, Int32],
) -> Int32 {
  match pattern {
    Variable(name) => graph.find(subst[name])
    Apply(op, children) =>
      graph.add(
        Node(op, children=children.map(p => instantiate(graph, p, subst))),
      )
  }
}

///|
/// Adds a substituted pattern. Rejects missing bindings before mutating the graph.
pub fn[Op : Eq + Hash] EGraph::instantiate(
  self : EGraph[Op],
  pattern : Pattern[Op],
  subst : Map[String, Int32],
) -> Int32 {
  for variable in pattern.variables() {
    guard subst.get(variable) is Some(id) else {
      abort("unbound pattern variable")
    }
    ignore(self.find(id))
  }
  instantiate(self, pattern, subst)
}
