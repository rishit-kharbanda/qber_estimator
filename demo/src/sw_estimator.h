/* sw_estimator.h - the parameter-estimation stage in C, for the FPGA vs ARM
 * comparison (Part 4). It consumes the packed photon words of INTERFACES.md
 * section 2 (8 photons per word, nibble {b_basis, b_bit, a_basis, a_bit},
 * oldest in nibble 0) and does the same work as the PL:
 *
 *   sift (a_basis == b_basis) -> block of the next BLOCK_SIZE sifted bits
 *   -> sampler: D = max(NMAX, FIX_N) positions without repeats (RNG5)
 *   -> compare -> SPRT and fixed test on the same disclosed bits
 *   -> counters with the same meaning as the PL counters (section 5).
 *
 * BIT-EXACT with Part 1's pe_top and Part 2's dec_top (model/qkd_model.py v2,
 * model/dec_model.py): for the same seeds, settings and photon stream every
 * block gives the same n_sprt, n_fix, decisions and counters. The sampler is
 * Part 1's rule (part1/INTERFACES_change_proposal.md section 7):
 *   start : P[p] = p, p = 0 .. BLOCK_SIZE-1 (kept from block to block)
 *   block : for i = 0 .. D-1: r = RNG5 step; j = i + (((r>>40)*(BS-i))>>24);
 *           swap P[i], P[j]; disclose P[i]
 *   test_all: positions 0 .. D-1, RNG5 unused.
 * Stop-and-wait disclosure: max(n_sprt, n_fix) bits are disclosed per block.
 *
 * Two entry points do identical work:
 *   swe_process()        word-parallel sifting (the fast, fair ARM baseline)
 *   swe_process_simple() one photon at a time (mirrors the RTL structure)
 */
#ifndef SW_ESTIMATOR_H
#define SW_ESTIMATOR_H

#include <stddef.h>
#include <stdint.h>
#include "params.h"

#define SWE_MAX_BLOCK 4096u
#define SWE_MAX_D     1024u

/* Result of one block, as dec_top reports it at blk_done. */
typedef struct {
    uint64_t index;             /* block number from 0 */
    uint16_t n_sprt, n_fix;
    uint8_t  sprt_abort, fix_abort, trunc;
    uint16_t blk_sifted;        /* always BLOCK_SIZE */
    uint16_t blk_true_err;      /* errors in the whole block */
    uint16_t n_disclosed;       /* max(n_sprt, n_fix) */
} swe_block_t;

typedef void (*swe_block_cb)(void *ctx, const swe_block_t *b);

typedef struct {
    uint32_t     block_size;    /* BLOCK_SIZE; must pass params_check_block() */
    est_consts_t k;             /* SPRT and fixed-test constants */
    int          curtail;       /* CTRL.curtail_en */
    int          test_all;      /* CTRL.test_all: sequential disclosure order */
    uint64_t     sampler_seed;  /* SEED4 (RNG5); 0 is replaced as in rng64.v */
    uint64_t     num_blocks;    /* NUM_BLOCKS: stop testing after this many; 0 = no limit */
    swe_block_cb on_block;      /* optional, called after every block */
    void        *ctx;
} swe_cfg_t;

/* Same meaning as the PL counters of the same name. */
typedef struct {
    uint64_t photons;           /* photons received (PHOTONS_PROC on the PL) */
    uint64_t sifted;            /* SIFTED */
    uint64_t sifted_errs;       /* SIFTED_ERRS (true QBER numerator) */
    uint64_t blocks;            /* BLOCKS_DONE */
    uint64_t sum_n_sprt;        /* SUM_N_SPRT */
    uint64_t sum_n_fix;         /* SUM_N_FIX */
    uint64_t abort_sprt;        /* ABORT_SPRT */
    uint64_t abort_fix;         /* ABORT_FIX */
    uint64_t trunc_sprt;        /* TRUNC_SPRT */
    uint64_t key_sprt;          /* KEY_SPRT: BLOCK_SIZE - n_sprt per SPRT accept */
    uint64_t key_fix;           /* KEY_FIX:  BLOCK_SIZE - n_fix per fixed accept */
    uint64_t disclosed;         /* DISCLOSED (proposed 0x190): sum of max(n_sprt, n_fix) */
    uint64_t key_out;           /* KEY_OUT (proposed 0x198): BLOCK_SIZE - max(n) per SPRT accept */
    uint64_t test_errs;         /* errors among the disclosed bits */
    uint8_t  last_sprt_abort, last_fix_abort, last_trunc;
} swe_counts_t;

typedef struct {
    swe_cfg_t    cfg;
    swe_counts_t c;
    uint32_t     d;                       /* max(NMAX, FIX_N) */
    uint64_t     samp;                    /* RNG5 state */
    uint32_t     fill;                    /* sifted bits in the current block */
    uint32_t     blk_errs;                /* errors in the current block */
    int          full;                    /* NUM_BLOCKS reached */
    uint8_t      e[SWE_MAX_BLOCK];        /* a_bit ^ b_bit of each sifted bit */
    uint16_t     perm[SWE_MAX_BLOCK];     /* sampler permutation P */
} swe_t;

/* Defaults: BLOCK_SIZE 4096, constants k, no curtailment, sampler order,
 * SEED4 default, no block limit, no callback. */
void swe_cfg_default(swe_cfg_t *cfg, const est_consts_t *k);

/* Returns 0, or -1 if the configuration breaks params_check_block().
 * Clears all counters and resets the sampler, like CTRL.start. */
int  swe_init(swe_t *s, const swe_cfg_t *cfg);

void swe_process(swe_t *s, const uint32_t *words, size_t n);
void swe_process_simple(swe_t *s, const uint32_t *words, size_t n);

#endif /* SW_ESTIMATOR_H */
