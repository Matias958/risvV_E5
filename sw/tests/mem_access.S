# ============================================================================
# Casos borde del acceso a memoria de datos con lectura anticipada (M10K).
# El load que esta en EX hace leer su direccion a la RAM mientras el store
# anterior escribe en MEM: si es la misma palabra, la RAM no puede dar el
# dato en ese ciclo y tiene que esperar uno (ready=0).
# Se compara contra el ISS en las 5 condiciones de memoria.
# ============================================================================
    .section .text.init
    .globl _start
_start:
    li   x31, 0x10000          # base de datos
    li   s0, 0

    # 1) store y load inmediato a la MISMA palabra
    li   t0, 0x12345678
    sw   t0, 0(x31)
    lw   t1, 0(x31)
    add  s0, s0, t1

    # 2) store de byte y load de la palabra completa (misma palabra)
    li   t0, 0xAB
    sb   t0, 1(x31)
    lw   t1, 0(x31)
    add  s0, s0, t1

    # 3) store de media palabra y load de byte con signo (misma palabra)
    li   t0, 0x8081
    sh   t0, 2(x31)
    lb   t1, 3(x31)
    add  s0, s0, t1

    # 4) store a otra palabra y load inmediato (no hay conflicto)
    li   t0, 77
    sw   t0, 8(x31)
    lw   t1, 4(x31)
    lw   t2, 8(x31)
    add  s0, s0, t1
    add  s0, s0, t2

    # 5) loads seguidos con dependencia de direccion (lista enlazada)
    addi t0, x31, 64
    addi t1, x31, 80
    addi t2, x31, 96
    sw   t1, 64(x31)           # nodo0 -> nodo1
    sw   t2, 80(x31)           # nodo1 -> nodo2
    sw   zero, 96(x31)         # nodo2 -> null
    mv   a0, t0
1:  lw   a0, 0(a0)             # load que alimenta la direccion del siguiente
    addi s0, s0, 1
    bnez a0, 1b

    # 6) store seguido de dos loads a la misma palabra
    li   t0, -5
    sw   t0, 12(x31)
    lw   t1, 12(x31)
    lw   t2, 12(x31)
    add  s0, s0, t1
    add  s0, s0, t2

    # 7) load cuyo valor se usa como dato de un store a la misma palabra
    lw   t1, 0(x31)
    addi t1, t1, 1
    sw   t1, 0(x31)
    lw   t2, 0(x31)
    add  s0, s0, t2

    # 8) loop de copia: load y store alternados en direcciones vecinas
    li   t3, 8
    addi a1, x31, 128          # origen
    addi a2, x31, 132          # destino solapado (desplazado 1 palabra)
    li   t0, 1
    sw   t0, 0(a1)
2:  lw   t0, 0(a1)
    addi t0, t0, 3
    sw   t0, 0(a2)
    addi a1, a1, 4
    addi a2, a2, 4
    addi t3, t3, -1
    bnez t3, 2b
    lw   t1, -4(a2)
    add  s0, s0, t1

    # Resultado a memoria y fin (TOHOST)
    sw   s0, 0(x31)
    li   t6, 0x80000000
    li   t5, 1
    sw   t5, 0(t6)
3:  j    3b
