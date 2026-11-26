# ============================================================================
# mvp0_basic.s - Test dirigido del MVP-0
# Cubre todas las operaciones de ALU, casos borde de shifts y comparaciones,
# LUI/AUIPC, escrituras a x0, y que saltos/memoria/FENCE/SYSTEM sean NOP.
# ============================================================================

# ---- Carga de constantes ----
        li   x1, 5
        li   x2, -3                 # 0xFFFFFFFD
        li   x3, 0x7FFFFFFF         # lui + addi
        li   x4, 0x80000000
        li   x5, 0x12345FFF         # caso lo12 negativo (lui compensa)
        lui  x6, 0xABCDE
        auipc x7, 0x1               # x7 = pc + 0x1000

# ---- R-type ----
        add  x8,  x1, x2            # 2
        sub  x9,  x1, x2            # 8
        add  x10, x3, x1            # overflow -> 0x80000004
        sub  x11, x4, x1            # 0x7FFFFFFB
        and  x12, x5, x6
        or   x13, x5, x6
        xor  x14, x5, x6
        slt  x15, x2, x1            # -3 < 5  -> 1
        sltu x16, x2, x1            # 0xFFFFFFFD < 5 -> 0
        slt  x17, x4, x3            # INT_MIN < INT_MAX -> 1
        sltu x18, x4, x3            # 0
        sll  x19, x1, x1            # 5 << 5 = 160
        srl  x20, x4, x1            # logico
        sra  x21, x4, x1            # aritmetico -> 0xFC000000
        li   x22, 33                # shamt = 33 & 31 = 1
        sll  x23, x1, x22           # 10
        sra  x24, x2, x22           # -2

# ---- I-type ----
        addi  x25, x2, -2048        # imm minimo
        addi  x26, x2, 2047         # imm maximo
        slti  x27, x2, -2           # -3 < -2 -> 1
        sltiu x28, x1, -1           # 5 < 0xFFFFFFFF -> 1
        xori  x29, x1, -1           # not
        ori   x30, x1, 0x7F0
        andi  x31, x2, 0x0F0
        slli  x8,  x3, 31
        srli  x9,  x4, 31           # 1
        srai  x10, x4, 31           # -1
        srai  x11, x3, 0

# ---- Escrituras a x0 se ignoran ----
        addi x0, x0, 123
        lui  x0, 0xFFFFF
        add  x12, x0, x0            # 0

# ---- Deben ser NOP en el MVP-0 ----
        beq  x0, x0, 8              # sin control de saltos todavia
        jal  x13, 8                 # no escribe x13 ni salta
        jalr x14, 0(x1)
        lw   x15, 0(x0)             # sin memoria de datos
        sw   x1, 0(x0)
        fence
        ecall
        ebreak

# ---- Dependencias encadenadas (single-cycle: siempre correcto) ----
        addi x16, x0, 1
        add  x16, x16, x16
        add  x16, x16, x16
        add  x16, x16, x16          # 8
        sub  x17, x16, x1           # 3
