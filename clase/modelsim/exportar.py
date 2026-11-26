#!/usr/bin/env python3
"""Prepara lo que necesita ModelSim (que no tiene Python ni el gcc de RISC-V):

  gen/erv26_core_bdf.v, gen/risvV_E5_bdf.v   los .bdf convertidos a Verilog
  programas/<test>.imem.hex / .dmem.hex      programas ya compilados
  programas/<test>.esperado                  lo que debe retirar el nucleo,
                                             segun el modelo de referencia (ISS)
  programas/leds_sim.*.hex                   demo de LEDs con esperas cortas

Se corre desde WSL/Linux (make modelsim) despues de cambiar un .bdf o un test.
"""
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from erv26_iss import ISS      # noqa: E402
import elf2hex                 # noqa: E402

BUILD = os.path.join(ROOT, 'sim', 'build_core')
GEN = os.path.join(HERE, 'gen')
PROG = os.path.join(HERE, 'programas')


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(' '.join(cmd) + '\n' + r.stdout + r.stderr)


os.makedirs(GEN, exist_ok=True)
os.makedirs(PROG, exist_ok=True)
run([sys.executable, os.path.join(ROOT, 'tools', 'bdf2v.py'), os.path.join(ROOT, 'rtl', 'erv26_core.bdf'),
     'erv26_core', os.path.join(GEN, 'erv26_core_bdf.v')])
run([sys.executable, os.path.join(ROOT, 'tools', 'bdf2v.py'), os.path.join(ROOT, 'risvV_E5.bdf'),
     'risvV_E5', os.path.join(GEN, 'risvV_E5_bdf.v')])

# compilar todos los tests (sin los aleatorios) con el runner de la regresion
run([sys.executable, os.path.join(ROOT, 'sim', 'run_core_tests.py'), '--random', '0', '--cond', 'lat0'])

names = []
for elf in sorted(glob.glob(os.path.join(BUILD, '*.elf'))):
    name = os.path.basename(elf)[:-4]
    if name.startswith('rand_'):
        continue
    imem, dmem = elf2hex.load(elf)
    iw, dw = elf2hex.words(imem), elf2hex.words(dmem)
    base = os.path.join(PROG, name)
    open(base + '.imem.hex', 'w').write(''.join(f'{w:08x}\n' for w in iw))
    open(base + '.dmem.hex', 'w').write(''.join(f'{w:08x}\n' for w in dw) or '00000000\n')
    iss = ISS(imem, 'full', dmem)
    iss.run_until(None)
    with open(base + '.esperado', 'w') as f:
        for pc, ins, rd, v in iss.trace:
            f.write(f'C {pc:08x} {ins:08x} - 0\n' if rd is None else f'C {pc:08x} {ins:08x} {rd} {v:08x}\n')
        for a, be, d in iss.stores:
            f.write(f'S {a:08x} {be:x} {d:08x}\n')
    names.append(name)
open(os.path.join(PROG, 'lista.txt'), 'w').write('\n'.join(names) + '\n')

# demo de LEDs para la simulacion de la placa (esperas de 250 ciclos)
run([sys.executable, os.path.join(ROOT, 'sw', 'build.py'), os.path.join(ROOT, 'sw', 'demo', 'leds.c'),
     '-DSIM', '-o', os.path.join(PROG, 'leds_sim')])
print(f'{len(names)} programas exportados a {PROG}')
