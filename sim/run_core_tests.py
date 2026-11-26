#!/usr/bin/env python3
"""
run_core_tests.py - Regresion del nucleo con pipeline.

Para cada programa:
  1. Compila con riscv64-unknown-elf-gcc (-march=rv32i) y genera los .hex
  2. Lo corre en el ISS (modelo de referencia)
  3. Lo corre en el RTL (Icarus) con distintas condiciones de memoria/halt
  4. Compara instruccion por instruccion: PC, instruccion, rd y valor
     escrito, y la secuencia de stores (direccion, byte enables, dato)

Suites:
  riscv-tests : rv32ui oficiales (requiere ../riscv-tests o --rvtests)
  c           : programas en C (sw/tests/*.c) y tests dirigidos en asm (sw/tests/*.S)
  random      : programas aleatorios con saltos, loops, loads/stores y
                dependencias densas para estresar forwarding y hazards

Gate-level (netlist post-fit que genera Quartus con gate_sim/core_gl.qpf):
    python3 run_core_tests.py --gate ../gate_sim/simulation/questa/core_gl.vo \
        --simlib <quartus>/eda/sim_lib

    python3 run_core_tests.py                     # todo
    python3 run_core_tests.py --suite random --random 300
    python3 run_core_tests.py --only add --vcd    # un test, con ondas
"""
import argparse
import glob
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from erv26_iss import ISS          # noqa: E402
import elf2hex                     # noqa: E402

BUILD = os.path.join(HERE, 'build_core')
SIMV = os.path.join(BUILD, 'tb_core.vvp')
COMMON = os.path.join(ROOT, 'sw', 'common')
CC = 'riscv64-unknown-elf-gcc'
CFLAGS = ['-march=rv32i', '-mabi=ilp32', '-nostdlib', '-nostartfiles', '-static',
          '-T', os.path.join(COMMON, 'link.ld'), '-I', COMMON]

# El nucleo es rtl/erv26_core.bdf (por bloques); se convierte a Verilog con
# tools/bdf2v.py antes de compilar. Estos son los bloques que instancia.
RTL = ['erv26_regfile.v', 'erv26_imm_gen.v', 'erv26_decoder.v', 'erv26_alu.v',
       'erv26_operand_build.v', 'erv26_branch_unit.v', 'erv26_lsu.v',
       'erv26_hazard_unit.v', 'erv26_forward_unit.v',
       'erv26_pc_select.v', 'erv26_if_id.v', 'erv26_id_predict.v', 'erv26_id_ex.v',
       'erv26_ex_result.v', 'erv26_ex_mem.v', 'erv26_mem_ctrl.v', 'erv26_wb_select.v',
       'erv26_mem_wb.v', 'erv26_wb_commit.v']
CORE_BDF = os.path.join(ROOT, 'rtl', 'erv26_core.bdf')

