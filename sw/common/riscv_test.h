/* ERV26 - entorno minimo para los riscv-tests oficiales (rv32ui)
 * Reemplaza al env/ original: sin CSRs ni traps. El resultado se escribe en
 * TOHOST (0x80000000): 1 = PASS, (TESTNUM << 1) | 1 = FAIL en ese test.
 */
#ifndef ERV26_RISCV_TEST_H
#define ERV26_RISCV_TEST_H

#define RVTEST_RV32U .macro init; .endm
#define RVTEST_RV64U RVTEST_RV32U
#define TESTNUM gp

#define RVTEST_CODE_BEGIN       \
        .section .text.init;    \
        .align  2;              \
        .globl _start;          \
_start:                         \
        li TESTNUM, 0;

#define RVTEST_CODE_END         \
1:      j 1b;

#define RVTEST_PASS             \
        li  t6, 0x80000000;     \
        li  t5, 1;              \
        sw  t5, 0(t6);          \
1:      j 1b;

#define RVTEST_FAIL             \
        li  t6, 0x80000000;     \
        slli t5, TESTNUM, 1;    \
        ori t5, t5, 1;          \
        sw  t5, 0(t6);          \
1:      j 1b;

#define EXTRA_DATA
#define RVTEST_DATA_BEGIN EXTRA_DATA .data; .align 4;
#define RVTEST_DATA_END

#endif
