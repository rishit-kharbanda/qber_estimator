/* link_emu.c - see link_emu.h. Part 4. */
#include "link_emu.h"
#include "xs64.h"

const uint64_t LINK_ZERO_SUB[5] = {
    0x9E3779B97F4A7C15ull,   /* RNG1 Alice   */
    0xBF58476D1CE4E5B9ull,   /* RNG2 Eve     */
    0x94D049BB133111EBull,   /* RNG3 noise   */
    0xD6E8FEB86659FD93ull,   /* RNG4 Bob     */
    0xA0761D6478BD642Full }; /* RNG5 sampler */

void link_emu_init4(link_emu_t *e, uint16_t p_noise, uint16_t f_eve, const uint64_t seeds[4])
{
    for (int i = 0; i < 4; i++)
        e->r[i] = seeds[i] ? seeds[i] : LINK_ZERO_SUB[i];
    e->p_noise = p_noise;
    e->f_eve   = f_eve;
}

void link_emu_init(link_emu_t *e, uint16_t p_noise, uint16_t f_eve, uint64_t seed)
{
    uint64_t s[4];
    for (int i = 0; i < 4; i++)
        s[i] = (seed + (uint64_t)i + 1u) * LINK_ZERO_SUB[i];
    link_emu_init4(e, p_noise, f_eve, s);
}

uint32_t link_emu_photon(link_emu_t *e)
{
    uint64_t r1 = xs64_next(&e->r[0]);
    uint64_t r2 = xs64_next(&e->r[1]);
    uint64_t r3 = xs64_next(&e->r[2]);
    uint64_t r4 = xs64_next(&e->r[3]);

    /* alice_src */
    uint32_t a_bit = (uint32_t)(r1 & 1u), a_basis = (uint32_t)((r1 >> 1) & 1u);
    /* quantum_channel: Eve measures in her basis and resends in it, then noise */
    uint32_t bit = a_bit, basis = a_basis;
    if ((uint32_t)(r2 >> 48) < e->f_eve) {
        uint32_t e_basis = (uint32_t)(r2 & 1u), e_rand = (uint32_t)((r2 >> 1) & 1u);
        bit   = (e_basis == a_basis) ? a_bit : e_rand;
        basis = e_basis;
    }
    if ((uint32_t)(r3 >> 48) < e->p_noise)
        bit ^= 1u;
    /* bob_det */
    uint32_t b_basis = (uint32_t)(r4 & 1u), b_rand = (uint32_t)((r4 >> 1) & 1u);
    uint32_t b_bit   = (b_basis == basis) ? bit : b_rand;

    return (b_basis << 3) | (b_bit << 2) | (a_basis << 1) | a_bit;
}

uint32_t link_emu_word(link_emu_t *e)
{
    uint32_t w = 0;
    for (int i = 0; i < 8; i++)
        w |= link_emu_photon(e) << (4 * i);
    return w;
}

void link_emu_fill(link_emu_t *e, uint32_t *buf, size_t n)
{
    for (size_t i = 0; i < n; i++)
        buf[i] = link_emu_word(e);
}

double link_emu_qber(double p, double f)
{
    return p + f / 4.0 - p * f / 2.0;
}
