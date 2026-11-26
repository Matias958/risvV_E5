/* ============================================================================
 * INVASORES DEL ESPACIO - juego estilo arcade para el ERV26 (RISC-V RV32I)
 *
 *   Pantalla 320x240 RGB332 con doble buffer; botones en GPIO_0[3:0]:
 *   izquierda, derecha, disparo, start. Los LEDs muestran las vidas.
 *
 *   Graficos, fuente y codigo propios (gfx_gen.py). Se compila para el
 *   ERV26 con sw/build.py y, con -DHOST, para la PC (host_main.c), que
 *   juega una partida guionada y guarda imagenes.
 * ========================================================================== */
#include <stdint.h>
#include "plat.h"
#include "gfx.h"

#ifdef HOST
#define main main_game          /* host_main.c tiene su propio main */
#endif

/* ---------------- Colores (RGB332: RRRGGGBB) ---------------- */
#define C_BLACK   0x00
#define C_WHITE   0xFF
#define C_GREEN   0x1C
#define C_CYAN    0x1F
#define C_MAGENTA 0xE3
#define C_RED     0xE0
#define C_YELLOW  0xFC
#define C_ORANGE  0xF0
#define C_GRAY    0x92
#define C_BLUE    0x0B

/* ---------------- Geometria ---------------- */
#define ROWS        5
#define COLS        11
#define CELL_W      20
#define CELL_H      16
#define INV_W       12
#define INV_H       8
#define PLAYER_Y    208
#define PLAYER_W    13
#define GROUND_Y    226
#define SHIELD_Y    180
#define SHIELD_W    24
#define SHIELD_H    16
#define NSHIELDS    4
#define UFO_Y       20
#define TOP_LIMIT   16
#define MAX_BOMBS   3

/* ---------------- Estado del juego ---------------- */
enum { ST_TITLE, ST_PLAY, ST_DYING, ST_OVER };

static uint8_t  alive[ROWS][COLS];   /* 0 muerto, 1 vivo, >1 explotando (cuadros) */
static int      n_alive;
static int      fx, fy, fdir;        /* posicion de la formacion y direccion */
static int      step_timer, anim;
static int      px;                  /* x del jugador */
static int      shot_x, shot_y, shot_on;
static int      bomb_x[MAX_BOMBS], bomb_y[MAX_BOMBS], bomb_on[MAX_BOMBS];
static int      bomb_timer;
static int      ufo_x, ufo_dir, ufo_on, ufo_timer, ufo_pts, ufo_msg_timer, ufo_msg_x;
static uint32_t shield[NSHIELDS][SHIELD_H];   /* un bit por pixel */
static uint32_t score, hiscore;
static int      lives, wave, state, state_timer;
static uint32_t frame;
static uint32_t rng = 0x12345678u;
static uint32_t prev_btn;

static const int shield_x[NSHIELDS] = {36, 112, 188, 264};
static const int row_pts[ROWS] = {30, 20, 20, 10, 10};
static const uint8_t row_col[ROWS] = {C_MAGENTA, C_CYAN, C_CYAN, C_GREEN, C_GREEN};

static uint32_t rnd(void)
{
    rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5;
    return rng;
}

/* ---------------- Dibujo en el framebuffer ---------------- */
static uint8_t *fb;

static void clear_screen(void)
{
    uint32_t *p = (uint32_t *)fb;
    for (int i = 0; i < SCR_W * SCR_H / 4; i += 8) {
        p[i] = 0; p[i + 1] = 0; p[i + 2] = 0; p[i + 3] = 0;
        p[i + 4] = 0; p[i + 5] = 0; p[i + 6] = 0; p[i + 7] = 0;
    }
}

static inline void pset(int x, int y, uint8_t c)
{
    if ((unsigned)x < SCR_W && (unsigned)y < SCR_H) fb[y * SCR_W + x] = c;
}

static void fill_rect(int x, int y, int w, int h, uint8_t c)
{
    for (int j = 0; j < h; j++)
        for (int i = 0; i < w; i++) pset(x + i, y + j, c);
}

static void draw_sprite(const sprite_t *s, int x, int y, uint8_t c)
{
    for (int j = 0; j < s->h; j++) {
        uint16_t r = s->rows[j];
        for (int i = 0; i < s->w; i++)
            if (r & (1u << (s->w - 1 - i))) pset(x + i, y + j, c);
    }
}

