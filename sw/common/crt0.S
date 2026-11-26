# ERV26 - arranque para programas en C
#   Inicializa sp/gp, limpia .bss, llama a main() y escribe el resultado en
#   TOHOST: (ret << 1) | 1  -> 1 significa que main devolvio 0 (PASS).
    .section .text.init
    .globl _start
_start:
    .option push
    .option norelax
    la   gp, __global_pointer$
    .option pop
    la   sp, _stack_top

    la   t0, __bss_start
    la   t1, __bss_end
1:  bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:
    call main

    slli a0, a0, 1
    ori  a0, a0, 1
    li   t0, 0x80000000          # TOHOST
    sw   a0, 0(t0)
3:  j    3b
