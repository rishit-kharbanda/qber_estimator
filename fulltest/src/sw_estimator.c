/* sw_estimator.c - parameter estimation in C (see sw_estimator.h). Part 4. */
#include "sw_estimator.h"
#include "link_emu.h"
#include "xs64.h"
#include <string.h>

#if defined(__GNUC__)
#define POPCOUNT32(x) ((uint32_t)__builtin_popcount(x))
#define CTZ32(x)      ((uint32_t)__builtin_ctz(x))
#else
#error "needs GCC/Clang builtins"
#endif

/* SEED4 reset value of axi_regs.v ({SEED4_HI, SEED4_LO}) */
#define SEED4_DEFAULT 0x000000052468ACE0ull

void swe_cfg_default(swe_cfg_t *cfg, const est_consts_t *k)
{
    memset(cfg, 0, sizeof(*cfg));
    cfg->block_size   = 4096;
    cfg->k            = *k;
    cfg->sampler_seed = SEED4_DEFAULT;
}

int swe_init(swe_t *s, const swe_cfg_t *cfg)
{
    if (params_check_block(cfg->block_size, cfg->k.nmax, cfg->k.fix_n) != 0)
        return -1;
    memset(s, 0, sizeof(*s));
    s->cfg  = *cfg;
    s->d    = cfg->k.nmax > cfg->k.fix_n ? cfg->k.nmax : cfg->k.fix_n;
    s->samp = cfg->sampler_seed ? cfg->sampler_seed : LINK_ZERO_SUB[4];
    for (uint32_t p = 0; p < cfg->block_size; p++)
        s->perm[p] = (uint16_t)p;
    return 0;
}

/* Test one full block (pe_top + dec_top). The sampler always makes exactly D
 * steps, so RNG5 and P stay in step with the PL whatever the decisions. */
static void test_block(swe_t *s)
{
    const est_consts_t *k = &s->cfg.k;
    const uint32_t B = s->cfg.block_size, D = s->d;
    uint16_t idx[SWE_MAX_D];

    if (s->cfg.test_all) {
        for (uint32_t i = 0; i < D; i++) idx[i] = (uint16_t)i;
    } else {
        uint16_t *P = s->perm;
        for (uint32_t i = 0; i < D; i++) {
            uint64_t r24 = xs64_next(&s->samp) >> 40;
            uint32_t j   = i + (uint32_t)((r24 * (uint64_t)(B - i)) >> 24);
            uint16_t t = P[i]; P[i] = P[j]; P[j] = t;
            idx[i] = P[i];
        }
    }

    int32_t  score = 0;
    uint32_t n_s = 0, n_f = 0, e_f = 0, errs = 0, d;
    int s_done = 0, f_done = 0, s_abort = 0, f_abort = 0, trunc = 0;

    for (d = 0; d < D && !(s_done && f_done); d++) {
        uint32_t err = s->e[idx[d]];             /* compare */
        errs += err;
        if (!s_done) {                           /* sprt_engine.v */
            score += err ? k->inc_err : k->inc_ok;
            n_s++;
            if (score >= k->thr_a)      { s_done = 1; s_abort = 1; }
            else if (score <= k->thr_b) { s_done = 1; s_abort = 0; }
            else if (n_s == k->nmax)    { s_done = 1; s_abort = score > 0; trunc = 1; }
        }
        if (!f_done) {                           /* fixed_engine.v */
            n_f++;
            e_f += err;
            if (n_f == k->fix_n)                               { f_done = 1; f_abort = e_f > k->fix_c; }
            else if (s->cfg.curtail && e_f > k->fix_c)         { f_done = 1; f_abort = 1; }
            else if (s->cfg.curtail && e_f + (k->fix_n - n_f) <= k->fix_c) { f_done = 1; f_abort = 0; }
        }
    }
    /* d = max(n_s, n_f): both engines see every disclosed bit (stop-and-wait) */

    swe_counts_t *c = &s->c;
    swe_block_t b;
    b.index        = c->blocks;
    b.n_sprt       = (uint16_t)n_s;
    b.n_fix        = (uint16_t)n_f;
    b.sprt_abort   = (uint8_t)s_abort;
    b.fix_abort    = (uint8_t)f_abort;
    b.trunc        = (uint8_t)trunc;
    b.blk_sifted   = (uint16_t)B;
    b.blk_true_err = (uint16_t)s->blk_errs;
    b.n_disclosed  = (uint16_t)d;

    c->blocks++;
    c->disclosed  += d;
    c->test_errs  += errs;
    c->sum_n_sprt += n_s;
    c->sum_n_fix  += n_f;
    c->abort_sprt += (uint64_t)s_abort;
    c->abort_fix  += (uint64_t)f_abort;
    c->trunc_sprt += (uint64_t)trunc;
    c->key_sprt   += s_abort ? 0 : (uint64_t)(B - n_s);
    c->key_fix    += f_abort ? 0 : (uint64_t)(B - n_f);
    c->key_out    += s_abort ? 0 : (uint64_t)(B - d);
    c->last_sprt_abort = (uint8_t)s_abort;
    c->last_fix_abort  = (uint8_t)f_abort;
    c->last_trunc      = (uint8_t)trunc;

    if (s->cfg.num_blocks && c->blocks >= s->cfg.num_blocks)
        s->full = 1;
    if (s->cfg.on_block)
        s->cfg.on_block(s->cfg.ctx, &b);
}

static inline void push_sifted(swe_t *s, uint32_t err)
{
    if (s->full)
        return;                                  /* run over: like busy = 0 */
    s->e[s->fill] = (uint8_t)err;
    s->blk_errs  += err;
    if (++s->fill == s->cfg.block_size) {
        test_block(s);
        s->fill = 0;
        s->blk_errs = 0;
    }
}

/* Word-parallel: d = w ^ (w >> 2) puts a_bit^b_bit at bit 4i and
 * a_basis^b_basis at bit 4i+1 of each nibble. */
void swe_process(swe_t *s, const uint32_t *words, size_t n)
{
    uint64_t sifted = 0, errs = 0;
    for (size_t i = 0; i < n; i++) {
        uint32_t w  = words[i];
        uint32_t d  = w ^ (w >> 2);
        uint32_t sm = ~d & 0x22222222u;          /* bit 4i+1: photon i sifted */
        uint32_t em = d & (sm >> 1);             /* bit 4i: sifted and wrong   */
        sifted += POPCOUNT32(sm);
        errs   += POPCOUNT32(em);
        while (sm) {
            uint32_t sh = CTZ32(sm) - 1u;        /* 4i: oldest photon first */
            push_sifted(s, (em >> sh) & 1u);
            sm &= sm - 1u;
        }
    }
    s->c.photons     += 8u * (uint64_t)n;
    s->c.sifted      += sifted;
    s->c.sifted_errs += errs;
}

/* One photon at a time, structured like the RTL (unpack -> sift -> store). */
void swe_process_simple(swe_t *s, const uint32_t *words, size_t n)
{
    for (size_t i = 0; i < n; i++) {
        uint32_t w = words[i];
        for (int p = 0; p < 8; p++) {
            uint32_t nib     = (w >> (4 * p)) & 0xFu;
            uint32_t a_bit   = nib & 1u;
            uint32_t a_basis = (nib >> 1) & 1u;
            uint32_t b_bit   = (nib >> 2) & 1u;
            uint32_t b_basis = (nib >> 3) & 1u;
            s->c.photons++;
            if (a_basis == b_basis) {
                s->c.sifted++;
                s->c.sifted_errs += a_bit ^ b_bit;
                push_sifted(s, a_bit ^ b_bit);
            }
        }
    }
}