static void draw_char(char ch, int x, int y, uint8_t c)
{
    if (ch >= 'a' && ch <= 'z') ch -= 32;
    if (ch < ' ' || ch > 'Z') ch = '?';
    const uint8_t *g = font5x7[ch - ' '];
    for (int j = 0; j < 7; j++)
        for (int i = 0; i < 5; i++)
            if (g[j] & (0x10 >> i)) pset(x + i, y + j, c);
}

static void draw_text(const char *s, int x, int y, uint8_t c)
{
    for (; *s; s++, x += 6) draw_char(*s, x, y, c);
}

static int text_w(const char *s) { int n = 0; while (s[n]) n++; return n * 6 - 1; }

static void draw_text_c(const char *s, int y, uint8_t c) { draw_text(s, (SCR_W - text_w(s)) / 2, y, c); }

static void draw_num(uint32_t v, int digits, int x, int y, uint8_t c)
{
    char buf[11];
    buf[digits] = 0;
    for (int i = digits - 1; i >= 0; i--) {
        uint32_t q = 0, r = v;           /* division por 10 sin hardware: restas */
        while (r >= 10) { r -= 10; q++; }
        buf[i] = (char)('0' + r);
        v = q;
    }
    draw_text(buf, x, y, c);
}

/* ---------------- Escudos ---------------- */
static void shields_reset(void)
{
    for (int s = 0; s < NSHIELDS; s++)
        for (int j = 0; j < SHIELD_H; j++) shield[s][j] = shield_rows[j];
}

/* Devuelve 1 si el pixel (x, y) de pantalla esta ocupado por un escudo */
static int shield_hit(int x, int y, int *si, int *sx, int *sy)
{
    if (y < SHIELD_Y || y >= SHIELD_Y + SHIELD_H) return 0;
    for (int s = 0; s < NSHIELDS; s++) {
        int lx = x - shield_x[s];
        if (lx >= 0 && lx < SHIELD_W && (shield[s][y - SHIELD_Y] & (1u << (SHIELD_W - 1 - lx)))) {
            *si = s; *sx = lx; *sy = y - SHIELD_Y;
            return 1;
        }
    }
    return 0;
}

/* Rompe un pedazo irregular del escudo alrededor del impacto */
static void shield_damage(int s, int lx, int ly)
{
    static const int8_t dx[] = {0, -1, 1, 0, 0, -2, 2, -1, 1, -1, 1};
    static const int8_t dy[] = {0, 0, 0, -1, 1, 0, 0, -1, 1, 1, -1};
    for (unsigned k = 0; k < sizeof dx; k++) {
        if (k >= 5 && (rnd() & 1)) continue;
        int x = lx + dx[k], y = ly + dy[k];
        if (x >= 0 && x < SHIELD_W && y >= 0 && y < SHIELD_H)
            shield[s][y] &= ~(1u << (SHIELD_W - 1 - x));
    }
}

static void draw_shields(void)
{
    for (int s = 0; s < NSHIELDS; s++)
        for (int j = 0; j < SHIELD_H; j++) {
            uint32_t r = shield[s][j];
            if (!r) continue;
            for (int i = 0; i < SHIELD_W; i++)
                if (r & (1u << (SHIELD_W - 1 - i))) pset(shield_x[s] + i, SHIELD_Y + j, C_GREEN);
        }
}

/* ---------------- Oleadas ---------------- */
static void wave_start(void)
{
    for (int r = 0; r < ROWS; r++)
        for (int c = 0; c < COLS; c++) alive[r][c] = 1;
    n_alive = ROWS * COLS;
    fx = 50; fdir = 1; anim = 0; step_timer = 0;
    fy = 36 + 8 * (wave < 4 ? wave : 4);
    shot_on = 0;
    for (int b = 0; b < MAX_BOMBS; b++) bomb_on[b] = 0;
    bomb_timer = 60;
    shields_reset();
}

static void game_start(void)
{
    score = 0; lives = 3; wave = 0;
    px = (SCR_W - PLAYER_W) / 2;
    ufo_on = 0; ufo_timer = 600; ufo_msg_timer = 0;
    wave_start();
    state = ST_PLAY;
}

