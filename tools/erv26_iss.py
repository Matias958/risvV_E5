#!/usr/bin/env python3
"""
erv26_iss.py - Simulador de set de instrucciones (modelo de referencia) RV32I.

Decodifica los bits de forma independiente al ensamblador y se usa como
"golden model" para comparar contra el RTL.

Modos:
    full : RV32I completo (memoria de datos, saltos). Para el pipeline.
    mvp0 : igual que el MVP-0: LOAD/STORE/BRANCH/JAL/JALR no tienen efecto
           (no escriben rd, PC = PC+4).

Mapa de memoria (Harvard, mismo espacio de direcciones):
    0x0000_0000  memoria de programa (imem)
    0x0001_0000  memoria de datos    (dmem, inicializada con .rodata/.data)
    0x8000_0000  TOHOST: escribir termina la simulacion (1 = PASS)
    0x8000_0004  PUTCHAR: escribe un caracter en la consola
"""
M32 = 0xFFFFFFFF
TOHOST = 0x80000000
PUTCHAR = 0x80000004


def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


class ISS:
    def __init__(self, prog_bytes, mode='full', data_bytes=b'', data_base=0x10000):
        self.imem = bytearray(prog_bytes)
        self.dmem = {data_base + i: b for i, b in enumerate(data_bytes)}
        self.x = [0] * 32
        self.pc = 0
        self.mode = mode
        self.retired = 0
        self.trace = []        # (pc, instr, rd o None, valor)
        self.stores = []       # (addr alineada, be, dato enmascarado)
        self.tohost = None
        self.console = ''

    def fetch(self, a):
        b = self.imem[a:a + 4]
        b = b + bytes(4 - len(b))
        return int.from_bytes(b, 'little')

    def ld(self, a, n):
        if a >= 0x80000000:
            return 0
        return int.from_bytes(bytes(self.dmem.get(a + i, 0) for i in range(n)), 'little')

    def st(self, a, v, n):
        off = a & 3
        be = ((1 << n) - 1) << off
        data = ((v & ((1 << (8 * n)) - 1)) << (8 * off)) & M32
        self.stores.append((a & ~3 & M32, be, data))
        if a == TOHOST:
            self.tohost = v & M32
            return
        if a == PUTCHAR:
            self.console += chr(v & 0xFF)
            return
        for i in range(n):
            self.dmem[(a + i) & M32] = (v >> (8 * i)) & 0xFF

    def step(self):
        pc = self.pc
        i = self.fetch(pc)
        opc, rd, f3 = i & 0x7F, (i >> 7) & 0x1F, (i >> 12) & 7
        rs1, rs2 = (i >> 15) & 0x1F, (i >> 20) & 0x1F
        a, b = self.x[rs1], self.x[rs2]
        imm_i = sext(i >> 20, 12)
        imm_s = sext(((i >> 25) << 5) | ((i >> 7) & 0x1F), 12)
        imm_b = sext((((i >> 31) & 1) << 12) | (((i >> 7) & 1) << 11) |
                     (((i >> 25) & 0x3F) << 5) | (((i >> 8) & 0xF) << 1), 13)
        imm_u = i & 0xFFFFF000
        imm_j = sext((((i >> 31) & 1) << 20) | (((i >> 12) & 0xFF) << 12) |
                     (((i >> 20) & 1) << 11) | (((i >> 21) & 0x3FF) << 1), 21)
        npc = (pc + 4) & M32
        wr = None
        full = self.mode == 'full'

        def alu(x, y, f3, alt):
            sh = y & 0x1F
            if f3 == 0: return (x - y) if alt else (x + y)
            if f3 == 1: return x << sh
            if f3 == 2: return int(sext(x, 32) < sext(y, 32))
            if f3 == 3: return int((x & M32) < (y & M32))
            if f3 == 4: return x ^ y
            if f3 == 5: return (sext(x, 32) >> sh) if alt else ((x & M32) >> sh)
            if f3 == 6: return x | y
            return x & y

        if opc == 0x37:
            wr = imm_u
        elif opc == 0x17:
            wr = pc + imm_u
        elif opc == 0x13:
            alt = (f3 == 5) and ((i >> 30) & 1)
            wr = alu(a, imm_i & M32, f3, alt)
        elif opc == 0x33:
            wr = alu(a, b, f3, (i >> 30) & 1)
        elif opc == 0x6F and full:
            wr, npc = pc + 4, (pc + imm_j) & M32
        elif opc == 0x67 and full:
            wr, npc = pc + 4, (a + imm_i) & M32 & ~1
        elif opc == 0x63 and full:
            sa, sb = sext(a, 32), sext(b, 32)
            take = {0: a == b, 1: a != b, 4: sa < sb, 5: sa >= sb, 6: a < b, 7: a >= b}.get(f3, False)
            if take:
                npc = (pc + imm_b) & M32
        elif opc == 0x03 and full:
            ad = (a + imm_i) & M32
            n = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2}[f3]
            v = self.ld(ad, n)
            wr = sext(v, 8 * n) if f3 in (0, 1) else v
        elif opc == 0x23 and full:
            ad = (a + imm_s) & M32
            self.st(ad, b, {0: 1, 1: 2, 2: 4}[f3])
        # FENCE, SYSTEM -> NOP

        if wr is not None and rd != 0:
            self.x[rd] = wr & M32
            self.trace.append((pc, i, rd, wr & M32))
        else:
            self.trace.append((pc, i, None, 0))
        self.pc = npc
        self.retired += 1

    def run(self, n):
        for _ in range(n):
            self.step()
        return self

    def run_until(self, halt_pc=None, max_steps=2_000_000):
        """Corre hasta escribir TOHOST o llegar a halt_pc."""
        for _ in range(max_steps):
            if self.tohost is not None or (halt_pc is not None and self.pc == halt_pc):
                return self
            self.step()
        raise RuntimeError('ISS: limite de instrucciones alcanzado')
