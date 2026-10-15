#!/usr/bin/env python3
"""Seeded cross-language checks against pinned, unmodified Rust egg."""
import argparse
import json
from pathlib import Path
import random
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PIN = '73975c9819efb4af2f3c6c1b44fa53f8c5742574'
parser = argparse.ArgumentParser()
parser.add_argument('--cases', type=int, default=512)
parser.add_argument('--seed', type=int, default=20261015)
args = parser.parse_args()
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT/'.repos/egg',text=True).strip() == PIN
assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT/'.repos/egg',text=True).strip(), 'reference must be unmodified'
rng = random.Random(args.seed)
def generate(depth):
    if depth == 0 or rng.random() < .25:
        return rng.choice(['0','0','1','1','2','x','y','z'])
    return (rng.choice(['+','*']), generate(depth-1), generate(depth-1))
def show(expr):
    return expr if isinstance(expr,str) else f'({expr[0]} {show(expr[1])} {show(expr[2])})'
def simplify(expr):
    if isinstance(expr,str): return expr
    op,a,b = expr
    a,b = simplify(a),simplify(b)
    if op == '+':
        if a == '0': return b
        if b == '0': return a
    else:
        if a == '0' or b == '0': return '0'
        if a == '1': return b
        if b == '1': return a
    return (op,a,b)
def cost(expr):
    return 1 if isinstance(expr,str) else 1+cost(expr[1])+cost(expr[2])
def parse(text):
    tokens = iter(text.replace('(',' ( ').replace(')',' ) ').split())
    def one(token):
        if token != '(': return token
        op=next(tokens); a=one(next(tokens)); b=one(next(tokens))
        assert next(tokens)==')'
        return (op,a,b)
    out=one(next(tokens)); assert next(tokens,None) is None
    return out
def evaluate(expr,env):
    if isinstance(expr,str): return env[expr] if expr in env else int(expr)
    a,b=evaluate(expr[1],env),evaluate(expr[2],env)
    return a+b if expr[0]=='+' else a*b
cases=[generate(4) for _ in range(args.cases)]
source='\n'.join(map(show,cases))+'\n'
subprocess.run(['moon','build','--release','--target','js','validation/bridge'],cwd=ROOT,check=True)
subprocess.run(['cargo','build','--release','--manifest-path','validation/rust/Cargo.toml'],cwd=ROOT,check=True)
outputs={}
for name,command in [('moonbit',['node','validation/run.mjs']),('rust',['validation/rust/target/release/egg-reference-check'])]:
    outputs[name]=subprocess.check_output(command,cwd=ROOT,input=source,text=True).splitlines()
    assert len(outputs[name])==len(cases)
for i,case in enumerate(cases):
    expected=cost(simplify(case))
    for name,lines in outputs.items():
        measured,result=lines[i].split('\t',1)
        assert int(measured)==expected, (i,name,show(case),expected,lines[i])
        result=parse(result)
        assert cost(result)==expected
        for values in [(0,1,2),(-3,4,7),(11,-5,0)]:
            env=dict(zip(['x','y','z'],values))
            assert evaluate(case,env)==evaluate(result,env),(i,name,show(case))
summary={'seed':args.seed,'cases':len(cases),'reference':PIN,'status':'passed','checks':['Rust and MoonBit extracted costs equal independent normalizer','extracted tree size matches reported cost','input/output semantics agree for three variable assignments']}
(ROOT/'validation/results.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))
