/* Capa de plataforma del juego: en el ERV26 son registros de E/S; con
 * -DHOST se compila para la PC (host_main.c) y genera imagenes. */
#ifndef PLAT_H
#define PLAT_H
#include <stdint.h>

#define SCR_W 320
#define SCR_H 240

/* Botones (1 = apretado) */
#define BTN_LEFT  1u
#define BTN_RIGHT 2u
#define BTN_FIRE  4u
#define BTN_START 8u

#ifdef HOST
uint8_t  *plat_page(int page);        /* puntero a la pagina para dibujar */
void      plat_show(int page);        /* pedir que se muestre esa pagina   */
void      plat_wait_frame(void);      /* esperar el proximo blanking       */
uint32_t  plat_buttons(void);
uint32_t  plat_entropy(void);
void      plat_leds(uint32_t v);
#else
#include "erv26.h"
static inline uint8_t *plat_page(int page) { return (uint8_t *)FB_PAGE(page); }
static inline void     plat_show(int page) { VIDEO_CTRL = (uint32_t)page; }
static inline void     plat_wait_frame(void) { uint32_t f = FRAMES; while (FRAMES == f) ; }
static inline uint32_t plat_buttons(void)  { return BUTTONS; }
static inline uint32_t plat_entropy(void)  { return CYCLES; }
static inline void     plat_leds(uint32_t v) { LEDS = v; }
#endif

#endif