static inline int inv_x(int c) { return fx + c * CELL_W; }
static inline int inv_y(int r) { return fy + r * CELL_H; }

/* Columnas extremas con invasores vivos */
static void formation_span(int *cmin, int *cmax, int *rmax)
{
    *cmin = COLS; *cmax = -1; *rmax = -1;
    for (int r = 0; r < ROWS; r++)
        for (int c = 0; c < COLS; c++)
            if (alive[r][c] == 1) {
                if (c < *cmin) *cmin = c;
                if (c > *cmax) *cmax = c;
                if (r > *rmax) *rmax = r;
            }
}

/* ---------------- Logica de un cuadro ---------------- */
static void update_play(uint32_t btn, uint32_t pressed)
{
    /* Jugador */
    if ((btn & BTN_LEFT) && px > 4) px -= 2;
    if ((btn & BTN_RIGHT) && px < SCR_W - PLAYER_W - 4) px += 2;
    if ((btn & BTN_FIRE) && !shot_on) {
        shot_on = 1; shot_x = px + PLAYER_W / 2; shot_y = PLAYER_Y - 4;
    }
    (void)pressed;

    /* Explosiones de invasores: cuentan hacia atras hasta desaparecer */
    for (int r = 0; r < ROWS; r++)
        for (int c = 0; c < COLS; c++)
            if (alive[r][c] > 1 && --alive[r][c] == 1) alive[r][c] = 0;

    /* Formacion: un paso cada 'periodo' cuadros; mas rapido con menos invasores */
    int period = 1 + n_alive / 3;
    if (++step_timer >= period && n_alive > 0) {
        step_timer = 0;
        anim ^= 1;
        int cmin, cmax, rmax;
        formation_span(&cmin, &cmax, &rmax);
        int nx = fx + 2 * fdir;
        if (nx + cmin * CELL_W < 4 || nx + cmax * CELL_W + INV_W > SCR_W - 4) {
            fy += 8; fdir = -fdir;
        } else
            fx = nx;
        /* los invasores que bajan sobre los escudos los borran */
        int bottom = inv_y(rmax) + INV_H;
        for (int r = 0; r < ROWS; r++)
            for (int c = 0; c < COLS; c++) {
                if (alive[r][c] != 1) continue;
                int x0 = inv_x(c), y0 = inv_y(r);
                for (int s = 0; s < NSHIELDS; s++)
                    for (int j = 0; j < SHIELD_H; j++) {
                        int y = SHIELD_Y + j;
                        if (y < y0 || y >= y0 + INV_H) continue;
                        for (int i = 0; i < SHIELD_W; i++) {
                            int x = shield_x[s] + i;
                            if (x >= x0 && x < x0 + INV_W) shield[s][j] &= ~(1u << (SHIELD_W - 1 - i));
                        }
                    }
            }
        if (bottom >= PLAYER_Y) {            /* invasion: fin del juego */
            lives = 0; state = ST_DYING; state_timer = 90;
            return;
        }
    }

    /* Disparo del jugador */
    if (shot_on) {
        for (int k = 0; k < 4 && shot_on; k++) {          /* 4 px por cuadro, de a 1 */
            shot_y--;
            if (shot_y < TOP_LIMIT) { shot_on = 0; break; }
            int si, sx, sy;
            if (shield_hit(shot_x, shot_y, &si, &sx, &sy)) {
                shield_damage(si, sx, sy); shot_on = 0; break;
            }
            /* contra invasores */
            for (int r = 0; r < ROWS && shot_on; r++) {
                int y0 = inv_y(r);
                if (shot_y < y0 || shot_y >= y0 + INV_H) continue;
                for (int c = 0; c < COLS; c++) {
                    int x0 = inv_x(c);
                    if (alive[r][c] == 1 && shot_x >= x0 && shot_x < x0 + INV_W) {
                        alive[r][c] = 14;               /* explota durante 12 cuadros */
                        n_alive--; score += row_pts[r]; shot_on = 0;
                        break;
                    }
                }
            }
            /* contra el platillo */
            if (shot_on && ufo_on && shot_y >= UFO_Y && shot_y < UFO_Y + 7 &&
                shot_x >= ufo_x && shot_x < ufo_x + 16) {
                static const int pts[4] = {50, 100, 150, 300};
                ufo_pts = pts[rnd() & 3];
                score += ufo_pts; ufo_on = 0; shot_on = 0;
                ufo_msg_timer = 60; ufo_msg_x = ufo_x;
            }
            /* contra las bombas */
            for (int b = 0; b < MAX_BOMBS && shot_on; b++)
                if (bomb_on[b] && shot_x >= bomb_x[b] && shot_x < bomb_x[b] + 3 &&
                    shot_y >= bomb_y[b] && shot_y < bomb_y[b] + 6) {
                    bomb_on[b] = 0; shot_on = 0;
                }
        }
    }

    /* Bombas: cae una desde el invasor mas bajo de una columna al azar */
    if (--bomb_timer <= 0 && n_alive > 0) {
        bomb_timer = 25 + (int)(rnd() % 40) - 3 * (wave < 5 ? wave : 5);
        for (int b = 0; b < MAX_BOMBS; b++) {
            if (bomb_on[b]) continue;
            int c = (int)(rnd() % COLS);
            for (int t = 0; t < COLS; t++, c = (c + 1) % COLS) {
                int r;
                for (r = ROWS - 1; r >= 0 && alive[r][c] != 1; r--) ;
                if (r >= 0) {
                    bomb_on[b] = 1;
                    bomb_x[b] = inv_x(c) + INV_W / 2 - 1;
                    bomb_y[b] = inv_y(r) + INV_H;
                    break;
                }
            }
            break;
        }
    }
    int bspeed = 2 + (wave >= 3);
    for (int b = 0; b < MAX_BOMBS; b++) {
        if (!bomb_on[b]) continue;
        for (int k = 0; k < bspeed && bomb_on[b]; k++) {
            bomb_y[b]++;
            int tipx = bomb_x[b] + 1, tipy = bomb_y[b] + 5;
            int si, sx, sy;
            if (tipy >= GROUND_Y) { bomb_on[b] = 0; break; }
            if (shield_hit(tipx, tipy, &si, &sx, &sy)) { shield_damage(si, sx, sy); bomb_on[b] = 0; break; }
            if (tipy >= PLAYER_Y + 2 && tipy < PLAYER_Y + 8 && tipx >= px && tipx < px + PLAYER_W) {
                bomb_on[b] = 0;
                state = ST_DYING; state_timer = 90;
                return;
            }
        }
    }

    /* Platillo misterioso */
    if (ufo_on) {
        if ((frame & 1) == 0) ufo_x += ufo_dir;
        if (ufo_x < -16 || ufo_x > SCR_W) { ufo_on = 0; ufo_timer = 900 + (int)(rnd() % 600); }
    } else if (--ufo_timer <= 0 && n_alive > 8) {
        ufo_on = 1;
        ufo_dir = (rnd() & 1) ? 1 : -1;
        ufo_x = ufo_dir > 0 ? -16 : SCR_W;
    }
    if (ufo_msg_timer > 0) ufo_msg_timer--;

    /* Oleada completa */
    if (n_alive == 0) {
        int exploding = 0;
        for (int r = 0; r < ROWS; r++)
            for (int c = 0; c < COLS; c++) exploding |= alive[r][c];
        if (!exploding) { wave++; wave_start(); }
    }
}

