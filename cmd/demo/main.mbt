///|
fn main raise {
  let graph = @egg.EGraph()
  let source = "(+ (* a b) (* a c))"
  let root = graph.add_expr(@egg.Expr::parse(source))
  let rules = [
    @egg.Rewrite::parse("factor", "(+ (* ?a ?b) (* ?a ?c))", "(* ?a (+ ?b ?c))"),
  ]
  let report = graph.run(rules)
  let best = graph.extract(root).unwrap()
  println("\{source} -> \{best.expression.to_string()}")
  println(
    "AST cost: 7 -> \{best.cost}; iterations: \{report.iterations.length()}",
  )
}
