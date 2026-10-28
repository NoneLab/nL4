/* SPDX-License-Identifier: BSD-2-Clause
 * Freestanding 64-bit unsigned division for 32-bit x86 targets whose
 * compiler runtime is not installed (e.g. hosts without 32-bit libgcc).
 * No 64-bit divide or modulo operations are used in this implementation.
 * The calling convention is the target compiler's __udivdi3 ABI.
 */
#if defined(__i386__) || defined(PISTACHIO_TEST_UDIVDI3)
unsigned long long __udivdi3(unsigned long long dividend,
                            unsigned long long divisor)
{
    unsigned long long quotient = 0;
    unsigned long long remainder = 0;
    unsigned index;

    if (divisor == 0)
        __builtin_trap();

    for (index = 64; index != 0; --index) {
        unsigned overflow = (unsigned)(remainder >> 63);
        remainder = (remainder << 1) | ((dividend >> (index - 1)) & 1ULL);
        if (overflow || remainder >= divisor) {
            remainder -= divisor;
            quotient |= 1ULL << (index - 1);
        }
    }
    return quotient;
}
#endif