/* ---------------- Dibujo de un cuadro ---------------- */
static void draw_hud(void)
{
    draw_text("PUNTOS", 6, 4, C_WHITE);
    draw_num(score, 5, 46, 4, C_YELLOW);
    draw_text("RECORD", 124, 4, C_WHITE);
    draw_num(hiscore, 5, 164, 4, C_YELLOW);
    draw_text("OLEADA", 236, 4, C_WHITE);
    draw_num((uint32_t)wave + 1, 2, 278, 4, C_YELLOW);
    fill_rect(0, GROUND_Y, SCR_W, 1, C_GREEN);
    draw_num((uint32_t)lives, 1, 6, GROUND_Y + 4, C_WHITE);
    for (int i = 0; i < lives - 1 && i < 6; i++) draw_sprite(&player, 18 + i * 17, GROUND_Y + 3, C_GREEN);
}

static void draw_play(int show_player, int player_boom)
{
    draw_hud();
    draw_shields();
    for (int r = 0; r < ROWS; r++)
        for (int c = 0; c < COLS; c++) {
            if (!alive[r][c]) continue;
            const sprite_t *s;
            if (alive[r][c] > 1) s = &boom;
            else if (r == 0) s = anim ? &inv_a1 : &inv_a0;
            else if (r < 3)  s = anim ? &inv_b1 : &inv_b0;
            else             s = anim ? &inv_c1 : &inv_c0;
            draw_sprite(s, inv_x(c), inv_y(r), alive[r][c] > 1 ? C_WHITE : row_col[r]);
        }
    if (ufo_on) draw_sprite(&ufo, ufo_x, UFO_Y, C_RED);
    if (ufo_msg_timer) draw_num((uint32_t)ufo_pts, 3, ufo_msg_x, UFO_Y, C_RED);
    if (show_player) {
        if (player_boom) draw_sprite((frame & 8) ? &player_boom0 : &player_boom1, px, PLAYER_Y, C_ORANGE);
        else draw_sprite(&player, px, PLAYER_Y, C_GREEN);
    }
    if (shot_on) fill_rect(shot_x, shot_y, 1, 4, C_WHITE);
    for (int b = 0; b < MAX_BOMBS; b++)
        if (bomb_on[b]) draw_sprite((frame & 4) ? &bomb1 : &bomb0, bomb_x[b], bomb_y[b], C_YELLOW);
}

