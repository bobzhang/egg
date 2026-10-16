# egg.mbt

E-graphs and equality saturation in pure MoonBit, ported from the core algorithms
of [Rust egg](https://github.com/egraphs-good/egg). The module is `bobzhang/egg`.
No external MoonBit dependencies; runs on JavaScript, native, Wasm, and Wasm GC.

An e-graph stores many equivalent expressions together. Rewrites add alternatives
without discarding earlier choices; extraction picks a low-cost expression.

```mbt check
///|
test "simplify with equality saturation" {
  let graph = @egg.EGraph()
  let root = graph.add_expr(@egg.Expr::parse("(+ 0 (* 1 x))"))
  let rules = [
    @egg.Rewrite::parse("commute", "(+ ?a ?b)", "(+ ?b ?a)"),
    @egg.Rewrite::parse("add-zero", "(+ ?a 0)", "?a"),
    @egg.Rewrite::parse("multiply-one", "(* 1 ?a)", "?a"),
  ]
  let report = graph.run(rules)
  assert_eq(report.reason, Saturated)
  let best = graph.extract(root).unwrap()
  assert_eq(best.expression.to_string(), "x")
  assert_eq(best.cost, 1L)
}
```

## Installation

```sh
moon add bobzhang/egg@0.1.0
```

[GitHub](https://github.com/bobzhang/egg) · [Mooncakes](https://mooncakes.io/docs/bobzhang/egg)

## Core API

- `EGraph()` creates a graph. `Node(op, children=[...])` adds an operator with
  ordered child IDs. Operators can be any immutable `Eq + Hash` type, including
  your own enums. String operators provide the analogue of egg's `SymbolLang`.
- `Expr()` builds expression DAGs in child-before-parent order. `Expr::parse`
  and `to_string` support S-expressions with string operators.
- `add`, `add_expr`, and `union` change a graph. **Call `rebuild()` before queries.**
  Rebuilding propagates congruence through parent links and restores hash-consing.
- `find`, `lookup`, `lookup_expr`, `class_ids`, and `class_nodes` inspect it.
  Returned child arrays are copies. Internal storage is private.
- `Pattern::parse("(+ ?x ?x)")` matches equal children. `search` returns
  substitutions and a `truncated` flag; `instantiate` adds a substituted pattern.
- `Rewrite::parse(name, lhs, rhs)` rejects unbound RHS variables. Use
  `Rewrite(name, lhs, rhs, condition=...)` for a pure conditional rule.
- `run` searches all rules before applying matches, rebuilds, and repeats.
  Its report distinguishes saturation, iteration/node/matching limits, and
  caller cancellation. Per-iteration counts record successful rule unions.
- `extract(root)` minimizes AST size. `cost=@egg.ast_depth` minimizes depth;
  custom callbacks receive a node and child costs. The returned DAG shares
  repeated subexpressions even though AST cost counts each occurrence.
- `analyze(make, merge)` computes a bounded e-class analysis fixed point. A `run`
  hook can use this to introduce derived constants or equalities. See
  [analysis_test.mbt](analysis_test.mbt) for constant folding.

## Scope and contracts

This is a usable **core port**, not complete upstream API or performance parity.
See [PORTING.md](PORTING.md) for the feature matrix and deliberate differences.

IDs belong to one graph. Operators and analysis data must be immutable. Rewrite
conditions and cost/analysis callbacks must be deterministic and obey their
method contracts. Mathematical rewrites need valid domain assumptions: for
example, `x / x = 1` is not valid when `x` can be zero.

Search limits are conservative and may stop at exactly the configured threshold.
Node limits count allocated IDs, including merged nodes, and are checked between
applications; one RHS may overshoot. A caller hook owns its own resource limits.
Cancellation is checked between iterations/applications, not within callbacks.
There is no wall-clock timeout or automatic eviction. Use bounded graphs and
replace them when their lifetime ends.

Parsed patterns have a 256-level nesting limit. Programmatically constructed
patterns and large-arity matching are limited by backend call stacks. Expression
DAG parsing and extraction reconstruction are iterative. Printing expands shared
subexpressions and can produce exponentially large text; inspect DAG nodes for
large results instead. AST costs use Int64 and abort on overflow. Custom costs
must be nonnegative, monotone, and strictly greater than each child's cost.

## Build and validate

```sh
moon check --target all --warn-list +unnecessary_annotation --deny-warn
moon test --target all
moon run cmd/demo
moon fmt --check
moon info
```

The README example is a test. Validation includes upstream arithmetic examples,
cyclic classes, repeated variables, conditional rules, analysis, parser failures,
explicit limits, and randomized congruence histories checked against an
independent Boolean-matrix oracle.

For cross-language validation, clone the reference as described in
[UPSTREAM.md](UPSTREAM.md), then run:

```sh
python3 validation/compare.py
```

This builds the unmodified pinned Rust library and the MoonBit JS export, then
checks 512 seeded expressions against both implementations and an independent
arithmetic normalizer. It compares extracted costs and evaluates the resulting
expressions under three variable assignments. Equal-cost expression spelling
may differ. [Recorded results](validation/results.json) are correctness results,
not performance measurements.

Tested with MoonBit compiler `0.10.15+943464bfa`. CI checks pinned/latest MoonBit
on Linux and macOS, plus the pinned Rust differential harness.

MIT licensed; upstream attribution is retained in [LICENSE](LICENSE).
