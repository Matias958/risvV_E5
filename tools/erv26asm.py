#!/usr/bin/env python3
"""
erv26asm.py - Mini ensamblador RV32I para el ERV26.

Uso:
    python3 erv26asm.py programa.s -o program.hex [--words words.hex] [--mif program.mif]

Salidas:
    program.hex : un byte por linea (para $readmemh de erv26_prog_mem)
    --words     : una palabra de 32 bits por linea (util para debug)
    --mif       : Memory Initialization File de Quartus (ancho 8 bits)

Soporta todo RV32I, nombres ABI (a0, sp, ...), etiquetas, comentarios (# y //)
y pseudo-instrucciones: nop, li, mv, not, neg, j, jr, ret, call (corto),
beqz, bnez, seqz, snez, la (via auipc+addi), .word
"""
import re
import sys
import argparse

ABI = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4, 't0': 5, 't1': 6, 't2': 7,
    's0': 8, 'fp': 8, 's1': 9, 'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14,
    'a5': 15, 'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21,
    's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27, 't3': 28,
    't4': 29, 't5': 30, 't6': 31,
}

R_OPS = {  # funct7, funct3
    'add': (0x00, 0), 'sub': (0x20, 0), 'sll': (0x00, 1), 'slt': (0x00, 2),
    'sltu': (0x00, 3), 'xor': (0x00, 4), 'srl': (0x00, 5), 'sra': (0x20, 5),
    'or': (0x00, 6), 'and': (0x00, 7),
}
I_ALU = {'addi': 0, 'slti': 2, 'sltiu': 3, 'xori': 4, 'ori': 6, 'andi': 7}
SHIFT_I = {'slli': (0x00, 1), 'srli': (0x00, 5), 'srai': (0x20, 5)}
LOADS = {'lb': 0, 'lh': 1, 'lw': 2, 'lbu': 4, 'lhu': 5}
STORES = {'sb': 0, 'sh': 1, 'sw': 2}
BRANCHES = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}


class AsmError(Exception):
    pass


def reg(tok):
    tok = tok.strip().lower()
    if tok in ABI:
        return ABI[tok]
    m = re.fullmatch(r'x(\d+)', tok)
    if m and int(m.group(1)) < 32:
        return int(m.group(1))
    raise AsmError(f"registro invalido: {tok}")


def check_range(v, bits, signed, what):
    lo, hi = (-(1 << (bits - 1)), (1 << (bits - 1)) - 1) if signed else (0, (1 << bits) - 1)
    if not lo <= v <= hi:
        raise AsmError(f"{what} fuera de rango ({v}, {bits} bits)")


def enc_r(f7, rs2, rs1, f3, rd, opc):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc


def enc_i(imm, rs1, f3, rd, opc):
    check_range(imm, 12, True, "inmediato I")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc


def enc_s(imm, rs2, rs1, f3, opc):
    check_range(imm, 12, True, "inmediato S")
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | opc


def enc_b(off, rs2, rs1, f3, opc=0x63):
    check_range(off, 13, True, "offset de branch")
    if off & 1:
        raise AsmError("offset de branch impar")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | opc


def enc_u(imm20, rd, opc):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | opc


def enc_j(off, rd, opc=0x6F):
    check_range(off, 21, True, "offset de jal")
    if off & 1:
        raise AsmError("offset de jal impar")
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
           (((o >> 12) & 0xFF) << 12) | (rd << 7) | opc


def split_hi_lo(v):
    """Divide un valor de 32 bits en (hi20, lo12) para lui/auipc + addi."""
    v &= 0xFFFFFFFF
    lo = v & 0xFFF
    if lo & 0x800:
        lo -= 0x1000
    hi = ((v - lo) >> 12) & 0xFFFFF
    return hi, lo


def parse_mem(tok):
    m = re.fullmatch(r'\s*(.*?)\s*\(\s*(\w+)\s*\)\s*', tok)
    if not m:
        raise AsmError(f"operando de memoria invalido: {tok}")
    off = m.group(1) or '0'
    return off, reg(m.group(2))


