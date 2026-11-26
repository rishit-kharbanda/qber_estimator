/* xs64.h - xorshift64 (shifts 13, 7, 17), as in INTERFACES.md section 0.
 * The state must be non-zero. */
#ifndef XS64_H
#define XS64_H

#include <stdint.h>

static inline uint64_t xs64_next(uint64_t *s)
{
    uint64_t x = *s;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *s = x;
    return x;
}

#endif /* XS64_H */
