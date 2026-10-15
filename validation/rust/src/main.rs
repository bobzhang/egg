use egg::{rewrite, AstSize, Extractor, RecExpr, Rewrite, Runner, StopReason, SymbolLang};
use std::io::{self, BufRead};
fn main() {
    let rules: Vec<Rewrite<SymbolLang, ()>> = vec![
        rewrite!("commute-add"; "(+ ?a ?b)" => "(+ ?b ?a)"),
        rewrite!("commute-mul"; "(* ?a ?b)" => "(* ?b ?a)"),
        rewrite!("add-0"; "(+ ?a 0)" => "?a"),
        rewrite!("mul-0"; "(* ?a 0)" => "0"),
        rewrite!("mul-1"; "(* ?a 1)" => "?a"),
    ];
    for line in io::stdin().lock().lines() {
        let expression: RecExpr<SymbolLang> = line.unwrap().parse().unwrap();
        let run = Runner::default().with_iter_limit(100).with_node_limit(100_000)
            .with_expr(&expression).run(&rules);
        assert!(matches!(run.stop_reason, Some(StopReason::Saturated)));
        let extractor = Extractor::new(&run.egraph, AstSize);
        let (cost, best) = extractor.find_best(run.roots[0]);
        println!("{}\t{}", cost, best);
    }
}
