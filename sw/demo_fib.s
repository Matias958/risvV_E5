# ============================================================================
# demo_fib.s - Demo del MVP-0 en placa
#   Fibonacci desenrollado en a0..a7 (x10..x17). Elegir el registro con
#   SW[2:0] y ver el byte bajo en los LEDs.
#   Esperado: a0=0 a1=1 a2=1 a3=2 a4=3 a5=5 a6=8 a7=13
#
#   Sin saltos el PC sigue avanzando por memoria vacia (0x00000000 se
#   decodifica como ilegal = NOP) y da la vuelta al llegar al final de la
#   memoria de programa, asi que el programa se re-ejecuta periodicamente.
# ============================================================================
        li   a0, 0
        li   a1, 1
        add  a2, a0, a1
        add  a3, a1, a2
        add  a4, a2, a3
        add  a5, a3, a4
        add  a6, a4, a5
        add  a7, a5, a6
