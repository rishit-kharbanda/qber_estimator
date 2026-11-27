#ifndef SW_ESTIMATOR_H
#define SW_ESTIMATOR_H

#include <stddef.h>
#include <stdint.h>
#include "params.h"

#define SWE_MAX_BLOCK 4096u
#define SWE_MAX_D     1024u

typedef struct {
    uint64_t index;
    uint16_t n_sprt, n_fix;
    uint8_t  sprt_abort, fix_abort, trunc;
    uint16_t blk_sifted;
    uint16_t blk_true_err;
    uint16_t n_disclosed;
} swe_block_t;

typedef void (*swe_block_cb)(void *ctx, const swe_block_t *b);

typedef struct {
    uint32_t     block_size;
    est_consts_t k;
    int          curtail;
    int          test_all;
    uint64_t     sampler_seed;
    uint64_t     num_blocks;
    swe_block_cb on_block;
    void        *ctx;
} swe_cfg_t;

typedef struct {
    uint64_t photons;
    uint64_t sifted;
    uint64_t sifted_errs;
    uint64_t blocks;
    uint64_t sum_n_sprt;
    uint64_t sum_n_fix;
    uint64_t abort_sprt;
    uint64_t abort_fix;
    uint64_t trunc_sprt;
    uint64_t key_sprt;
    uint64_t key_fix;
    uint64_t disclosed;
    uint64_t key_out;
    uint64_t test_errs;
    uint8_t  last_sprt_abort, last_fix_abort, last_trunc;
} swe_counts_t;

typedef struct {
    swe_cfg_t    cfg;
    swe_counts_t c;
    uint32_t     d;
    uint64_t     samp;
    uint32_t     fill;
    uint32_t     blk_errs;
    int          full;
    uint8_t      e[SWE_MAX_BLOCK];
    uint16_t     perm[SWE_MAX_BLOCK];
} swe_t;

void swe_cfg_default(swe_cfg_t *cfg, const est_consts_t *k);

int  swe_init(swe_t *s, const swe_cfg_t *cfg);

void swe_process(swe_t *s, const uint32_t *words, size_t n);
void swe_process_simple(swe_t *s, const uint32_t *words, size_t n);

#endif
