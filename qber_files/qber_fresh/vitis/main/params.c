/* params.c - estimator constants from (p0, p1, alpha, beta). Part 4. */
#include "params.h"
#include <math.h>

const test_spec_t PRESET_BB84 = { 0.03, 0.11, 0.01, 0.01 };

#define N_LIMIT_MAX 6000
static double pmf0[N_LIMIT_MAX + 1];
static double pmf1[N_LIMIT_MAX + 1];

uint16_t params_q16(double p)
{
    if (p <= 0.0) return 0;
    double v = floor(p * 65536.0 + 0.5);
    return (v >= 65535.0) ? 65535u : (uint16_t)v;
}

int params_check_block(uint32_t block_size, uint32_t nmax, uint32_t fix_n)
{
    uint32_t d = nmax > fix_n ? nmax : fix_n;
    if (block_size < 1 || block_size > 4096 || nmax < 1 || fix_n < 1 || d > 1024)
        return -1;
    return (4u * d + (block_size + 31u) / 32u + 16u <= block_size) ? 0 : -1;
}

uint32_t params_min_block(uint32_t nmax, uint32_t fix_n)
{
    for (uint32_t bs = 1; bs <= 4096; bs++)
        if (params_check_block(bs, nmax, fix_n) == 0)
            return bs;
    return 0;   /* no valid size: D too large */
}

/* Binomial pmf for k = 0..n by the ratio recurrence (no factorials). */
static void binom_pmf(int n, double p, double *pmf)
{
    double r = p / (1.0 - p);
    pmf[0] = exp((double)n * log1p(-p));
    for (int k = 0; k < n; k++)
        pmf[k + 1] = pmf[k] * (double)(n - k) / (double)(k + 1) * r;
}

int params_fixed_design(double p0, double p1, double alpha, double beta,
                        int n_limit, int *n_out, int *c_out)
{
    if (n_limit > N_LIMIT_MAX) n_limit = N_LIMIT_MAX;
    for (int n = 10; n <= n_limit; n++) {
        binom_pmf(n, p0, pmf0);
        binom_pmf(n, p1, pmf1);
        /* smallest c with upper tail P(X > c | p0) <= alpha (summed from the top,
         * so tiny alphas keep their precision) */
        double tail = 0.0;
        int c = n;
        for (int k = n; k >= 0; k--) {
            /* tail = P(X > k-1) = P(X >= k) after adding pmf0[k] */
            tail += pmf0[k];
            if (tail > alpha) { c = k; break; }
            if (k == 0) c = 0;
        }
        /* now P(X > c) <= alpha and P(X > c-1) > alpha */
        double low = 0.0;          /* P(X <= c | p1) */
        for (int k = 0; k <= c; k++) low += pmf1[k];
        if (low <= beta) {
            *n_out = n;
            *c_out = c;
            return 0;
        }
    }
    return -1;
}

static int fits_s16(double v) { return v >= -32768.0 && v <= 32767.0; }

int params_compute(const test_spec_t *s, est_consts_t *k)
{
    if (!(s->p0 > 0.0 && s->p0 < s->p1 && s->p1 < 0.5 &&
          s->alpha > 0.0 && s->alpha < 0.5 && s->beta > 0.0 && s->beta < 0.5))
        return -1;

    const double S = PARAMS_SCALE;
    double ie = floor(S * log(s->p1 / s->p0) + 0.5);
    double io = floor(S * log((1.0 - s->p1) / (1.0 - s->p0)) + 0.5);
    double ta = floor(S * log((1.0 - s->beta) / s->alpha) + 0.5);
    double tb = floor(S * log(s->beta / (1.0 - s->alpha)) + 0.5);
    if (!fits_s16(ie) || !fits_s16(io) || !fits_s16(ta) || !fits_s16(tb))
        return -1;
    /* the score must stay inside s16: |thr| + |inc| < 32768 */
    if (fabs(ta) + fabs(ie) > 32767.0 || fabs(tb) + fabs(io) > 32767.0)
        return -1;

    int n, c;
    if (params_fixed_design(s->p0, s->p1, s->alpha, s->beta, N_LIMIT_MAX, &n, &c) != 0)
        return -1;
    if (2 * n > 65535)
        return -1;

    k->inc_err = (int16_t)ie;
    k->inc_ok  = (int16_t)io;
    k->thr_a   = (int16_t)ta;
    k->thr_b   = (int16_t)tb;
    k->fix_n   = (uint16_t)n;
    k->fix_c   = (uint16_t)c;
    k->nmax    = (uint16_t)(2 * n);
    return 0;
}