class Assembler:
    def __init__(self):
        self.labels = {}

    def value(self, tok, pc=None, rel=False):
        tok = tok.strip()
        if tok in self.labels:
            v = self.labels[tok]
            return v - pc if rel else v
        try:
            return int(tok, 0)
        except ValueError:
            raise AsmError(f"valor o etiqueta desconocida: {tok}")

    @staticmethod
    def clean(lines):
        out = []
        for n, line in enumerate(lines, 1):
            line = line.split('#')[0].split('//')[0].strip()
            if line:
                out.append((n, line))
        return out

    @staticmethod
    def split(line):
        parts = line.split(None, 1)
        mn = parts[0].lower()
        ops = [o.strip() for o in parts[1].split(',')] if len(parts) > 1 else []
        return mn, ops

    def size(self, mn, ops):
        """Tamano en bytes de cada linea (pass 1)."""
        if mn == 'li':
            v = int(ops[1], 0)
            return 4 if -2048 <= v <= 2047 else 8
        if mn == 'la':
            return 8
        return 4

    def expand(self, mn, ops, pc):
        """Devuelve lista de palabras de 32 bits."""
        # ---- pseudo-instrucciones ----
        if mn == 'nop':
            return [enc_i(0, 0, 0, 0, 0x13)]
        if mn == 'mv':
            return [enc_i(0, reg(ops[1]), 0, reg(ops[0]), 0x13)]
        if mn == 'not':
            return [enc_i(-1, reg(ops[1]), 4, reg(ops[0]), 0x13)]
        if mn == 'neg':
            return [enc_r(0x20, reg(ops[1]), 0, 0, reg(ops[0]), 0x33)]
        if mn == 'seqz':
            return [enc_i(1, reg(ops[1]), 3, reg(ops[0]), 0x13)]
        if mn == 'snez':
            return [enc_r(0, reg(ops[1]), 0, 3, reg(ops[0]), 0x33)]
        if mn == 'li':
            rd, v = reg(ops[0]), self.value(ops[1])
            if -2048 <= v <= 2047:
                return [enc_i(v, 0, 0, rd, 0x13)]
            hi, lo = split_hi_lo(v)
            return [enc_u(hi, rd, 0x37), enc_i(lo, rd, 0, rd, 0x13)]
        if mn == 'la':
            rd = reg(ops[0])
            hi, lo = split_hi_lo(self.value(ops[1], pc, rel=True))
            return [enc_u(hi, rd, 0x17), enc_i(lo, rd, 0, rd, 0x13)]
        if mn == 'j':
            return [enc_j(self.value(ops[0], pc, True), 0)]
        if mn == 'call':
            return [enc_j(self.value(ops[0], pc, True), 1)]
        if mn == 'jr':
            return [enc_i(0, reg(ops[0]), 0, 0, 0x67)]
        if mn == 'ret':
            return [enc_i(0, 1, 0, 0, 0x67)]
        if mn == 'beqz':
            return [enc_b(self.value(ops[1], pc, True), 0, reg(ops[0]), 0)]
        if mn == 'bnez':
            return [enc_b(self.value(ops[1], pc, True), 0, reg(ops[0]), 1)]
        if mn == '.word':
            return [self.value(ops[0]) & 0xFFFFFFFF]

        # ---- RV32I ----
        if mn in R_OPS:
            f7, f3 = R_OPS[mn]
            return [enc_r(f7, reg(ops[2]), reg(ops[1]), f3, reg(ops[0]), 0x33)]
        if mn in I_ALU:
            return [enc_i(self.value(ops[2]), reg(ops[1]), I_ALU[mn], reg(ops[0]), 0x13)]
        if mn in SHIFT_I:
            f7, f3 = SHIFT_I[mn]
            sh = self.value(ops[2])
            check_range(sh, 5, False, "shamt")
            return [enc_r(f7, sh, reg(ops[1]), f3, reg(ops[0]), 0x13)]
        if mn in LOADS:
            off, rs1 = parse_mem(ops[1])
            return [enc_i(self.value(off), rs1, LOADS[mn], reg(ops[0]), 0x03)]
        if mn in STORES:
            off, rs1 = parse_mem(ops[1])
            return [enc_s(self.value(off), reg(ops[0]), rs1, STORES[mn], 0x23)]
        if mn in BRANCHES:
            return [enc_b(self.value(ops[2], pc, True), reg(ops[1]), reg(ops[0]), BRANCHES[mn])]
        if mn == 'lui':
            return [enc_u(self.value(ops[1]), reg(ops[0]), 0x37)]
        if mn == 'auipc':
            return [enc_u(self.value(ops[1]), reg(ops[0]), 0x17)]
        if mn == 'jal':
            if len(ops) == 1:
                return [enc_j(self.value(ops[0], pc, True), 1)]
            return [enc_j(self.value(ops[1], pc, True), reg(ops[0]))]
        if mn == 'jalr':
            if len(ops) == 1:
                return [enc_i(0, reg(ops[0]), 0, 1, 0x67)]
            if '(' in ops[1]:
                off, rs1 = parse_mem(ops[1])
                return [enc_i(self.value(off), rs1, 0, reg(ops[0]), 0x67)]
            return [enc_i(self.value(ops[2]), reg(ops[1]), 0, reg(ops[0]), 0x67)]
        if mn == 'fence':
            return [0x0FF0000F]
        if mn == 'ecall':
            return [0x00000073]
        if mn == 'ebreak':
            return [0x00100073]
        raise AsmError(f"instruccion desconocida: {mn}")

    def assemble(self, text):
        lines = self.clean(text.splitlines())
        # Pass 1: etiquetas
        pc, items = 0, []
        for n, line in lines:
            while ':' in line:
                lab, line = line.split(':', 1)
                self.labels[lab.strip()] = pc
                line = line.strip()
            if not line:
                continue
            mn, ops = self.split(line)
            items.append((n, line, mn, ops, pc))
            pc += self.size(mn, ops)
        # Pass 2: codificacion
        words, listing = [], []
        for n, line, mn, ops, pc in items:
            try:
                ws = self.expand(mn, ops, pc)
            except (AsmError, IndexError, ValueError) as e:
                raise AsmError(f"linea {n}: '{line}': {e}")
            for k, w in enumerate(ws):
                listing.append((pc + 4 * k, w, line if k == 0 else ''))
            words.extend(ws)
        return words, listing


