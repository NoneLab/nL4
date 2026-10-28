/* SPDX-License-Identifier: BSD-2-Clause */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "../kernel/src/runtime/udivdi3.c"

int main(void)
{
    static const uint64_t values[] = {
        0, 1, 2, 3, 7, 0xffffffffULL, 0x100000000ULL,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xffffffffffffffffULL, 0xfedcba9876543210ULL
    };
    size_t i, j;
    uint64_t a = 0x12345678abcdef01ULL;
    uint64_t b = 0xa75ef910c6543210ULL;

    for (i = 0; i < sizeof values / sizeof values[0]; ++i) {
        for (j = 1; j < sizeof values / sizeof values[0]; ++j) {
            volatile uint64_t n = values[i];
            volatile uint64_t d = values[j];
            if (__udivdi3(n, d) != n / d) {
                fprintf(stderr, "division mismatch at %zu, %zu\n", i, j);
                return EXIT_FAILURE;
            }
        }
    }
    for (i = 0; i < 10000; ++i) {
        volatile uint64_t n;
        volatile uint64_t d;
        a ^= a << 13; a ^= a >> 7; a ^= a << 17;
        b ^= b << 13; b ^= b >> 7; b ^= b << 17;
        n = a;
        d = b | 1ULL;
        if (__udivdi3(n, d) != n / d) {
            fprintf(stderr, "random division mismatch at %zu\n", i);
            return EXIT_FAILURE;
        }
    }
    puts("udivdi3: 10,100+ host-side test cases passed");
    return EXIT_SUCCESS;
}
