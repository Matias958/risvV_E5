/* Version para PC del juego (gcc -DHOST): juega una partida con botones
 * guionados y guarda algunos cuadros como PPM, para revisar el juego sin la
 * placa ni el simulador.
 *
 *   gcc -O2 -DHOST -I. -o invaders_host invaders.c host_main.c
 *   ./invaders_host salida/        -> salida/frame_NNNNN.ppm
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "plat.h"

static uint8_t  pages[2][SCR_W * SCR_H];
static int      shown, nframe;
static const char *outdir = ".";

uint8_t *plat_page(int p) { return pages[p & 1]; }
void     plat_show(int p) { shown = p & 1; }
uint32_t plat_entropy(void) { return 0xC0FFEEu; }
void     plat_leds(uint32_t v) { (void)v; }

/* Guion de botones: (desde el cuadro, hasta el cuadro, botones) */
static const struct { int a, b; uint32_t btn; } script[] = {
    {  60,   62, BTN_START },
    { 100,  160, BTN_LEFT | BTN_FIRE },
    { 160,  260, BTN_RIGHT | BTN_FIRE },
    { 260,  400, BTN_FIRE },
    { 400,  520, BTN_LEFT | BTN_FIRE },
    { 520,  700, BTN_RIGHT | BTN_FIRE },
    { 700, 1400, BTN_FIRE },
    {1400, 1600, BTN_LEFT | BTN_FIRE },
    {1600, 2600, BTN_FIRE },
};

uint32_t plat_buttons(void)
{
    uint32_t b = 0;
    for (unsigned i = 0; i < sizeof script / sizeof script[0]; i++)
        if (nframe >= script[i].a && nframe < script[i].b) b |= script[i].btn;
    /* despues del cuadro 2600: moverse de lado a lado disparando */
    if (nframe >= 2600) b |= BTN_FIRE | (((nframe / 90) & 1) ? BTN_LEFT : BTN_RIGHT);
    return b;
}

static void save(const char *name)
{
    char path[512];
    snprintf(path, sizeof path, "%s/%s.ppm", outdir, name);
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); exit(1); }
    fprintf(f, "P6\n%d %d\n255\n", SCR_W, SCR_H);
    for (int i = 0; i < SCR_W * SCR_H; i++) {
        uint8_t v = pages[shown][i];
        uint8_t r = v >> 5, g = (v >> 2) & 7, bb = v & 3;
        uint8_t rgb[3] = {(uint8_t)((r << 5) | (r << 2) | (r >> 1)),
                          (uint8_t)((g << 5) | (g << 2) | (g >> 1)), (uint8_t)(bb * 0x55)};
        fwrite(rgb, 1, 3, f);
    }
    fclose(f);
}

static const int snaps[] = {30, 63, 150, 400, 900, 1500, 2200, 3000, 4000, 5500, 7000};
static int max_frames = 7200;

void plat_wait_frame(void)
{
    char name[64];
    for (unsigned i = 0; i < sizeof snaps / sizeof snaps[0]; i++)
        if (snaps[i] == nframe) { snprintf(name, sizeof name, "frame_%05d", nframe); save(name); }
    if (++nframe >= max_frames) exit(0);
}

int main_game(void);
int main(int argc, char **argv)
{
    if (argc > 1) outdir = argv[1];
    if (argc > 2) max_frames = atoi(argv[2]);
    return main_game();
}
