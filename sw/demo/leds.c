/* Demo en placa del ERV26 con pipeline.
 *   SW[1:0] : patron   (0 contador, 1 "auto fantastico", 2 llenado, 3 Fibonacci mod 256)
 *   SW[2]   : velocidad (0 lenta, 1 rapida)
 *   SW[3]   : pausa (lo lee el programa, el procesador sigue corriendo)
 * Los switches se leen en cada paso, asi que la demo se "parametriza en vivo".
 */
#include <stdint.h>
#include "erv26.h"

#define CYCLES  (*(volatile uint32_t *)(ERV26_IO_BASE + 0x8))   /* contador de ciclos a 50 MHz */

static void wait_cycles(uint32_t n) {
    uint32_t t0 = CYCLES;
    while ((uint32_t)(CYCLES - t0) < n) ;
}

int main(void) {
    uint32_t step = 0, a = 0, b = 1;
    for (;;) {
        uint32_t sw = SWITCHES;
        if (sw & 8) continue;                          /* pausa */

        uint32_t out;
        switch (sw & 3) {
        case 0:  out = step; break;
        case 1: {                                      /* rebote 0..7..0 */
            uint32_t p = step % 14;
            out = 1u << (p < 8 ? p : 14 - p);
            break;
        }
        case 2:  out = (1u << (step % 9)) - 1; break;
        default: { uint32_t t = a + b; a = b; b = t; out = a; break; }
        }
        LEDS = out & 0xFF;
        step++;
#ifdef SIM
        wait_cycles((sw & 4) ? 50u : 250u);            /* simulacion */
#else
        wait_cycles((sw & 4) ? 2500000u : 12500000u);  /* 50 ms / 250 ms */
#endif
    }
}
