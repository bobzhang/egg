///|
fn simple_rules() -> Array[@egg.Rewrite[String]] raise {
  [
    @egg.Rewrite::parse("commute-add", "(+ ?a ?b)", "(+ ?b ?a)"),
    @egg.Rewrite::parse("commute-mul", "(* ?a ?b)", "(* ?b ?a)"),
    @egg.Rewrite::parse("add-0", "(+ ?a 0)", "?a"),
    @egg.Rewrite::parse("mul-0", "(* ?a 0)", "0"),
    @egg.Rewrite::parse("mul-1", "(* ?a 1)", "?a"),
  ]
}

///|
test "upstream simple examples simplify to expected atoms" {
  for
    (input, expected) in [
      ("(* 0 42)", "0"),
      ("(+ 0 (* 1 foo))", "foo"),
      ("(+ 0 (* 1 10))", "10"),
    ] {
    let g = @egg.EGraph()
    let root = g.add_expr(@egg.Expr::parse(input))
    let report = g.run(simple_rules())
    assert_eq(report.reason, Saturated)
    let best = g.extract(root).unwrap()
    assert_eq(best.cost, 1L)
    assert_eq(best.expression.to_string(), expected)
  }
}

///|
test "factoring and cyclic extraction select a cheap finite expression" {
  let g = @egg.EGraph()
  let root = g.add_expr(@egg.Expr::parse("(+ (* a b) (* a c))"))
  let report = g.run(
    [
      @egg.Rewrite::parse(
        "factor", "(+ (* ?a ?b) (* ?a ?c))", "(* ?a (+ ?b ?c))",
      ),
      @egg.Rewrite::parse("identity-expansion", "?a", "(+ ?a 0)"),
    ],
    iteration_limit=3,
    node_limit=1000,
  )
  assert_true(report.reason == IterationLimit || report.reason == Saturated)
  assert_eq(g.extract(root).unwrap().cost, 5L)
  assert_eq(g.extract(root, cost=@egg.ast_depth).unwrap().cost, 3L)
}

///|
test "unbound variables rejected and runner limits are explicit" {
  let rejected = try {
    ignore(@egg.Rewrite::parse("bad", "?x", "?y"))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let g = @egg.EGraph()
  ignore(g.add_expr(@egg.Expr::parse("(f a b)")))
  assert_eq(g.run([], iteration_limit=0).reason, IterationLimit)
  assert_eq(g.run([], node_limit=1).reason, NodeLimit)
  let rule = @egg.Rewrite::parse("expand", "?x", "(g ?x)")
  assert_eq(g.run([rule], match_limit=1).reason, MatchLimit)
  assert_eq(g.run([rule], cancelled=() => true).reason, Cancelled)
  assert_eq(g.run([rule], node_limit=5).reason, NodeLimit)
  assert_true(g.is_clean())
}

///|
test "conditional rewrite and custom cost" {
  let g = @egg.EGraph()
  let root = g.add_expr(@egg.Expr::parse("(/ x x)"))
  let rule = @egg.Rewrite(
    "cancel",
    @egg.Pattern::parse("(/ ?x ?x)"),
    @egg.Pattern::parse("1"),
    condition=(_, _) => false,
  )
  assert_eq(g.run([rule]).reason, Saturated)
  assert_eq(g.extract(root).unwrap().cost, 3L)
  let one = g.add(Node("1"))
  ignore(g.union(root, one))
  ignore(g.rebuild())
  let result = g
    .extract(root, cost=(node, children) => {
      children.fold(init=if node.op == "1" { 100L } else { 1L }, (sum, x) => {
        sum + x
      })
    })
    .unwrap()
  assert_eq(result.expression.to_string(), "(/ x x)")
  assert_eq(result.expression.length(), 2)
  assert_eq(result.cost, 3L)
}
