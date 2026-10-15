///|
pub struct Rewrite[Op] {
  priv name : String
  priv left : Pattern[Op]
  priv right : Pattern[Op]
  priv condition : (EGraph[Op], Map[String, Int32]) -> Bool
}

///|
fn[Op] copy_pattern(pattern : Pattern[Op]) -> Pattern[Op] {
  match pattern {
    Variable(name) => Variable(name)
    Apply(op, children) => Apply(op, children.map(copy_pattern))
  }
}

///|
/// Creates a rewrite, rejecting RHS variables not bound on the LHS.
/// Conditions must not mutate the graph. Operators must remain immutable.
pub fn[Op] Rewrite::Rewrite(
  name : String,
  left : Pattern[Op],
  right : Pattern[Op],
  condition~ : (EGraph[Op], Map[String, Int32]) -> Bool = (_, _) => true,
) -> Rewrite[Op] raise ParseError {
  let bound = left.variables()
  for variable in right.variables() {
    guard bound.contains(variable) else {
      raise ParseError("unbound RHS variable: " + variable)
    }
  }
  { name, left: copy_pattern(left), right: copy_pattern(right), condition, }
}

///|
pub fn Rewrite::parse(
  name : String,
  left : String,
  right : String,
) -> Rewrite[String] raise ParseError {
  Rewrite(name, Pattern::parse(left), Pattern::parse(right))
}

///|
pub fn[Op] Rewrite::name(self : Rewrite[Op]) -> String {
  self.name
}

///|
pub(all) enum StopReason {
  Saturated
  IterationLimit
  NodeLimit
  MatchLimit
  Cancelled
} derive(Eq, Debug)

///|
pub extend StopReason with Eq::{equal, not_equal}

///|
pub extend StopReason with Debug::{to_repr}

///|
pub(all) struct Iteration {
  index : Int32
  classes : Int32
  nodes : Int32
  applied : Map[String, Int32]
}

///|
pub(all) struct RunReport {
  reason : StopReason
  iterations : Array[Iteration]
}

///|
/// Equality saturation: search every rule before applying any matches, then
/// rebuild and invoke the optional analysis hook. Limits are checked at rule
/// applications; node count can overshoot by at most one instantiated RHS.
/// Match truncation stops explicitly rather than claiming saturation.
pub fn[Op : Eq + Hash] EGraph::run(
  self : EGraph[Op],
  rules : Array[Rewrite[Op]],
  iteration_limit~ : Int32 = 30,
  node_limit~ : Int32 = 100000,
  match_limit~ : Int32 = 10000,
  search_steps~ : Int32 = 1000000,
  hook~ : (EGraph[Op]) -> Unit = _ => (),
  cancelled~ : () -> Bool = () => false,
) -> RunReport {
  let iterations = []
  ignore(self.rebuild())
  hook(self)
  ignore(self.rebuild())
  if self.allocated_size() >= node_limit {
    return { reason: NodeLimit, iterations, }
  }
  for index in 0..<iteration_limit {
    if cancelled() {
      return { reason: Cancelled, iterations, }
    }
    let revision = self.revision
    let searched = []
    for rule in rules {
      let result = rule.left.search(self, limit=match_limit, steps=search_steps)
      if result.truncated {
        return { reason: MatchLimit, iterations, }
      }
      searched.push(result.matches)
    }
    let applied : Map[String, Int32] = Map([])
    for r, rule in rules {
      for found in searched[r] {
        if cancelled() {
          ignore(self.rebuild())
          return { reason: Cancelled, iterations, }
        }
        if !self.clean {
          ignore(self.rebuild())
        }
        let old_revision = self.revision
        let allowed = (rule.condition)(self, found.subst.copy())
        guard self.revision == old_revision else {
          abort("rewrite condition mutated its graph")
        }
        if allowed {
          let rhs = self.instantiate(rule.right, found.subst)
          if self.union(found.eclass, rhs) {
            applied[rule.name] = applied.get(rule.name).unwrap_or(0) + 1
          }
        }
        if self.allocated_size() >= node_limit {
          ignore(self.rebuild())
          iterations.push({
            index,
            classes: self.number_of_classes(),
            nodes: self.total_size(),
            applied,
          })
          return { reason: NodeLimit, iterations, }
        }
      }
    }
    ignore(self.rebuild())
    hook(self)
    ignore(self.rebuild())
    iterations.push({
      index,
      classes: self.number_of_classes(),
      nodes: self.total_size(),
      applied,
    })
    if self.allocated_size() >= node_limit {
      return { reason: NodeLimit, iterations, }
    }
    if self.revision == revision {
      return { reason: Saturated, iterations, }
    }
  }
  { reason: IterationLimit, iterations, }
}
