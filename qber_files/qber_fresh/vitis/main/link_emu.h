#ifndef LINK_EMU_H
#define LINK_EMU_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint64_t r[4];
    uint16_t p_noise;
    uint16_t f_eve;
} link_emu_t;

extern const uint64_t LINK_ZERO_SUB[5];

void     link_emu_init4(link_emu_t *e, uint16_t p_noise, uint16_t f_eve, const uint64_t seeds[4]);

void     link_emu_init(link_emu_t *e, uint16_t p_noise, uint16_t f_eve, uint64_t seed);

uint32_t link_emu_photon(link_emu_t *e);
uint32_t link_emu_word(link_emu_t *e);
void     link_emu_fill(link_emu_t *e, uint32_t *buf, size_t n);

double   link_emu_qber(double p, double f);

#endif
