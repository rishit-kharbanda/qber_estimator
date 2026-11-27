#include <inttypes.h>
#include <stdio.h>
#include "platform.h"
#include "qber_hw.h"
#include "params.h"
#include "sw_estimator.h"
#include "golden_cases.h"

#define PKT_WORDS     256u
#define CASE_RATE_DIV 8u
#define SWEEP_SECONDS 0.5
#define PL_CLOCK_HZ   100e6

static uint32_t rx[4096];
static swe_t est;
static int fails = 0;

static uint64_t drain(uint64_t got, double timeout_s)
{
    uint64_t t_end = now_ticks() + (uint64_t)(timeout_s * (double)TICKS_PER_SEC);
    for (;;) {
        uint32_t n = qfifo_read(rx, sizeof(rx) / sizeof(rx[0]));
        if (n) { swe_process(&est, rx, n); got += n; }
        uint64_t sent = qhw_rd64(QR_CNT(QC_STREAM_WORDS_SENT));
        if ((got >= sent && !(qhw_status() & ST_BUSY)) || now_ticks() > t_end) return got;
    }
}

static void start_run(uint32_t levels)
{
    qhw_set_levels(levels | CTRL_STREAM_EN);
    qhw_pulse(CTRL_START);
}

static void golden_case(const golden_case_t *g)
{
    est_consts_t k = { g->inc_err, g->inc_ok, g->thr_a, g->thr_b, g->nmax, g->fix_n, g->fix_c };
    swe_cfg_t cfg;
    swe_cfg_default(&cfg, &k);
    cfg.block_size = g->block_size; cfg.num_blocks = g->num_blocks;
    cfg.curtail = g->curtail; cfg.test_all = g->test_all; cfg.sampler_seed = g->seed[4];
    if (swe_init(&est, &cfg) != 0) { printf("FAIL %s: configuration rejected\r\n", g->name); fails++; return; }

    qhw_set_levels(0);
    qhw_soft_reset();
    qfifo_reset();
    qhw_wr(QR_P_NOISE, g->p_noise);
    qhw_wr(QR_F_EVE, g->f_eve);
    qhw_wr(QR_RATE_DIV, CASE_RATE_DIV);
    qhw_wr(QR_BLOCK_SIZE, g->block_size);
    qhw_wr(QR_NUM_BLOCKS, g->num_blocks);
    qhw_wr(QR_STREAM_PKT, PKT_WORDS);
    qhw_write_consts(&k);
    qhw_write_seeds(g->seed);
    uint32_t levels = CTRL_MODE_RUN | (g->curtail ? CTRL_CURTAIL_EN : 0) | (g->test_all ? CTRL_TEST_ALL : 0);

    uint64_t t0 = now_ticks();
    start_run(levels);
    uint64_t got = 0;
    while (!(qhw_status() & ST_DONE) && ticks_to_s(now_ticks() - t0) < 10.0) {
        uint32_t n = qfifo_read(rx, sizeof(rx) / sizeof(rx[0]));
        if (n) { swe_process(&est, rx, n); got += n; }
    }
    got = drain(got, 0.2);
    qhw_set_levels(levels);
    got = drain(got, 0.05);
    double secs = ticks_to_s(now_ticks() - t0);

    qhw_counters_t c;
    qhw_read_counters(&c);
    uint32_t st = qhw_status();
    const swe_counts_t *a = &est.c;
    static const struct { const char *name; int qc; int ex; } ref[] = {
        { "BLOCKS_DONE", QC_BLOCKS_DONE, 0 }, { "SUM_N_SPRT", QC_SUM_N_SPRT, 1 },
        { "SUM_N_FIX", QC_SUM_N_FIX, 2 },     { "ABORT_SPRT", QC_ABORT_SPRT, 3 },
        { "ABORT_FIX", QC_ABORT_FIX, 4 },     { "TRUNC_SPRT", QC_TRUNC_SPRT, 5 },
        { "KEY_SPRT", QC_KEY_SPRT, 6 },       { "KEY_FIX", QC_KEY_FIX, 7 },
        { "DISCLOSED", QC_DISCLOSED, 8 },     { "KEY_OUT", QC_KEY_OUT, 9 },
        { "SIFTED", QC_SIFTED, 10 },          { "SIFTED_ERRS", QC_SIFTED_ERRS, 11 },
        { "PHOTONS_IN", QC_PHOTONS_IN, 12 } };
    uint64_t arm[10] = { a->blocks, a->sum_n_sprt, a->sum_n_fix, a->abort_sprt, a->abort_fix,
                         a->trunc_sprt, a->key_sprt, a->key_fix, a->disclosed, a->key_out };
    int pl_ok = 1, arm_ok = 1;
    for (unsigned i = 0; i < sizeof ref / sizeof ref[0]; i++) {
        if (c.v[ref[i].qc] != g->exp[ref[i].ex]) {
            pl_ok = 0;
            printf("  %s: PL %s=%" PRIu64 " model=%" PRIu64 "\r\n", g->name, ref[i].name,
                   c.v[ref[i].qc], g->exp[ref[i].ex]);
        }
        if (i < 10 && arm[i] != c.v[ref[i].qc]) {
            arm_ok = 0;
            printf("  %s: ARM %s=%" PRIu64 " PL=%" PRIu64 "\r\n", g->name, ref[i].name, arm[i], c.v[ref[i].qc]);
        }
    }
    int rate_ok = c.v[QC_PHOTONS_PROC] == c.v[QC_PHOTONS_IN] && c.v[QC_PL_DROPPED] == 0 && !(st & ST_PE_ERR);
    int strm_ok = got == c.v[QC_STREAM_WORDS_SENT] && c.v[QC_STREAM_WORDS_DROPPED] == 0 &&
                  c.v[QC_STREAM_WORDS_SENT] == c.v[QC_PHOTONS_IN] / 8u;
    if (!pl_ok || !arm_ok || !rate_ok || !strm_ok) fails++;
    printf("%s,%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%.3f,%s,%s,%s,%s\r\n",
           g->name, c.v[QC_BLOCKS_DONE], c.v[QC_PHOTONS_IN], c.v[QC_SUM_N_SPRT], c.v[QC_SUM_N_FIX], secs,
           pl_ok ? "PL=model" : "PL!=model", rate_ok ? "no_PL_drops" : "PL_DROPS",
           strm_ok ? "stream_ok" : "STREAM_ERR", arm_ok ? "ARM=PL" : "ARM!=PL");
}

