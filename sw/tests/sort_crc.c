/* Ordenamiento (quicksort + insertion), CRC32 y busqueda binaria.
 * Mucho load/store, branches dependientes de datos y recursion. */
#include <stdint.h>
#include "erv26.h"

#define N 200

static uint32_t lfsr = 0xACE1u;
static uint32_t rnd(void) {
    lfsr ^= lfsr << 13; lfsr ^= lfsr >> 17; lfsr ^= lfsr << 5;
    return lfsr;
}

static int32_t v[N];

static void quicksort(int32_t *a, int lo, int hi) {
    while (hi - lo > 8) {
        int32_t p = a[(lo + hi) >> 1];
        int i = lo, j = hi;
        while (i <= j) {
            while (a[i] < p) i++;
            while (a[j] > p) j--;
            if (i <= j) { int32_t t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
        }
        if (j - lo < hi - i) { quicksort(a, lo, j); lo = i; }
        else                 { quicksort(a, i, hi); hi = j; }
    }
    for (int k = lo + 1; k <= hi; k++) {
        int32_t x = a[k]; int m = k - 1;
        while (m >= lo && a[m] > x) { a[m + 1] = a[m]; m--; }
        a[m + 1] = x;
    }
}

static uint32_t crc32(const uint8_t *p, int n) {
    uint32_t c = 0xFFFFFFFFu;
    for (int i = 0; i < n; i++) {
        c ^= p[i];
        for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320u & -(c & 1));
    }
    return ~c;
}

static int bsearch_i(const int32_t *a, int n, int32_t key) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = (lo + hi) >> 1;
        if (a[mid] == key) return mid;
        if (a[mid] < key) lo = mid + 1; else hi = mid - 1;
    }
    return -1;
}

int main(void) {
    for (int i = 0; i < N; i++) v[i] = (int32_t)rnd();
    int32_t probe = v[37];
    quicksort(v, 0, N - 1);
    for (int i = 1; i < N; i++) if (v[i - 1] > v[i]) return 1;
    if (bsearch_i(v, N, probe) < 0) return 2;
    if (crc32((const uint8_t *)"123456789", 9) != 0xCBF43926u) return 3;   /* vector estandar */
    erv26_puts("sort_crc ok\n");
    return 0;
}
