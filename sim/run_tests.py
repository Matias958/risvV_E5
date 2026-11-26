#!/usr/bin/env python3
"""
run_tests.py - Regresion del MVP-0: ensambla, simula en Icarus y compara el
estado final de los registros contra el ISS (tools/erv26_iss.py).

    python3 run_tests.py                 # tests dirigidos + 50 aleatorios
    python3 run_tests.py --random 500    # mas aleatorios
    python3 run_tests.py --seed 7 --vcd  # reproducir uno y generar VCD
"""
import argparse
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from erv26asm import Assembler, write_outputs   # noqa: E402
from erv26_iss import ISS                         # noqa: E402

RTL = ['erv26_regfile.v', 'erv26_imm_gen.v', 'erv26_decoder.v', 'erv26_alu.v',
       'erv26_prog_mem.v', 'erv26_fetch.v', 'erv26_operand_build.v', 'erv26_mvp0.v']
BUILD = os.path.join(HERE, 'build')
SIMV = os.path.join(BUILD, 'tb_mvp0.vvp')


def compile_rtl():
    os.makedirs(BUILD, exist_ok=True)
    cmd = ['iverilog', '-g2005', '-Wall', '-I', os.path.join(ROOT, 'rtl'), '-o', SIMV,
           os.path.join(HERE, 'tb_mvp0.v')] + [os.path.join(ROOT, 'rtl', f) for f in RTL]
    r = subprocess.run(cmd, capture_output=True, text=True)
    warns = [l for l in r.stderr.splitlines() if l.strip() and 'timescale' not in l]
    if r.returncode:
        sys.exit('Error de compilacion:\n' + r.stderr)
    if warns:
        print('Warnings de iverilog:\n  ' + '\n  '.join(warns))


def random_program(rng, n):
    ops_r = ['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and']
    ops_i = ['addi', 'slti', 'sltiu', 'xori', 'ori', 'andi']
    ops_sh = ['slli', 'srli', 'srai']
    nops = ['beq x1, x2, 16', 'jal x5, 64', 'jalr x6, 4(x7)', 'lw x8, 0(x9)',
            'sw x3, 8(x4)', 'lb x10, -1(x2)', 'fence', 'ecall', 'bne x0, x1, -8']
    r = lambda: f'x{rng.randrange(32)}'
    lines = []
    # Inicializar registros con valores "interesantes"
    special = [0, 1, -1, 0x7FFFFFFF, -0x80000000, 31, 32, 0x55555555, -0xAAAAAAB]
    for k in range(1, 32):
        v = rng.choice(special) if rng.random() < 0.4 else rng.randrange(-(1 << 31), 1 << 31)
        lines.append(f'li x{k}, {v}')
    for _ in range(n):
        p = rng.random()
        if p < 0.40:
            lines.append(f'{rng.choice(ops_r)} {r()}, {r()}, {r()}')
        elif p < 0.70:
            imm = rng.choice([-2048, 2047, 0, -1, 1]) if rng.random() < 0.3 else rng.randrange(-2048, 2048)
            lines.append(f'{rng.choice(ops_i)} {r()}, {r()}, {imm}')
        elif p < 0.82:
            lines.append(f'{rng.choice(ops_sh)} {r()}, {r()}, {rng.randrange(32)}')
        elif p < 0.88:
            lines.append(f'lui {r()}, {rng.randrange(1 << 20)}')
        elif p < 0.94:
            lines.append(f'auipc {r()}, {rng.randrange(1 << 20)}')
        else:
            lines.append(rng.choice(nops))
    return '\n'.join(lines) + '\n'


def run_one(name, src, vcd=False):
    words, _ = Assembler().assemble(src)
    hexf = os.path.join(BUILD, f'{name}.hex')
    outf = os.path.join(BUILD, f'{name}.out')
    write_outputs(words, hex_path=hexf)
    n = len(words)
    prog = b''.join(w.to_bytes(4, 'little') for w in words)
    iss = ISS(prog, mode='mvp0').run(n)

    cmd = ['vvp', '-n', SIMV, f'+PROG={hexf}', f'+N={n}', f'+OUT={outf}'] + (['+VCD'] if vcd else [])
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=BUILD)
    if not os.path.exists(outf):
        return [f'la simulacion no genero salida:\n{r.stdout}{r.stderr}']
    got = dict(l.split() for l in open(outf) if l.strip())

    errs = [l for l in r.stdout.splitlines() if 'ERROR' in l]
    if int(got.get('tb_errors', '0')):
        errs.append(f"testbench reporto {got['tb_errors']} errores")
    if int(got['pc'], 16) != iss.pc:
        errs.append(f"pc: rtl={got['pc']} iss={iss.pc:08x}")
    for k in range(32):
        rv = got[f'x{k}']
        if 'x' in rv.lower() or int(rv, 16) != iss.x[k]:
            errs.append(f"x{k}: rtl={rv} iss={iss.x[k]:08x}")
    return errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--random', type=int, default=50)
    ap.add_argument('--len', type=int, default=300)
    ap.add_argument('--seed', type=int)
    ap.add_argument('--vcd', action='store_true')
    a = ap.parse_args()

    compile_rtl()
    tests = []
    if a.seed is None:
        tdir = os.path.join(HERE, 'tests')
        for f in sorted(os.listdir(tdir)):
            if f.endswith('.s'):
                tests.append((f[:-2], open(os.path.join(tdir, f)).read()))
        seeds = range(a.random)
    else:
        seeds = [a.seed]
    for s in seeds:
        tests.append((f'rand_{s}', random_program(random.Random(s), a.len)))

    fails = 0
    for name, src in tests:
        errs = run_one(name, src, a.vcd)
        status = 'PASS' if not errs else 'FAIL'
        if errs:
            fails += 1
            print(f'[{status}] {name}')
            for e in errs[:10]:
                print('      ' + e)
        elif not name.startswith('rand_') or a.seed is not None:
            print(f'[{status}] {name}')
    print(f'\n{len(tests) - fails}/{len(tests)} tests OK')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