def write_outputs(words, hex_path=None, words_path=None, mif_path=None, depth=1024):
    data = b''.join(w.to_bytes(4, 'little') for w in words)
    if hex_path:
        with open(hex_path, 'w') as f:
            f.write('\n'.join(f'{b:02x}' for b in data) + '\n')
    if words_path:
        with open(words_path, 'w') as f:
            f.write('\n'.join(f'{w:08x}' for w in words) + '\n')
    if mif_path:
        with open(mif_path, 'w') as f:
            f.write(f'DEPTH = {depth};\nWIDTH = 8;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT BEGIN\n')
            for i, b in enumerate(data):
                f.write(f'  {i:04x} : {b:02x};\n')
            if len(data) < depth:
                f.write(f'  [{len(data):04x}..{depth - 1:04x}] : 00;\n')
            f.write('END;\n')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('src')
    ap.add_argument('-o', '--out', default='program.hex')
    ap.add_argument('--words')
    ap.add_argument('--mif')
    ap.add_argument('--depth', type=int, default=1024)
    ap.add_argument('-l', '--list', action='store_true', help='imprimir listado')
    a = ap.parse_args()
    try:
        words, listing = Assembler().assemble(open(a.src).read())
    except AsmError as e:
        sys.exit(f"error: {e}")
    write_outputs(words, a.out, a.words, a.mif, a.depth)
    if a.list:
        for pc, w, src in listing:
            print(f'{pc:08x}: {w:08x}   {src}')
    print(f"{len(words)} instrucciones -> {a.out}", file=sys.stderr)


if __name__ == '__main__':
    main()
