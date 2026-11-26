# ============================================================================
# Casos borde de la prediccion de saltos BTFN (hacia atras tomado, hacia
# adelante no tomado). El runner lo compara instruccion por instruccion
# contra el ISS en las 5 condiciones de memoria y halt.
# ============================================================================
    .section .text.init
    .globl _start
_start:
    li   x31, 0x10000          # base de datos
    li   s0, 0                 # acumulador

    # 1) Loop con branch hacia atras: tomado 4 veces, no tomado al salir
    li   t0, 5
1:  addi s0, s0, 1
    addi t0, t0, -1
    bnez t0, 1b                # depende del addi anterior (forwarding EX->EX)

    # 2) Branch hacia atras que depende de un load inmediatamente anterior
    #    (stall load-use con el branch en ID, que ademas se predice tomado)
    sw   zero, 0(x31)
    li   t1, 3
    sw   t1, 4(x31)
    sw   t1, 8(x31)
    sw   t1, 12(x31)
    addi a0, x31, 16
2:  addi a0, a0, -4
    lw   t2, 0(a0)
    bnez t2, 2b                # load-use contra el branch; sale cuando lee 0

    # 3) Branch hacia atras NO tomado la primera vez (mal predicho de entrada)
    li   t3, 0
3:  addi s0, s0, 7
    bnez t3, 3b                # predicho tomado, no se toma

    # 4) Dos branches hacia atras seguidos (el 2do entra a ID cuando el 1ro
    #    esta en EX); loop anidado corto
    li   t4, 3
4:  li   t5, 2
5:  addi s0, s0, 3
    addi t5, t5, -1
    bnez t5, 5b
    addi t4, t4, -1
    bnez t4, 4b

    # 5) Branch hacia atras cuyo destino es otro branch hacia atras
    li   t0, 2
    j    7f
6:  addi t0, t0, -1
    bnez t0, 6b                # destino de un salto predicho
    j    8f
7:  bnez t0, 6b                # predicho tomado hacia un branch
8:
    # 6) Branch hacia adelante tomado y no tomado (como antes)
    li   t1, 1
    beqz t1, 9f                # no tomado (bien predicho)
    addi s0, s0, 11
    bnez t1, 9f                # tomado (mal predicho, 1 ciclo)
    addi s0, s0, 1000          # no se ejecuta
9:
    # 7) JALR justo despues de un branch hacia atras mal predicho
    la   t2, 10f
    li   t3, 0
    j    11f
12: addi s0, s0, 5
11: bnez t3, 12b               # predicho tomado, no se toma
    jalr x0, 0(t2)
    addi s0, s0, 2000          # no se ejecuta
10:
    # 8) Branch hacia atras con offset maximo de signo (salto lejano atras)
    li   t0, 1
    j    14f
13: addi s0, s0, 13
    addi t0, t0, -1
    .rept 200
    nop
    .endr
14: bnez t0, 13b

    # Resultado a memoria y fin (TOHOST)
    sw   s0, 0(x31)
    li   t6, 0x80000000
    li   t5, 1
    sw   t5, 0(t6)
15: j    15b
