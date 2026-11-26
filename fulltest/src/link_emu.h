/* link_emu.h - the emulated BB84 link in C (Alice, intercept-resend Eve,
 * noise, Bob), writing packed photon words (INTERFACES.md section 2).
 * Part 4, for the estimator benchmark and the laptop tests.
 *
 * Bit-exact with Part 1's link_top.v and model/qkd_model.py v2 (Link):
 *   RNG1..RNG4 = xorshift64 (13, 7, 17), a zero seed replaced by the same
 *   constant as rng64.v; each generator steps once per photon and the
 *   photon uses the new state:
 *     a_bit = r1[0], a_basis = r1[1]
 *     Eve   : r2[63:48] < F_EVE,  e_basis = r2[0], e_rand = r2[1]
 *     noise : r3[63:48] < P_NOISE
 *     Bob   : b_basis = r4[0], b_rand = r4[1]
 * So photon k here is photon k of the PL for the same seeds and settings.
 */
#ifndef LINK_EMU_H
#define LINK_EMU_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint64_t r[4];        /* RNG1 Alice, RNG2 Eve, RNG3 noise, RNG4 Bob */
    uint16_t p_noise;     /* P_NOISE register value (probability * 65536, max 0xFFFF) */
    uint16_t f_eve;       /* F_EVE register value */
} link_emu_t;

/* Zero-seed replacements of rng64.v (RNG1..RNG5). */
extern const uint64_t LINK_ZERO_SUB[5];

/* Exact PL seeds SEED0..SEED3. */
void     link_emu_init4(link_emu_t *e, uint16_t p_noise, uint16_t f_eve, const uint64_t seeds[4]);
/* Convenience: four seeds derived from one number (benchmark and tests). */
void     link_emu_init(link_emu_t *e, uint16_t p_noise, uint16_t f_eve, uint64_t seed);

uint32_t link_emu_photon(link_emu_t *e);               /* nibble {b_basis, b_bit, a_basis, a_bit} */
uint32_t link_emu_word(link_emu_t *e);                 /* 8 photons, oldest in nibble 0 */
void     link_emu_fill(link_emu_t *e, uint32_t *buf, size_t n);

/* Expected QBER for noise p and Eve fraction f: p + f/4 - p f / 2 */
double   link_emu_qber(double p, double f);

#endif /* LINK_EMU_H */
