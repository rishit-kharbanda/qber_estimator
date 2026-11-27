#include <inttypes.h>
#include <stdio.h>
#include "uart_log.h"

#define PL_CLOCK_HZ 100e6

void log_header(void)
{
    printf("#mode,preset,p_noise,f_eve,rate_div,block_size,run_s,photons_in,photons_proc,cycles,"
           "pl_dropped,sifted,sifted_errs,blocks_done,sum_n_sprt,sum_n_fix,abort_sprt,abort_fix,"
           "trunc_sprt,key_sprt,key_fix,disclosed,key_out,lat_max,stream_words_sent,"
           "stream_words_dropped,arm_photons,arm_blocks,arm_sum_n_sprt,arm_abort_sprt,arm_match\r\n");
}

void log_comment(const char *text)
{
    printf("# %s\r\n", text);
}

void log_row(const log_run_t *r, const log_pl_t *pl, const log_arm_t *arm)
{
    const uint64_t *v = pl->v;
    double run_s = (double)v[QC_CYCLES] / PL_CLOCK_HZ;
    printf("%s,%s,%u,%u,%lu,%lu,%.6f,"
           "%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ","
           "%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ","
           "%" PRIu64 ",%" PRIu64 ",%lu,%" PRIu64 ",%" PRIu64 ","
           "%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%d\r\n",
           r->mode, r->preset, (unsigned)r->p_noise, (unsigned)r->f_eve,
           (unsigned long)r->rate_div, (unsigned long)r->block_size, run_s,
           v[QC_PHOTONS_IN], v[QC_PHOTONS_PROC], v[QC_CYCLES], v[QC_PL_DROPPED],
           v[QC_SIFTED], v[QC_SIFTED_ERRS], v[QC_BLOCKS_DONE],
           v[QC_SUM_N_SPRT], v[QC_SUM_N_FIX], v[QC_ABORT_SPRT], v[QC_ABORT_FIX],
           v[QC_TRUNC_SPRT], v[QC_KEY_SPRT], v[QC_KEY_FIX],
           v[QC_DISCLOSED], v[QC_KEY_OUT], (unsigned long)pl->lat_max,
           v[QC_STREAM_WORDS_SENT], v[QC_STREAM_WORDS_DROPPED],
           arm->photons, arm->blocks, arm->sum_n_sprt, arm->abort_sprt, arm->match);
}

void log_arm_from_estimator(log_arm_t *a, const swe_counts_t *c, const log_pl_t *pl, int compare)
{
    const uint64_t *v = pl->v;
    a->photons    = c->photons;
    a->blocks     = c->blocks;
    a->sum_n_sprt = c->sum_n_sprt;
    a->abort_sprt = c->abort_sprt;
    if (!compare) { a->match = -1; return; }
    a->match = c->blocks == v[QC_BLOCKS_DONE] && c->sum_n_sprt == v[QC_SUM_N_SPRT] &&
               c->sum_n_fix == v[QC_SUM_N_FIX] && c->abort_sprt == v[QC_ABORT_SPRT] &&
               c->abort_fix == v[QC_ABORT_FIX] && c->trunc_sprt == v[QC_TRUNC_SPRT] &&
               c->key_sprt == v[QC_KEY_SPRT] && c->key_fix == v[QC_KEY_FIX] &&
               c->disclosed == v[QC_DISCLOSED] && c->key_out == v[QC_KEY_OUT];
}
