///|
#export_name("simplify")
pub fn simplify(source : String) -> String {
  let g = @egg.EGraph()
  let root = g.add_expr(try! @egg.Expr::parse(source))
  let rules = [
    try! @egg.Rewrite::parse("commute-add", "(+ ?a ?b)", "(+ ?b ?a)"),
    try! @egg.Rewrite::parse("commute-mul", "(* ?a ?b)", "(* ?b ?a)"),
    try! @egg.Rewrite::parse("add-0", "(+ ?a 0)", "?a"),
    try! @egg.Rewrite::parse("mul-0", "(* ?a 0)", "0"),
    try! @egg.Rewrite::parse("mul-1", "(* ?a 1)", "?a"),
  ]
  let report = g.run(rules, iteration_limit=100)
  guard report.reason == Saturated else {
    abort("reference case did not saturate")
  }
  let result = g.extract(root).unwrap()
  result.cost.to_string() + "\t" + result.expression.to_string()
}
