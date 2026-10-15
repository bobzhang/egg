///|
test "congruence propagates through multiple parents and repeated rebuilds" {
  let g = @egg.EGraph()
  let x = g.add(@egg.Node("x"))
  let y = g.add(@egg.Node("y"))
  let fx = g.add(@egg.Node("f", children=[x]))
  let fy = g.add(@egg.Node("f", children=[y]))
  let gx = g.add(@egg.Node("g", children=[fx, x]))
  let gy = g.add(@egg.Node("g", children=[fy, y]))
  ignore(g.rebuild())
  assert_true(g.find(gx) != g.find(gy))
  assert_true(g.union(x, y))
  assert_eq(g.rebuild(), 2)
  assert_eq(g.find(gx), g.find(gy))
  assert_eq(g.number_of_classes(), 3)
  assert_eq(g.total_size(), 4)
  assert_eq(g.add(@egg.Node("f", children=[y])), g.find(fx))
  assert_eq(g.rebuild(), 0)
  assert_false(g.union(gx, gy))
}

///|
test "hash keys and returned nodes do not alias caller child arrays" {
  let g = @egg.EGraph()
  let a = g.add(@egg.Node("a"))
  let b = g.add(@egg.Node("b"))
  let children = [a]
  let f = g.add(@egg.Node("f", children~))
  children[0] = b
  ignore(g.rebuild())
  let nodes = g.class_nodes(f)
  nodes[0].children[0] = b
  assert_eq(g.lookup(@egg.Node("f", children=[a])), Some(f))
  assert_eq(g.lookup(@egg.Node("f", children=[b])), None)
}

///|
test "cyclic eclasses retain finite representatives" {
  let g = @egg.EGraph()
  let x = g.add(@egg.Node(1))
  let f = g.add(@egg.Node(2, children=[x]))
  ignore(g.union(x, f))
  ignore(g.rebuild())
  assert_eq(g.number_of_classes(), 1)
  assert_eq(g.total_size(), 2)
  assert_eq(g.class_nodes(x).length(), 2)
}

///|
test "expression DAG preserves shared children" {
  let expr = @egg.Expr()
  let x = expr.add(@egg.Node("x"))
  ignore(expr.add(@egg.Node("+", children=[x, x])))
  let g = @egg.EGraph()
  let root = g.add_expr(expr)
  ignore(g.rebuild())
  assert_eq(g.total_size(), 2)
  assert_eq(g.lookup_expr(expr), Some(root))
}
