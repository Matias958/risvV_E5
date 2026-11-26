#!/usr/bin/env python3
"""
elf2hex.py - Convierte un ELF del ERV26 en archivos de inicializacion.

    python3 elf2hex.py prog.elf -o build/prog

Genera:
    <out>.imem.hex          palabras de 32 bits (memoria de programa)
    <out>.dmem.hex          palabras de 32 bits (memoria de datos, desde DMEM_BASE)
    <out>.dmem_b{0..3}.hex  un archivo por carril de byte (para erv26_dmem en Quartus)
    <out>.imem.mif          MIF de Quartus (opcional, --mif)
"""
import argparse
import subprocess
import tempfile
import os

OBJCOPY = 'riscv64-unknown-elf-objcopy'
DMEM_BASE = 0x10000


def section_bin(elf, sections):
    with tempfile.NamedTemporaryFile(suffix='.bin', delete=False) as t:
        path = t.name
    args = [OBJCOPY, '-O', 'binary']
    for s in sections:
        args += ['-j', s]
    subprocess.run(args + [elf, path], check=True)
    data = open(path, 'rb').read()
    os.unlink(path)
    return data


def words(data):
    data = data + bytes(-len(data) % 4)
    return [int.from_bytes(data[i:i + 4], 'little') for i in range(0, len(data), 4)]


def load(elf):
    """Devuelve (bytes de imem desde 0, bytes de dmem desde DMEM_BASE)."""
    imem = section_bin(elf, ['.text'])
    dmem = section_bin(elf, ['.rodata', '.data'])
    # objcopy arranca el binario en la menor VMA de las secciones pedidas
    r = subprocess.run(['riscv64-unknown-elf-objdump', '-h', elf], capture_output=True, text=True, check=True)
    vmas = []
    for line in r.stdout.splitlines():
        p = line.split()
        if len(p) > 4 and p[1] in ('.rodata', '.data') and int(p[2], 16) > 0:
            vmas.append(int(p[3], 16))
    if dmem and vmas:
        dmem = bytes(min(vmas) - DMEM_BASE) + dmem
    return imem, dmem


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('elf')
    ap.add_argument('-o', '--out', required=True)
    ap.add_argument('--mif', action='store_true')
    ap.add_argument('--imem-words', type=int, default=4096)
    a = ap.parse_args()

    imem, dmem = load(a.elf)
    iw, dw = words(imem), words(dmem)
    open(a.out + '.imem.hex', 'w').write(''.join(f'{w:08x}\n' for w in iw))
    open(a.out + '.dmem.hex', 'w').write(''.join(f'{w:08x}\n' for w in dw) or '00000000\n')
    for k in range(4):
        open(f'{a.out}.dmem_b{k}.hex', 'w').write(
            ''.join(f'{(w >> (8 * k)) & 0xFF:02x}\n' for w in dw) or '00\n')
    if a.mif:
        with open(a.out + '.imem.mif', 'w') as f:
            f.write(f'DEPTH = {a.imem_words};\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT BEGIN\n')
            for i, w in enumerate(iw):
                f.write(f'  {i:04x} : {w:08x};\n')
            if len(iw) < a.imem_words:
                f.write(f'  [{len(iw):04x}..{a.imem_words - 1:04x}] : 00000013;\n')
            f.write('END;\n')
    print(f'imem: {len(iw)} palabras, dmem: {len(dw)} palabras')


if __name__ == '__main__':
    main()
