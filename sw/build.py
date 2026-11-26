#!/usr/bin/env python3
"""
build.py - Compila un programa en C o assembler para el ERV26 y deja los
archivos de inicializacion de memoria listos para Quartus o simulacion.

    python3 sw/build.py sw/demo/leds.c                  # -> raiz del proyecto
    python3 sw/build.py prog.c -o otra/carpeta -O2
    python3 sw/build.py prog.c -DSIM                    # flags extra a gcc

Genera en la carpeta destino: imem.hex, imem.mif, dmem.hex, dmem_b0..3.hex,
prog.elf y prog.lst (desensamblado).
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import elf2hex  # noqa: E402

COMMON = os.path.join(HERE, 'common')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src', nargs='+')
    ap.add_argument('-o', '--out', default=ROOT)
    ap.add_argument('-O', dest='opt', default='2')
    a, extra = ap.parse_known_args()

    os.makedirs(a.out, exist_ok=True)
    elf = os.path.join(a.out, 'prog.elf')
    srcs = list(a.src)
    if any(s.endswith('.c') for s in srcs):          # C: agregar el arranque
        srcs = [os.path.join(COMMON, 'crt0.S')] + srcs
    cmd = ['riscv64-unknown-elf-gcc', '-march=rv32i', '-mabi=ilp32', f'-O{a.opt}',
           '-nostdlib', '-nostartfiles', '-static', '-ffreestanding',
           '-T', os.path.join(COMMON, 'link.ld'), '-I', COMMON] + extra + srcs + ['-lgcc', '-o', elf]
    r = subprocess.run(cmd)
    if r.returncode:
        sys.exit(r.returncode)

    imem, dmem = elf2hex.load(elf)
    iw, dw = elf2hex.words(imem), elf2hex.words(dmem)
    if len(iw) > 4096 or len(dw) > 4096:
        sys.exit(f'el programa no entra: imem {len(iw)} / dmem {len(dw)} palabras (max 4096)')
    w = lambda n, s: open(os.path.join(a.out, n), 'w').write(s)
    w('imem.hex', ''.join(f'{x:08x}\n' for x in iw))
    w('dmem.hex', ''.join(f'{x:08x}\n' for x in dw) or '00000000\n')
    for k in range(4):
        w(f'dmem_b{k}.hex', ''.join(f'{(x >> (8 * k)) & 0xFF:02x}\n' for x in dw) or '00\n')
    with open(os.path.join(a.out, 'imem.mif'), 'w') as f:
        f.write('DEPTH = 4096;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT BEGIN\n')
        for i, x in enumerate(iw):
            f.write(f'  {i:03x} : {x:08x};\n')
        if len(iw) < 4096:
            f.write(f'  [{len(iw):03x}..fff] : 00000013;\n')
        f.write('END;\n')
    lst = subprocess.run(['riscv64-unknown-elf-objdump', '-d', '-M', 'no-aliases', elf],
                         capture_output=True, text=True).stdout
    w('prog.lst', lst)
    print(f'OK: imem {len(iw)}/4096 palabras, dmem {len(dw)}/4096 palabras -> {a.out}')


if __name__ == '__main__':
    main()
