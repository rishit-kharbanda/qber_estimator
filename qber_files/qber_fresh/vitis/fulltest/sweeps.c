#include <stdio.h>
#include <string.h>
#include "platform.h"
#include "qber_hw.h"
#include "sw_estimator.h"
#include "sweeps.h"

#define PKT_WORDS   256u
#define PL_CLOCK_HZ 100e6

static uint32_t rx[4096];
static swe_t    est;

void (*run_hook)(const run_req_t *q, const log_pl_t *pl, const log_arm_t *arm) = 0;

void run_req_default(run_req_t *q, const char *mode, const char *preset, uint32_t idx)
{
    memset(q, 0, sizeof(*q));
    q->mode = mode;
    q->preset = preset;
    params_compute(&PRESET_BB84, &q->k);
    q->rate_div = 1;
    q->block_size = 4096;
    q->max_s = 60.0;
    q->ctrl_mode = CTRL_MODE_RUN;
    q->slow_div = 6250000u;

    static const uint64_t base[5] = { 0x1234ABCD5678EF01ull, 0x0BADF00DCAFEBABEull, 0xDEADBEEF01234567ull,
                                      0x13579BDF2468ACE0ull, 0x0F1E2D3C4B5A6978ull };
    for (int i = 0; i < 5; i++)
        q->seed[i] = base[i] ^ (0x9E3779B97F4A7C15ull * (uint64_t)(idx + 1u));
}

static uint64_t pump(int estimate)
{
    uint32_t n = qfifo_read(rx, sizeof(rx) / sizeof(rx[0]));
    if (n && estimate) swe_process(&est, rx, n);
    return n;
}

int run_once(const run_req_t *q, log_pl_t *pl_out, log_arm_t *arm_out)
{
    log_pl_t  pl;
    log_arm_t arm = { 0, 0, 0, 0, -1 };

    if (params_check_block(q->block_size, q->k.nmax, q->k.fix_n) != 0) {
        printf("# skipped %s/%s: BLOCK_SIZE %lu breaks the timing rule\r\n",
               q->mode, q->preset, (unsigned long)q->block_size);
        return -1;
    }
    int estimate = q->stream && q->arm_estimate;
    if (estimate) {
        swe_cfg_t cfg;
        swe_cfg_default(&cfg, &q->k);
        cfg.block_size = q->block_size; cfg.num_blocks = q->num_blocks;
        cfg.curtail = q->curtail; cfg.test_all = q->test_all; cfg.sampler_seed = q->seed[4];
        swe_init(&est, &cfg);
    }

    qhw_set_levels(0);
    qhw_soft_reset();
    qfifo_reset();
    qhw_wr(QR_P_NOISE, q->p_noise);
    qhw_wr(QR_F_EVE, q->f_eve);
    qhw_wr(QR_RATE_DIV, q->rate_div);
    qhw_wr(QR_SLOW_DIV, q->slow_div);
    qhw_wr(QR_BLOCK_SIZE, q->block_size);
    qhw_wr(QR_NUM_BLOCKS, q->num_blocks);
    qhw_wr(QR_STREAM_PKT, PKT_WORDS);
    qhw_write_consts(&q->k);
    qhw_write_seeds(q->seed);
    uint32_t levels = (q->ctrl_mode & CTRL_MODE_MASK) | (q->curtail ? CTRL_CURTAIL_EN : 0) | (q->test_all ? CTRL_TEST_ALL : 0);

    uint64_t words = 0, t0 = now_ticks();
    uint64_t t_end = t0 + (uint64_t)(q->max_s * (double)TICKS_PER_SEC);
    qhw_set_levels(levels | (q->stream ? CTRL_STREAM_EN : 0));
    qhw_pulse(CTRL_START);
    for (;;) {
        if (q->stream) words += pump(estimate);
        if (qhw_status() & ST_DONE) break;
        if (now_ticks() > t_end || (q->idle && q->idle())) { qhw_pulse(CTRL_STOP); break; }
    }
    qhw_wait_idle(100);

    uint64_t t_settle = now_ticks() + TICKS_PER_SEC / 500u;
    while (now_ticks() < t_settle)
        if (q->stream) words += pump(estimate);
    qhw_set_levels(levels);
    if (q->stream) {
        uint64_t sent = qhw_rd64(QR_CNT(QC_STREAM_WORDS_SENT));
        uint64_t t_drain = now_ticks() + TICKS_PER_SEC / 5u;
        while (words < sent && now_ticks() < t_drain)
            words += pump(estimate);
    }

    qhw_counters_t c;
    qhw_read_counters(&c);
    memcpy(pl.v, c.v, sizeof(pl.v));
    pl.lat_max = qhw_rd(QR_LAT_MAX);

    if (q->stream) {
        if (estimate) {
            int compare = pl.v[QC_STREAM_WORDS_DROPPED] == 0 && words == pl.v[QC_STREAM_WORDS_SENT];
            log_arm_from_estimator(&arm, &est.c, &pl, compare);
        } else {
            arm.photons = 8u * words;
        }
    }

    log_row(&(log_run_t){ q->mode, q->preset, q->p_noise, q->f_eve, q->rate_div, q->block_size }, &pl, &arm);
    if (run_hook) run_hook(q, &pl, &arm);
    if (pl_out) *pl_out = pl;
    if (arm_out) *arm_out = arm;
    return 0;
}