# Condiciones de simulacion: (nombre, plusargs)
CONDITIONS = [
    ('lat0', ['+LAT_MAX=0']),                           # memoria ideal, sin espera
    ('lat3', ['+LAT_MAX=3', '+SEED=11']),               # latencia aleatoria 0..3
    ('lat2+halt', ['+LAT_MAX=2', '+EN_RAND', '+SEED=5']),
    ('m10k', ['+MEM_RTL']),                             # RAM real de la placa (M10K)
    ('m10k+halt', ['+MEM_RTL', '+EN_RAND', '+SEED=7']),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


GATE = None        # (netlist .vo, carpeta sim_lib de Quartus) con --gate


def compile_gate():
    os.makedirs(BUILD, exist_ok=True)
    vo, lib = GATE
    libs = [os.path.join(lib, f) for f in ('altera_primitives.v', 'cyclonev_atoms.v')]
    libs.append(os.path.join(HERE, 'gate_stubs.v'))
    libs.append(os.path.join(ROOT, 'rtl', 'erv26_dmem.v'))     # RAM del modo +MEM_RTL
    r = sh(['iverilog', '-g2005', '-DGATE', '-s', 'tb_core', '-I', os.path.dirname(vo), '-o', SIMV, os.path.join(HERE, 'tb_core.v'), vo] + libs)
    if r.returncode:
        sys.exit('Error de compilacion del netlist:\n' + r.stderr)


def compile_rtl():
    if GATE:
        return compile_gate()
    os.makedirs(BUILD, exist_ok=True)
    core_v = os.path.join(BUILD, 'erv26_core_bdf.v')
    r = sh([sys.executable, os.path.join(ROOT, 'tools', 'bdf2v.py'), CORE_BDF, 'erv26_core', core_v])
    if r.returncode:
        sys.exit('Error en ' + CORE_BDF + ':\n' + r.stdout + r.stderr)
    r = sh(['iverilog', '-g2005', '-Wall', '-I', os.path.join(ROOT, 'rtl'), '-I', HERE, '-o', SIMV,
            os.path.join(HERE, 'tb_core.v'), core_v,
            os.path.join(ROOT, 'rtl', 'erv26_dmem.v')] + [os.path.join(ROOT, 'rtl', f) for f in RTL])
    warns = [l for l in r.stderr.splitlines() if l.strip() and 'timescale' not in l]
    if r.returncode:
        sys.exit('Error de compilacion RTL:\n' + r.stderr)
    if warns:
        print('Warnings de iverilog:\n  ' + '\n  '.join(warns[:20]))


def build(name, sources, extra=()):
    elf = os.path.join(BUILD, name + '.elf')
    r = sh([CC] + CFLAGS + list(extra) + sources + ['-lgcc', '-o', elf])
    if r.returncode:
        raise RuntimeError(f'gcc fallo en {name}:\n{r.stderr}')
    base = os.path.join(BUILD, name)
    imem, dmem = elf2hex.load(elf)
    iw, dw = elf2hex.words(imem), elf2hex.words(dmem)
    open(base + '.imem.hex', 'w').write(''.join(f'{w:08x}\n' for w in iw))
    open(base + '.dmem.hex', 'w').write(''.join(f'{w:08x}\n' for w in dw) or '00000000\n')
    return base, imem, dmem


def parse_rtl(path):
    commits, stores, tohost, stats = [], [], None, ''
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == 'C':
            pc, ins = int(p[1], 16), int(p[2], 16)
            commits.append((pc, ins, None, 0) if p[3] == '-' else (pc, ins, int(p[3]), int(p[4], 16)))
        elif p[0] == 'S':
            stores.append((int(p[1], 16), int(p[2], 16), int(p[3], 16)))
        elif p[0] == 'TOHOST':
            tohost = int(p[1], 16)
        elif p[0] == 'STATS':
            stats = ' '.join(p[1:])
    return commits, stores, tohost, stats


def fmt(c):
    pc, ins, rd, v = c
    return f'pc={pc:08x} ins={ins:08x} ' + (f'x{rd}={v:08x}' if rd is not None else '(sin escritura)')


def run_test(name, base, imem, dmem, halt_pc=None, expect_pass=True, vcd=False, conds=CONDITIONS):
    iss = ISS(imem, 'full', dmem)
    iss.run_until(halt_pc)
    if halt_pc is not None:
        iss.step()                       # el RTL tambien retira la instruccion de halt
    errors, stats_out = [], ''
    if expect_pass and iss.tohost is not None and iss.tohost != 1:
        errors.append(f'el ISS reporta FAIL (tohost={iss.tohost:#x}): test mal armado')
    maxcyc = 20 * len(iss.trace) + 1000
    for cname, args in conds:
        trace = f'{base}.{cname}.trace'
        cmd = ['vvp', '-n', SIMV, f'+IMEM={base}.imem.hex', f'+DMEM={base}.dmem.hex',
               f'+TRACE={trace}', f'+MAXCYC={maxcyc}'] + args
        if halt_pc is not None:
            cmd.append(f'+HALT_PC={halt_pc:08x}')
        if GATE and iss.trace:
            cmd.append(f'+TOHOST_PC={iss.trace[-1][0]:08x}')
        if vcd:
            cmd.append('+VCD')
        r = sh(cmd, cwd=BUILD)
        if 'ASSERT' in r.stdout or 'TIMEOUT' in r.stdout:
            errors.append(f'[{cname}] ' + ' '.join(l for l in r.stdout.splitlines() if 'ASSERT' in l or 'TIMEOUT' in l))
        commits, stores, tohost, stats = parse_rtl(trace)
        if cname == conds[0][0]:
            stats_out = stats + stats_out
        elif cname == 'm10k':                # ciclos con la RAM real de la placa
            d = dict(kv.split('=') for kv in stats.split())
            stats_out += f"  | m10k: cycles={d.get('cycles')} mem_wait={d.get('mem_wait')}"
        for k, (a, b) in enumerate(zip(commits, iss.trace)):
            if a != b:
                errors.append(f'[{cname}] instruccion #{k}: rtl {fmt(a)} | iss {fmt(b)}')
                break
        else:
            if len(commits) != len(iss.trace):
                errors.append(f'[{cname}] retiro {len(commits)} instrucciones, ISS {len(iss.trace)}')
        if stores != iss.stores:
            k = next((i for i, (a, b) in enumerate(zip(stores, iss.stores)) if a != b), min(len(stores), len(iss.stores)))
            errors.append(f'[{cname}] stores difieren en #{k}: rtl {stores[k:k+1]} iss {iss.stores[k:k+1]}')
        if halt_pc is None and tohost != iss.tohost:
            errors.append(f'[{cname}] tohost rtl={tohost} iss={iss.tohost}')
        if errors:
            break
    return errors, stats_out, len(iss.trace)


# ---------------------------------------------------------------------------
# Programas aleatorios
# ---------------------------------------------------------------------------
def random_program(rng, n_blocks=40):
    """
    Registros reservados: x31 = base de datos (0x10000), x30 = scratch para
    JALR, x29 = contador de loops. El resto se usa libremente, eligiendo
    fuentes entre los ultimos destinos para forzar dependencias cercanas.
    """
    free = list(range(1, 29))
    recent = []
    lines = ['.section .text.init', '.globl _start', '_start:',
             '  li x31, 0x10000']
    for r in free:
        lines.append(f'  li x{r}, {rng.randrange(-(1 << 31), 1 << 31)}')
    lab = [0]

    def newlab():
        lab[0] += 1
        return f'L{lab[0]}'

    def src():
        if recent and rng.random() < 0.6:
            return rng.choice(recent[-3:])
        return rng.choice([0] + free)

    def dst():
        r = rng.choice(free)
        recent.append(r)
        return r

    def alu_op():
        p = rng.random()
        if p < 0.45:
            op = rng.choice(['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and'])
            s1, s2 = src(), src()
            return f'  {op} x{dst()}, x{s1}, x{s2}'
        if p < 0.75:
            op = rng.choice(['addi', 'slti', 'sltiu', 'xori', 'ori', 'andi'])
            s1 = src()
            return f'  {op} x{dst()}, x{s1}, {rng.randrange(-2048, 2048)}'
        if p < 0.88:
            op = rng.choice(['slli', 'srli', 'srai'])
            s1 = src()
            return f'  {op} x{dst()}, x{s1}, {rng.randrange(32)}'
        if p < 0.94:
            return f'  lui x{dst()}, {rng.randrange(1 << 20)}'
        return f'  auipc x{dst()}, {rng.randrange(1 << 20)}'

    def mem_op():
        kind = rng.choice(['lw', 'lh', 'lhu', 'lb', 'lbu', 'sw', 'sh', 'sb'])
        size = {'w': 4, 'h': 2, 'b': 1}[kind[1]]
        off = rng.randrange(0, 1024 // size) * size
        if kind[0] == 'l':
            return [f'  {kind} x{dst()}, {off}(x31)']
        s = src()
        return [f'  {kind} x{s}, {off}(x31)']

    def straight(n):
        out = []
        for _ in range(n):
            if rng.random() < 0.3:
                out += mem_op()
            else:
                out.append(alu_op())
            # load seguido de uso inmediato
            if out[-1].lstrip().startswith('l') and not out[-1].lstrip().startswith('lui') and rng.random() < 0.5:
                out.append(alu_op())
        return out

    for _ in range(n_blocks):
        p = rng.random()
        if p < 0.35:                                   # branch hacia adelante
            l = newlab()
            op = rng.choice(['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'])
            pre = straight(rng.randrange(0, 3))
            s1, s2 = src(), src()
            lines += pre + [f'  {op} x{s1}, x{s2}, {l}'] + straight(rng.randrange(1, 5)) + [f'{l}:']
        elif p < 0.50:                                 # loop con contador
            l = newlab()
            lines += [f'  li x29, {rng.randrange(1, 6)}', f'{l}:'] + straight(rng.randrange(1, 6)) + \
                     ['  addi x29, x29, -1', f'  bnez x29, {l}']
        elif p < 0.60:                                 # llamada JAL/JALR a subrutina inline
            l_fn, l_ret = newlab(), newlab()
            link = rng.choice([1, 5, 7])
            free.remove(link)                    # el cuerpo no puede pisar el link
            recent[:] = [r for r in recent if r != link]
            body = straight(rng.randrange(1, 4))
            free.append(link)
            lines += [f'  jal x{link}, {l_fn}', f'  j {l_ret}', f'{l_fn}:'] + body + \
                     [f'  jalr x0, 0(x{link})', f'{l_ret}:']
            recent.append(link)
        elif p < 0.68:                                 # JALR calculado con auipc
            l = newlab()
            r = dst()
            lines += [f'  la x30, {l}', f'  jalr x{r}, 0(x30)'] + straight(rng.randrange(1, 3)) + [f'{l}:']
        else:
            lines += straight(rng.randrange(2, 8))

    # Volcar algunos registros a memoria para que el resultado quede en stores
    lines += [f'  sw x{r}, {4 * r + 1024}(x31)' for r in free]
    lines += ['  li t6, 0x80000000', '  li t5, 1', '  sw t5, 0(t6)', '1: j 1b']
    return '\n'.join(lines) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--suite', choices=['all', 'riscv-tests', 'c', 'random'], default='all')
    ap.add_argument('--random', type=int, default=100)
    ap.add_argument('--only')
    ap.add_argument('--rvtests', default=os.path.join(os.path.dirname(ROOT), 'riscv-tests'))
    ap.add_argument('--vcd', action='store_true')
    ap.add_argument('--cond', help='correr solo estas condiciones (ej: m10k o lat0,lat3)')
    ap.add_argument('-j', dest='jobs', type=int, default=1, help='tests en paralelo')
    ap.add_argument('--gate', metavar='NETLIST.vo',
                    help='simular el netlist post-fit de Quartus (ver gate_sim/) en vez del RTL')
    ap.add_argument('--simlib', metavar='DIR',
                    help='carpeta quartus/eda/sim_lib (cyclonev_atoms.v, altera_primitives.v)')
    a = ap.parse_args()
    global GATE
    if a.gate:
        if not a.simlib:
            sys.exit('--gate necesita --simlib')
        GATE = (os.path.abspath(a.gate), os.path.abspath(a.simlib))

    compile_rtl()
    tests = []   # (name, builder)

    if a.suite in ('all', 'riscv-tests'):
        rv = os.path.join(a.rvtests, 'isa')
        skip = {'fence_i', 'ma_data'}        # auto-modificacion de codigo / desalineados
        for s in sorted(glob.glob(os.path.join(rv, 'rv32ui', '*.S'))):
            n = os.path.basename(s)[:-2]
            if n in skip:
                continue
            tests.append((f'rv32ui-{n}', lambda n=n, s=s: build(
                f'rv32ui-{n}', [s], ['-I', os.path.join(rv, 'macros', 'scalar'), '-I', COMMON])))

    if a.suite in ('all', 'c'):
        for s in sorted(glob.glob(os.path.join(ROOT, 'sw', 'tests', '*.c'))):
            n = os.path.basename(s)[:-2]
            tests.append((f'c-{n}', lambda n=n, s=s: build(
                f'c-{n}', [os.path.join(COMMON, 'crt0.S'), s], ['-O2'])))
        for s in sorted(glob.glob(os.path.join(ROOT, 'sw', 'tests', '*.S'))):
            n = os.path.basename(s)[:-2]           # tests dirigidos en assembler
            tests.append((f'asm-{n}', lambda n=n, s=s: build(f'asm-{n}', [s])))

    if a.suite in ('all', 'random'):
        for k in range(a.random):
            def b(k=k):
                path = os.path.join(BUILD, f'rand_{k}.S')
                open(path, 'w').write(random_program(random.Random(k)))
                return build(f'rand_{k}', [path])
            tests.append((f'rand-{k}', b))

    if a.only:
        exact = [t for t in tests if t[0] == a.only]
        tests = exact or [t for t in tests if a.only in t[0]]
    conds = CONDITIONS
    if a.cond:
        conds = [c for c in CONDITIONS if c[0] in a.cond.split(',')]
        if not conds:
            sys.exit('condiciones validas: ' + ', '.join(c[0] for c in CONDITIONS))

    def one(t):
        name, builder = t
        try:
            base, imem, dmem = builder()
            return run_test(name, base, imem, dmem, vcd=a.vcd, conds=conds)
        except Exception as e:      # noqa: BLE001
            return [f'excepcion: {e}'], '', 0

    fails, total_i = 0, 0
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
        for (name, _), (errs, stats, ni) in zip(tests, ex.map(one, tests)):
            total_i += ni
            if errs:
                fails += 1
                print(f'[FAIL] {name}')
                for e in errs[:6]:
                    print('       ' + e)
            elif not name.startswith('rand-') or a.only or GATE:
                print(f'[PASS] {name:28s} {stats}', flush=True)
    print(f'\n{len(tests) - fails}/{len(tests)} tests OK  ({total_i} instrucciones comparadas por condicion)')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
