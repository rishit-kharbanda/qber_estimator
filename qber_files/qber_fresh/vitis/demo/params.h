/* params.h - estimator constants from (p0, p1, alpha, beta). Part 4.
 * The ARM computes these and writes them to the SPRT/FIX registers, so a
 * different error target is a register write (the project uses BB84 only).
 */
#ifndef PARAMS_H
#define PARAMS_H

#include <stdint.h>

typedef struct {
    double p0;      /* safe error rate          (BB84: 0.03) */
    double p1;      /* unsafe error rate        (BB84: 0.11) */
    double alpha;   /* P(abort | p0)  target    (0.01) */
    double beta;    /* P(accept | p1) target    (0.01) */
} test_spec_t;

typedef struct {
    int16_t  inc_err;   /* SPRT_INC_ERR = round(S ln(p1/p0))               */
    int16_t  inc_ok;    /* SPRT_INC_OK  = round(S ln((1-p1)/(1-p0)))       */
    int16_t  thr_a;     /* SPRT_THR_A   = round(S ln((1-beta)/alpha))  ABORT */
    int16_t  thr_b;     /* SPRT_THR_B   = round(S ln(beta/(1-alpha)))  ACCEPT */
    uint16_t nmax;      /* SPRT_NMAX    = 2 * FIX_N (truncation)           */
    uint16_t fix_n;     /* FIX_N: smallest N meeting alpha and beta         */
    uint16_t fix_c;     /* FIX_C: abort if errors > FIX_C                   */
} est_consts_t;

#define PARAMS_SCALE 256   /* fixed-point scale of the SPRT score */

/* Fill k from s. Returns 0 on success, -1 if the inputs are invalid or the
 * constants do not fit the 16-bit registers. */
int params_compute(const test_spec_t *s, est_consts_t *k);

/* Fixed-sample design: smallest N (and C) with P(errors > C | p0) <= alpha
 * and P(errors <= C | p1) <= beta. Same search as the Python fixedN().
 * Returns 0 on success. */
int params_fixed_design(double p0, double p1, double alpha, double beta,
                        int n_limit, int *n_out, int *c_out);

/* Block-size rule that pe_top's timing needs (Part 1, docs/pe_top_timing.md),
 * with D = max(NMAX, FIX_N) and no public-channel delay:
 *   1 <= BLOCK_SIZE <= 4096, NMAX >= 1, FIX_N >= 1, D <= 1024,
 *   4*D + ceil(BLOCK_SIZE/32) + 16 <= BLOCK_SIZE.
 * The ARM checks this before CTRL.start. Returns 0 if the settings are valid. */
int params_check_block(uint32_t block_size, uint32_t nmax, uint32_t fix_n);

/* Smallest BLOCK_SIZE that passes params_check_block() for these constants. */
uint32_t params_min_block(uint32_t nmax, uint32_t fix_n);

/* Probability as a 16-bit register value: round(p * 65536), clamped to
 * 0xFFFF (1.0 would wrap to 0 = off in the 16-bit field). */
uint16_t params_q16(double p);

/* The project's protocol: BB84, p0 = 3 %, p1 = 11 %, alpha = beta = 1 % */
extern const test_spec_t PRESET_BB84;

#endif /* PARAMS_H */
