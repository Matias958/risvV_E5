#!/usr/bin/env python3
"""Arma el .gtkw final a partir de la plantilla:
  - pone la ruta del desensamblador (rv_dis.py)
  - si se le pasa el .elf, busca las etiquetas caso1_..caso9_ del programa,
    encuentra en el VCD el ciclo en que cada una entra a ID y pone ahi los
    marcadores A, B, C... de GTKWave. Imprime la leyenda.

uso: marcadores.py plantilla.gtkw.in salida.gtkw tb_core.vcd [prog.elf]
"""
import os
import subprocess
import sys

tpl, out, vcd = sys.argv[1:4]
elf = sys.argv[4] if len(sys.argv) > 4 else None
here = os.path.dirname(os.path.abspath(__file__))
text = open(tpl).read().replace('@@DIS@@', os.path.join(here, 'rv_dis.py'))


def vcd_values(path, names):
    """Devuelve {nombre: [(tiempo, valor), ...]} para señales de tb_core."""
    ids, scope, res = {}, [], {n: [] for n in names}
    t = 0
    with open(path) as f:
        for line in f:
            w = line.split()
            if not w:
                continue
            if w[0] == '$scope':
                scope.append(w[2])
            elif w[0] == '$upscope':
                scope.pop()
            elif w[0] == '$var' and scope == ['tb_core'] and w[4] in names:
                ids[w[3]] = w[4]
            elif w[0][0] == '#':
                t = int(w[0][1:])
            elif w[0][0] == 'b' and len(w) == 2 and w[1] in ids:
                v = w[0][1:]
                res[ids[w[1]]].append((t, int(v, 2) if set(v) <= {'0', '1'} else None))
    return res


legend = []
markers = []
start = None
if elf:
    syms = []
    for line in subprocess.run(['riscv64-unknown-elf-nm', '-n', elf], capture_output=True,
                               text=True).stdout.splitlines():
        a, _, n = line.split()
        if n.startswith('caso'):
            syms.append((int(a, 16), n))
    v = vcd_values(vcd, ['ID_pc', 'ID_instr'])
    pcs, ins = v['ID_pc'], v['ID_instr']

    def at(lst, t):
        val = None
        for tt, vv in lst:
            if tt > t:
                break
            val = vv
        return val
    times = sorted({tt for tt, _ in pcs} | {tt for tt, _ in ins})
    for addr, name in syms:
        for tt in times:
            if at(pcs, tt) == addr and at(ins, tt):
                markers.append(tt)
                legend.append((chr(ord('A') + len(markers) - 1), tt, name))
                break
    if markers:
        start = max(0, markers[0] - 40000)

if not elf and '[timestart] auto' in text:   # primer $dumpon del VCD (ondas por ventanas)
    t = 0
    with open(vcd) as f:
        for line in f:
            if line.startswith('#'):
                t = int(line[1:])
            elif line.startswith('$dumpon'):
                start = t
                break

named = markers + [-1] * (26 - len(markers))
zoom = [l for l in text.splitlines() if l.startswith('*')]
z = zoom[0].split()[0] if zoom else '*-15.000000'
newz = z + ' -1 ' + ' '.join(str(x) for x in named)
text = '\n'.join(newz if l.startswith('*') else
                 (f'[timestart] {start}' if l.startswith('[timestart]') and start is not None else l)
                 for l in text.splitlines()) + '\n'
open(out, 'w').write(text)
for letter, tt, name in legend:
    print(f'  marcador {letter}  {tt / 1000:7.0f} ns  {name}')
