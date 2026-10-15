///|
test "parsing round trips quoted Unicode atoms and nested expressions" {
  for
    source in [
      "x", "(+ a (* b c))", "(\"space op\" \"你好 世界\" \"a\\\"b\")", "(f \"\" \"x\\ny\")",
    ] {
    let expression = @egg.Expr::parse(source)
    assert_eq(
      @egg.Expr::parse(expression.to_string()).to_string(),
      expression.to_string(),
    )
  }
  for source in ["", "()", "(", ")", "a b", "(a", "(a))", "\"x", "\"x\"y"] {
    let bad = try {
      ignore(@egg.Expr::parse(source))
      false
    } catch {
      _ => true
    }
    assert_true(bad, msg=source)
  }
}

///|
test "repeated variables require equivalent children" {
  let g = @egg.EGraph()
  let aa = g.add_expr(@egg.Expr::parse("(+ a a)"))
  let ab = g.add_expr(@egg.Expr::parse("(+ a b)"))
  ignore(g.rebuild())
  let p = @egg.Pattern::parse("(+ ?x ?x)")
  let found = p.search(g)
  assert_false(found.truncated)
  assert_eq(found.matches.length(), 1)
  assert_eq(found.matches[0].eclass, aa)
  let a = g.lookup_expr(@egg.Expr::parse("a")).unwrap()
  let b = g.lookup_expr(@egg.Expr::parse("b")).unwrap()
  ignore(g.union(a, b))
  ignore(g.rebuild())
  assert_eq(g.find(aa), g.find(ab))
  assert_eq(p.search(g).matches.length(), 1)
}

///|
test "e-matching joins alternatives and observes explicit limits" {
  let g = @egg.EGraph()
  let fa = g.add_expr(@egg.Expr::parse("(f a)"))
  let fb = g.add_expr(@egg.Expr::parse("(f b)"))
  ignore(g.union(fa, fb))
  let pair = g.add(@egg.Node("pair", children=[fa, fb]))
  ignore(g.rebuild())
  let pattern = @egg.Pattern::parse("(pair (f ?x) (f ?y))")
  let all = pattern.search(g, eclass=pair)
  assert_eq(all.matches.length(), 4)
  assert_false(all.truncated)
  let limited = pattern.search(g, limit=2)
  assert_eq(limited.matches.length(), 2)
  assert_true(limited.truncated)
  assert_true(pattern.search(g, steps=1).truncated)
  let rhs = @egg.Pattern::parse("(result ?y ?x)")
  let output = g.instantiate(rhs, all.matches[0].subst)
  ignore(g.rebuild())
  assert_eq(g.class_nodes(output)[0].op, "result")
}
