///|
pub(all) struct AnalysisResult[Data] {
  data : Map[Int32, Data]
  converged : Bool
  iterations : Int32
}

///|
/// Computes e-class analysis to a bounded fixed point. `make` observes the
/// current optional child data, and `merge` joins contributions. Both callbacks
/// must be pure; merge must be associative, commutative, idempotent, and monotone.
/// Data values must be immutable. A nonconverged result must not be treated as
/// complete. Run this from the saturation hook to add derived constants/unions.
pub fn[Op : Eq + Hash, Data : Eq] EGraph::analyze(
  self : EGraph[Op],
  make : (Node[Op], Array[Data?]) -> Data?,
  merge : (Data, Data) -> Data,
  iteration_limit~ : Int32 = 1000,
) -> AnalysisResult[Data] {
  self.require_clean()
  let data : Map[Int32, Data] = Map([])
  let ids = self.class_ids()
  for iteration in 0..<iteration_limit {
    let mut changed = false
    for id in ids {
      for node in self.class_nodes(id) {
        if make(node, node.children.map(child => data.get(self.find(child))))
          is Some(value) {
          let merged = match data.get(id) {
            None => value
            Some(old) => merge(old, value)
          }
          if data.get(id) != Some(merged) {
            data[id] = merged
            changed = true
          }
        }
      }
    }
    if !changed {
      return { data, converged: true, iterations: iteration + 1, }
    }
  }
  { data, converged: false, iterations: iteration_limit, }
}
