# ============================================================================
# Demo del pipeline para mostrar en clase (make pipeline).
# Cada bloque provoca un caso distinto; en GTKWave se ve la instruccion que
# hay en cada etapa (IF, ID, EX, MEM, WB) y las senales de control.
# Tambien corre en la regresion: se compara contra el ISS como los demas.
# ============================================================================
    .section .text.init
    .globl _start
_start:
    li   x31, 0x10000          # base de la memoria de datos
    li   s0, 0
    li   s1, 0

caso1_sin_dependencias:
    # 1) Sin dependencias: entra una instruccion por ciclo, CPI = 1
    addi t0, zero, 1
    addi t1, zero, 2
    addi t2, zero, 3

caso2_forwarding:
    # 2) Forwarding: el resultado se usa en la instruccion siguiente
    addi a0, zero, 5
    addi a1, a0, 1             # a0 desde MEM
    add  a2, a0, a1            # a0 desde WB, a1 desde MEM

caso3_load_use:
    # 3) Load-use: el dato del load recien esta en MEM -> 1 ciclo de stall
    sw   a2, 0(x31)
    lw   a3, 0(x31)
    addi a4, a3, 1             # espera un ciclo en ID
    # Con la RAM real de la placa ademas hay 1 ciclo de espera de memoria:
    # el lw lee la misma palabra que el sw esta escribiendo en ese flanco.

caso4_load_sin_stall:
    # 4) Load con una instruccion en el medio: sin stall
    lw   a5, 0(x31)
    addi t3, zero, 9
    add  a6, a5, a5            # a5 llega por forwarding desde WB

caso5_loop_btfn:
    # 5) Loop: el branch hacia atras se predice tomado en ID (BTFN).
    #    Solo la salida del loop esta mal predicha y se corrige en EX.
    li   t4, 3
1:  addi s0, s0, 1
    addi t4, t4, -1
    bnez t4, 1b

caso6_branch_adelante:
    # 6) Branch hacia adelante tomado: se predice no tomado -> se corrige en EX
    beq  zero, zero, 2f
    addi s1, s1, 100           # se busca pero se anula (flush)
2:
caso7_llamada:
    # 7) Llamada y retorno: jal salta desde ID, jalr (ret) se resuelve en EX
    jal  ra, funcion
    addi s2, s2, 1

    # Fin: resultado a memoria y TOHOST (el testbench termina aca)
    sw   s0, 4(x31)
    li   t6, 0x80000000
    li   t5, 1
    sw   t5, 0(t6)
3:  j    3b

funcion:
    addi s2, zero, 40
    ret
