/* Multiplicacion/division por software (libgcc: __mulsi3, __divsi3, ...),
 * recursion profunda (JAL/JALR, pila), accesos de 8/16 bits y punteros a
 * funcion (JALR a direccion calculada). */
#include <stdint.h>
#include "erv26.h"

static int fib(int n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }

static uint32_t isqrt(uint32_t x) {
    uint32_t r = 0, b = 1u << 30;
    while (b > x) b >>= 2;
    while (b) {
        if (x >= r + b) { x -= r + b; r = (r >> 1) + b; } else r >>= 1;
        b >>= 2;
    }
    return r;
}

static uint32_t add(uint32_t a, uint32_t b) { return a + b; }
static uint32_t sub(uint32_t a, uint32_t b) { return a - b; }
static uint32_t mul(uint32_t a, uint32_t b) { return a * b; }
static uint32_t (*const ops[3])(uint32_t, uint32_t) = { add, sub, mul };

static volatile uint8_t  bytes[16];
static volatile int16_t  halves[8];

int main(void) {
    if (fib(15) != 610) return 1;

    int32_t a = -123456, b = 789;
    if (a * b != -97406784) return 2;
    if (a / b != -156 || a % b != -372) return 3;
    if ((uint32_t)0xFFFFFFF0u / 7u != 613566754u) return 4;
    if (isqrt(1000000) != 1000 || isqrt(99) != 9) return 5;

    uint32_t acc = 0;
    for (int i = 0; i < 30; i++) acc = ops[i % 3](acc, (uint32_t)i + 1);
    if (acc != 1600051480u) return 6;

    for (int i = 0; i < 16; i++) bytes[i] = (uint8_t)(0xF0 + i);
    for (int i = 0; i < 8; i++)  halves[i] = (int16_t)(-1000 * i);
    int32_t s = 0;
    for (int i = 0; i < 16; i++) s += (int8_t)bytes[i];
    for (int i = 0; i < 8; i++)  s += halves[i];
    if (s != -28136) return 7;

    uint64_t big = 0x123456789ull;
    big *= 1000003u;
    if ((uint32_t)(big >> 32) != 0x115c75u || (uint32_t)big != 0x30e26adbu) return 8;

    erv26_puts("arith ok\n");
    return 0;
}
