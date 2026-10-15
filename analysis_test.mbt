///|
fn constants(node : @egg.Node[String], children : Array[Int32?]) -> Int32? {
  match (node.op, children) {
    ("0", []) => Some(0)
    ("1", []) => Some(1)
    ("2", []) => Some(2)
    ("3", []) => Some(3)
    ("+", [Some(a), Some(b)]) => Some(a + b)
    ("*", [Some(a), Some(b)]) => Some(a * b)
    _ => None
  }
}

///|
test "fixed point analysis propagates constants and saturation hook folds them" {
  let g = @egg.EGraph()
  let root = g.add_expr(@egg.Expr::parse("(+ (* 2 3) x)"))
  let x = g.add(Node("x"))
  let one = g.add(Node("1"))
  ignore(g.union(x, one))
  ignore(g.rebuild())
  let join = fn(a, b) {
    if a != b {
      abort("inconsistent constants")
    }
    a
  }
  let result = g.analyze(constants, join)
  assert_true(result.converged)
  assert_eq(result.data.get(g.find(root)), Some(7))
  assert_false(g.analyze(constants, join, iteration_limit=0).converged)
  let report = g.run([], hook=graph => {
    let result = graph.analyze(constants, join)
    for id, value in result.data {
      let constant = graph.add(Node(value.to_string()))
      ignore(graph.union(id, constant))
    }
  })
  assert_eq(report.reason, Saturated)
  assert_eq(g.extract(root).unwrap().expression.to_string(), "7")
}

///|
test "conditions can query rebuilt classes across multiple applications" {
  let g = @egg.EGraph()
  ignore(g.add_expr(@egg.Expr::parse("(pair (f a) (f b))")))
  let rule = @egg.Rewrite(
    "unwrap",
    @egg.Pattern::parse("(f ?x)"),
    @egg.Pattern::parse("?x"),
    condition=(graph, subst) => !graph.class_nodes(subst["?x"]).is_empty(),
  )
  assert_eq(g.run([rule]).reason, Saturated)
}
