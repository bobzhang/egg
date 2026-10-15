# Port coverage and design decisions

Reference: egg 0.11.0, commit recorded in [UPSTREAM.md](UPSTREAM.md).

| Upstream capability | MoonBit status |
| --- | --- |
| Union-find with path compression | Implemented |
| Hash-consed e-nodes and equivalence classes | Implemented |
| Parent worklist and deferred congruence rebuilding | Implemented |
| RecExpr DAGs and SymbolLang | `Expr[Op]`, `Node[Op]`; strings for textual operators |
| Generic operator languages | Immutable `Op: Eq + Hash`; arity lives in `Node.children` |
| S-expression parsing/printing | Implemented with explicit quoted-atom escape subset |
| Variables and substitutions, repeated-variable equality | Implemented |
| Pattern search and application | Implemented with direct bounded backtracking |
| Validated and conditional rewrite rules | Implemented |
| Search/apply/rebuild saturation loop | Implemented as `EGraph::run` |
| Iteration/node limits and reports | Implemented; node limit uses allocated IDs |
| Search work limits and cancellation | Implemented explicitly |
| AST size, depth, and custom-cost extraction | Implemented with Int64 costs and shared DAG reconstruction |
| E-class analyses and modification | Adapted to bounded batch `analyze` plus a runner hook |
| Upstream incremental analysis propagation / DidMerge | Not ported; analysis currently recomputes to a fixed point |
| Compiled e-matching virtual machine / operator indexes | Not ported; direct matcher has different performance |
| MultiPattern / multi_rewrite relational joins | Not ported |
| Proof explanations, congruence proof extraction | Not ported |
| Simple/backoff/custom rewrite schedulers | One bounded scheduler; upstream backoff interface not ported |
| Wall-clock timing, DOT, serde, report serialization | Not ported |
| LP-based DAG extraction and external solver integrations | Not ported |
| Rust macros, borrowed searcher/applier trait objects | Replaced by constructors, enums, and callbacks |

The implementation follows the upstream add/union/rebuild and equality saturation
model, with a smaller API adapted to MoonBit. It does not mechanically translate
Rust's macro, trait-object, or associated-type machinery. All mutations copy
caller child arrays, and graph/rewriter internals are private; operator payloads
remain the caller's immutable-value responsibility.

Unlike upstream's integrated `Analysis` trait, `analyze` computes a fresh batch
fixed point. This is useful for constants and finite-lattice data but does not
claim upstream incremental-analysis performance. A hook may merge derived nodes
between iterations; its additions are included in saturation detection.

The tests port upstream simple arithmetic examples and exercise congruence,
matching, and extraction behavior. The full upstream lambda, Datalog,
explanation, and analysis test suites are not claimed to pass. In particular,
using a small rule set does not demonstrate completeness of all upstream APIs.

Future ports can add compiled matching and integrated analyses without changing
the basic Node/Expr/EGraph model. Proof explanations need additional provenance
storage and should be treated as a distinct feature, with dedicated soundness
checks. No production-readiness or performance-parity claim is made here.
