///|
fn random_index(state : Ref[UInt32], bound : Int32) -> Int32 {
  state.val = state.val * 1664525U + 1013904223U
  (state.val.reinterpret_as_int() & 0x7fffffff) % bound
}

///|
// Independent oracle: a Boolean equivalence matrix, Floyd-Warshall closure,
// and pairwise congruence checks. No union-find or hash-consing.
fn close_relation(
  nodes : Array[@egg.Node[Int32]],
  equal : Array[Array[Bool]],
) -> Unit {
  let n = nodes.length()
  let mut changed = true
  while changed {
    changed = false
    for k in 0..<n {
      for i in 0..<n {
        for j in 0..<n {
          if !equal[i][j] && equal[i][k] && equal[k][j] {
            equal[i][j] = true
            changed = true
          }
        }
      }
    }
    for i in 0..<n {
      for j in 0..<n {
        let a = nodes[i]
        let b = nodes[j]
        if !equal[i][j] &&
          a.op == b.op &&
          a.children.length() == b.children.length() {
          let mut same = true
          for c in 0..<a.children.length() {
            if !equal[a.children[c]][b.children[c]] {
              same = false
            }
          }
          if same {
            equal[i][j] = true
            equal[j][i] = true
            changed = true
          }
        }
      }
    }
  }
}

///|
test "random congruence histories match an independent equivalence matrix" {
  for seed in 1..<13 {
    let random = Ref(seed.reinterpret_as_uint())
    let graph = @egg.EGraph()
    let nodes : Array[@egg.Node[Int32]] = []
    let ids = []
    for i in 0..<36 {
      let node = if i < 6 {
        @egg.Node(i)
      } else {
        Node(6 + random_index(random, 3), children=[
          random_index(random, i),
          random_index(random, i),
        ])
      }
      ids.push(
        graph.add(
          Node(node.op, children=node.children.map(child => ids[child])),
        ),
      )
      nodes.push(node)
    }
    let equal = Array::makei(36, i => Array::makei(36, j => i == j))
    for step in 0..<24 {
      let a = random_index(random, 36)
      let b = random_index(random, 36)
      equal[a][b] = true
      equal[b][a] = true
      ignore(graph.union(ids[a], ids[b]))
      close_relation(nodes, equal)
      ignore(graph.rebuild())
      for i in 0..<36 {
        for j in 0..<36 {
          assert_eq(
            graph.find(ids[i]) == graph.find(ids[j]),
            equal[i][j],
            msg="seed=\{seed} step=\{step} pair=\{i},\{j}",
          )
        }
      }
      assert_eq(graph.rebuild(), 0)
    }
  }
}

///|
test "shared DAG extraction avoids exponential allocation" {
  let graph = @egg.EGraph()
  let mut root = graph.add(Node("x"))
  for _ in 0..<25 {
    root = graph.add(Node("f", children=[root, root]))
  }
  ignore(graph.rebuild())
  let result = graph.extract(root).unwrap()
  assert_eq(result.expression.length(), 26)
  assert_eq(result.cost, 67108863L)
}

///|
test "panic querying a dirty graph is rejected" {
  let graph = @egg.EGraph()
  ignore(graph.add(Node("x")))
  ignore(graph.total_size())
}

///|
test "panic invalid expression forward reference is rejected" {
  let expression : @egg.Expr[String] = Expr()
  ignore(expression.add(Node("f", children=[0])))
}