static void rate_point(uint32_t rate_div)
{
    est_consts_t k;
    swe_cfg_t cfg;
    params_compute(&PRESET_BB84, &k);
    swe_cfg_default(&cfg, &k);
    swe_init(&est, &cfg);

    qhw_set_levels(0);
    qhw_soft_reset();
    qfifo_reset();
    qhw_wr(QR_P_NOISE, params_q16(0.03));
    qhw_wr(QR_F_EVE, 0);
    qhw_wr(QR_RATE_DIV, rate_div);
    qhw_wr(QR_BLOCK_SIZE, 4096);
    qhw_wr(QR_NUM_BLOCKS, 0);
    qhw_wr(QR_STREAM_PKT, PKT_WORDS);
    qhw_write_consts(&k);

    uint64_t t0 = now_ticks(), t_end = t0 + (uint64_t)(SWEEP_SECONDS * (double)TICKS_PER_SEC);
    start_run(CTRL_MODE_RUN);
    uint64_t got = 0;
    while (now_ticks() < t_end) {
        uint32_t n = qfifo_read(rx, sizeof(rx) / sizeof(rx[0]));
        if (n) { swe_process(&est, rx, n); got += n; }
    }
    double t_arm = ticks_to_s(now_ticks() - t0);
    uint64_t got_window = got;
    qhw_pulse(CTRL_STOP);
    qhw_wait_idle(100);
    got = drain(got, 0.2);
    qhw_set_levels(CTRL_MODE_RUN);
    got = drain(got, 0.05);

    qhw_counters_t c;
    qhw_read_counters(&c);
    double busy_s  = (double)c.v[QC_CYCLES] / PL_CLOCK_HZ;
    double in_mps  = PL_CLOCK_HZ / (double)rate_div / 1e6;
    double pl_mps  = busy_s > 0 ? (double)c.v[QC_PHOTONS_PROC] / busy_s / 1e6 : 0;
    double arm_mps = 8.0 * (double)got_window / t_arm / 1e6;
    uint64_t sent = c.v[QC_STREAM_WORDS_SENT], dropped = c.v[QC_STREAM_WORDS_DROPPED];
    double drop_pct = sent + dropped ? 100.0 * (double)dropped / (double)(sent + dropped) : 0;
    printf("%lu,%.2f,%.2f,%" PRIu64 ",%" PRIu64 ",%.2f,%" PRIu64 ",%" PRIu64 ",%.2f,%" PRIu64 ",%" PRIu64 "\r\n",
           (unsigned long)rate_div, in_mps, pl_mps, c.v[QC_PL_DROPPED], c.v[QC_BLOCKS_DONE],
           arm_mps, sent, dropped, drop_pct, est.c.blocks, (uint64_t)qhw_rd(QR_LAT_MAX));
}

int main(void)
{
    printf("\r\n# QBER full design test (%s), built %s %s\r\n", PLATFORM_NAME, __DATE__, __TIME__);
    uint32_t id, ver;
    if (qhw_probe(&id, &ver) != 0) {
        printf("# FAIL: ID %08lx. Wrong bitstream or base address?\r\n# done\r\n", (unsigned long)id);
        return 1;
    }
    printf("# ID %08lx, VERSION %lu.%lu.%lu, %s\r\n", (unsigned long)id,
           (unsigned long)((ver >> 16) & 0xFF), (unsigned long)((ver >> 8) & 0xFF),
           (unsigned long)(ver & 0xFF), (ver & 0x80000000u) ? "full core" : "BRING-UP STUB (wrong bitstream)");
    if (!(ver & 0x80000000u)) { printf("# done\r\n"); return 1; }

    printf("# A. golden cases at RATE_DIV=%u (model v2)\r\n", CASE_RATE_DIV);
    printf("#case,blocks,photons,sum_n_sprt,sum_n_fix,seconds,pl_vs_model,pl_drops,stream,arm_vs_pl\r\n");
    for (int i = 0; i < GOLDEN_N_CASES; i++) golden_case(&GOLDEN_CASES[i]);

    printf("# B. rate sweep, BB84 defaults, QBER 3%%, %.1f s per point\r\n", SWEEP_SECONDS);
    printf("#rate_div,input_mph_s,pl_mph_s,pl_dropped,pl_blocks,arm_mph_s,words_sent,words_dropped,"
           "arm_drop_pct,arm_blocks,lat_max_cycles\r\n");
    static const uint32_t rates[] = { 64, 32, 16, 12, 8, 6, 4, 3, 2, 1 };
    for (unsigned i = 0; i < sizeof rates / sizeof rates[0]; i++) rate_point(rates[i]);

    printf(fails ? "# fulltest: FAIL (%d)\r\n" : "# fulltest: PASS\r\n", fails);
    printf("# done\r\n");
    return fails != 0;
}