static void draw_title(void)
{
    draw_hud();
    draw_text_c("INVASORES DEL ESPACIO", 48, C_GREEN);
    draw_text_c("ERV26 - RISC-V EN FPGA", 62, C_GRAY);
    draw_sprite(&ufo, 108, 92, C_RED);       draw_text("= ? MISTERIO", 132, 92, C_WHITE);
    draw_sprite(&inv_a0, 110, 110, C_MAGENTA); draw_text("= 30 PUNTOS", 132, 110, C_WHITE);
    draw_sprite(&inv_b0, 110, 126, C_CYAN);    draw_text("= 20 PUNTOS", 132, 126, C_WHITE);
    draw_sprite(&inv_c0, 110, 142, C_GREEN);   draw_text("= 10 PUNTOS", 132, 142, C_WHITE);
    if ((frame >> 5) & 1) draw_text_c("APRETA START", 176, C_YELLOW);
    draw_text_c("< >  MOVER       FUEGO  DISPARAR", 200, C_GRAY);
}

/* ---------------- Bucle principal ---------------- */
int main(void)
{
    int back = 1;
    state = ST_TITLE; lives = 3; wave = 0;
    shields_reset();
    plat_show(0);
    for (;;) {
        uint32_t btn = plat_buttons();
        uint32_t pressed = btn & ~prev_btn;
        prev_btn = btn;
        frame++;

        switch (state) {
        case ST_TITLE:
            if (pressed & BTN_START) { rng ^= plat_entropy() | 1u; game_start(); }
            break;
        case ST_PLAY:
            update_play(btn, pressed);
            break;
        case ST_DYING:                        /* animacion de la explosion */
            for (int b = 0; b < MAX_BOMBS; b++) bomb_on[b] = 0;
            shot_on = 0;
            if (--state_timer == 0) {
                if (--lives <= 0) { lives = 0; state = ST_OVER; state_timer = 120; }
                else { state = ST_PLAY; px = (SCR_W - PLAYER_W) / 2; }
            }
            break;
        case ST_OVER:
            if (state_timer > 0) state_timer--;
            else if (pressed & BTN_START) { rng ^= plat_entropy(); game_start(); }
            break;
        }
        if (score > hiscore) hiscore = score;

        fb = plat_page(back);
        clear_screen();
        if (state == ST_TITLE) draw_title();
        else {
            draw_play(state != ST_OVER, state == ST_DYING);
            if (state == ST_OVER) {
                fill_rect(0, 96, SCR_W, 40, C_BLACK);
                draw_text_c("FIN DEL JUEGO", 104, C_RED);
                if (state_timer == 0 && ((frame >> 5) & 1)) draw_text_c("APRETA START", 120, C_YELLOW);
            }
        }
        plat_leds((1u << lives) - 1u);
        plat_show(back);
        plat_wait_frame();
        back ^= 1;
    }
}