void sweep_graph1(uint32_t blocks_per_point)
{
    static const double qber_pct[] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 17, 20, 25 };
    char msg[96];
    snprintf(msg, sizeof msg, "Graph 1: error-level sweep, %lu blocks per point, full rate, FPGA only",
             (unsigned long)blocks_per_point);
    log_comment(msg);
    uint32_t idx = 100;
    for (unsigned i = 0; i < sizeof qber_pct / sizeof qber_pct[0]; i++) {
        run_req_t q;
        run_req_default(&q, LOG_MODE_G1, "bb84", idx++);
        q.p_noise    = params_q16(qber_pct[i] / 100.0);
        q.num_blocks = blocks_per_point;
        q.curtail    = 0;
        run_once(&q, NULL, NULL);
    }
}

void sweep_reliability(uint32_t blocks)
{
    char msg[96];
    snprintf(msg, sizeof msg, "reliability: %lu blocks at QBER 3%% (safe) and 11%% (unsafe), FPGA only",
             (unsigned long)blocks);
    log_comment(msg);
    static const double qber[] = { 0.03, 0.11 };
    for (int i = 0; i < 2; i++) {
        run_req_t q;
        run_req_default(&q, LOG_MODE_REL, "bb84", 200u + (uint32_t)i);
        q.p_noise    = params_q16(qber[i]);
        q.num_blocks = blocks;
        run_once(&q, NULL, NULL);
    }
}

void sweep_rate(double seconds_per_point, int readonly_pass)
{
    static const uint32_t rates[] = { 64, 32, 16, 12, 10, 8, 7, 6, 5, 4, 3, 2, 1 };
    char msg[112];
    snprintf(msg, sizeof msg, "Graph 2: input-rate sweep, QBER 3%%, %.1f s per point; ARM read+estimate, then read only",
             seconds_per_point);
    log_comment(msg);
    for (int pass = 0; pass < (readonly_pass ? 2 : 1); pass++)
        for (unsigned i = 0; i < sizeof rates / sizeof rates[0]; i++) {
            run_req_t q;
            run_req_default(&q, LOG_MODE_RATE, pass ? "bb84+readonly" : "bb84", 300u + i);
            q.p_noise      = params_q16(0.03);
            q.rate_div     = rates[i];
            q.stream       = 1;
            q.arm_estimate = !pass;

            double photons = PL_CLOCK_HZ / (double)rates[i] * seconds_per_point;
            uint32_t nb = (uint32_t)(photons / (2.0 * (double)q.block_size));
            q.num_blocks = nb < 20u ? 20u : nb;
            q.max_s      = 4.0 * seconds_per_point + 1.0;
            run_once(&q, NULL, NULL);
        }
}

void run_long(double seconds)
{
    char msg[112];
    snprintf(msg, sizeof msg, "sustained rate: %.1f s at one photon per clock (pass if photons_proc = photons_in, pl_dropped = 0)",
             seconds);
    log_comment(msg);
    run_req_t q;
    run_req_default(&q, LOG_MODE_LONG, "bb84", 400);
    q.p_noise    = params_q16(0.03);
    q.num_blocks = 0;
    q.max_s      = seconds;
    log_pl_t pl;
    if (run_once(&q, &pl, NULL) == 0)
        printf("# sustained rate: %s (%.3f G photons in, %.3f G processed, %llu dropped)\r\n",
               (pl.v[QC_PHOTONS_PROC] == pl.v[QC_PHOTONS_IN] && pl.v[QC_PL_DROPPED] == 0) ? "PASS" : "FAIL",
               (double)pl.v[QC_PHOTONS_IN] / 1e9, (double)pl.v[QC_PHOTONS_PROC] / 1e9,
               (unsigned long long)pl.v[QC_PL_DROPPED]);
}
