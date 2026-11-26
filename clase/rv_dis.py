#!/usr/bin/env python3
"""Filtro de GTKWave: convierte palabras de instruccion RV32I (en hex) a texto.

GTKWave le manda un valor por linea y espera una linea de respuesta.
Se usa como "Translate Filter Process" en los archivos .gtkw de esta carpeta.
Tambien sirve desde la terminal:  echo 00a00513 | ./rv_dis.py
"""
import sys

ABI = ['zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2', 's0', 's1', 'a0', 'a1',
       'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 's2', 's3', 's4', 's5', 's6', 's7',
       's8', 's9', 's10', 's11', 't3', 't4', 't5', 't6']


def sx(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


def dis(w):
    if w == 0:
        return '-- burbuja --'
    if w == 0x00000013:
        return 'nop'
    op = w & 0x7F
    rd, f3 = (w >> 7) & 31, (w >> 12) & 7
    rs1, rs2, f7 = (w >> 15) & 31, (w >> 20) & 31, w >> 25
    r = ABI
    i_imm = sx(w >> 20, 12)
    s_imm = sx(((w >> 25) << 5) | ((w >> 7) & 31), 12)
    b_imm = sx((((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11) |
               (((w >> 25) & 63) << 5) | (((w >> 8) & 15) << 1), 13)
    j_imm = sx((((w >> 31) & 1) << 20) | (((w >> 12) & 255) << 12) |
               (((w >> 20) & 1) << 11) | (((w >> 21) & 1023) << 1), 21)
    if op == 0x37:
        return f'lui {r[rd]},0x{w >> 12:x}'
    if op == 0x17:
        return f'auipc {r[rd]},0x{w >> 12:x}'
    if op == 0x6F:
        return f'jal {r[rd]},{j_imm:+d}' if rd else f'j {j_imm:+d}'
    if op == 0x67:
        if rd == 0 and rs1 == 1 and i_imm == 0:
            return 'ret'
        return f'jalr {r[rd]},{i_imm}({r[rs1]})'
    if op == 0x63:
        n = {0: 'beq', 1: 'bne', 4: 'blt', 5: 'bge', 6: 'bltu', 7: 'bgeu'}.get(f3, '?b')
        if rs2 == 0 and n in ('beq', 'bne'):
            return f'{n}z {r[rs1]},{b_imm:+d}'
        return f'{n} {r[rs1]},{r[rs2]},{b_imm:+d}'
    if op == 0x03:
        n = {0: 'lb', 1: 'lh', 2: 'lw', 4: 'lbu', 5: 'lhu'}.get(f3, '?l')
        return f'{n} {r[rd]},{i_imm}({r[rs1]})'
    if op == 0x23:
        n = {0: 'sb', 1: 'sh', 2: 'sw'}.get(f3, '?s')
        return f'{n} {r[rs2]},{s_imm}({r[rs1]})'
    if op == 0x13:
        if f3 == 0 and rs1 == 0:
            return f'li {r[rd]},{i_imm}'
        if f3 == 1:
            return f'slli {r[rd]},{r[rs1]},{rs2}'
        if f3 == 5:
            return f"{'srai' if f7 & 0x20 else 'srli'} {r[rd]},{r[rs1]},{rs2}"
        n = {0: 'addi', 2: 'slti', 3: 'sltiu', 4: 'xori', 6: 'ori', 7: 'andi'}[f3]
        return f'{n} {r[rd]},{r[rs1]},{i_imm}'
    if op == 0x33:
        n = {(0, 0): 'add', (0, 0x20): 'sub', (1, 0): 'sll', (2, 0): 'slt', (3, 0): 'sltu',
             (4, 0): 'xor', (5, 0): 'srl', (5, 0x20): 'sra', (6, 0): 'or', (7, 0): 'and'}.get((f3, f7), '?r')
        return f'{n} {r[rd]},{r[rs1]},{r[rs2]}'
    if op == 0x0F:
        return 'fence'
    if op == 0x73:
        return {0x00000073: 'ecall', 0x00100073: 'ebreak'}.get(w, 'system')
    return f'?? {w:08x}'


def main():
    for line in sys.stdin:
        t = line.strip()
        try:
            out = dis(int(t, 16))
        except ValueError:
            out = t                      # X, Z o vacio: se muestra tal cual
        sys.stdout.write(out + '\n')
        sys.stdout.flush()


if __name__ == '__main__':
    main()
