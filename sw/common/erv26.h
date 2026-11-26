/* ERV26 - mapa de E/S mapeada en memoria */
#ifndef ERV26_H
#define ERV26_H
#include <stdint.h>

#define ERV26_IO_BASE   0x80000000u
#define TOHOST          (*(volatile uint32_t *)(ERV26_IO_BASE + 0x0))  /* sim: fin  / placa: LEDs */
#define PUTCHAR         (*(volatile uint32_t *)(ERV26_IO_BASE + 0x4))  /* sim: consola */
#define LEDS            (*(volatile uint32_t *)(ERV26_IO_BASE + 0x0))
#define SWITCHES        (*(volatile uint32_t *)(ERV26_IO_BASE + 0x4))
#define CYCLES          (*(volatile uint32_t *)(ERV26_IO_BASE + 0x8))   /* contador de ciclos */
#define BUTTONS         (*(volatile uint32_t *)(ERV26_IO_BASE + 0xC))   /* GPIO_0[3:0], 1 = apretado */
#define FRAMES          (*(volatile uint32_t *)(ERV26_IO_BASE + 0x10))  /* cuadros de video (60 Hz) */
#define VIDEO_CTRL      (*(volatile uint32_t *)(ERV26_IO_BASE + 0x14))  /* bit0: pagina mostrada */

/* Framebuffer: 2 paginas de 320x240, 1 byte por pixel RGB332 (RRRGGGBB).
 * Solo escritura. La pagina elegida en VIDEO_CTRL se muestra a partir del
 * proximo blanking vertical (cuando FRAMES se incrementa). */
#define VRAM_BASE       0x40000000u
#define FB_W            320
#define FB_H            240
#define FB_PAGE(p)      ((volatile uint8_t *)(VRAM_BASE + (p) * (FB_W * FB_H)))
#define RGB332(r, g, b) ((uint8_t)(((r) & 0xE0) | (((g) >> 3) & 0x1C) | ((b) >> 6)))

static inline void erv26_puts(const char *s) { while (*s) PUTCHAR = (uint8_t)*s++; }

#endif
