#include <stdio.h>
#include <string.h>
#include "platform.h"
#include "qber_hw.h"
#include "uart_log.h"
#include "sweeps.h"
#include "ui.h"

#ifndef DEMO_BLOCKS
#define DEMO_BLOCKS        5000u
#endif
#ifndef REL_BLOCKS
#define REL_BLOCKS         20000u
#endif
#ifndef RATE_SECONDS
#define RATE_SECONDS       0.5
#endif
#ifndef SLOW_DIV_DEMO
#define SLOW_DIV_DEMO      6250000u
#endif
#ifndef SLOW_FINISH_FAST
#define SLOW_FINISH_FAST   1
#endif
#define STEPS_PER_BIT      4u
#define POLL_TICKS         (TICKS_PER_SEC / 100u)
#define LIVE_TICKS         (TICKS_PER_SEC / 8u)
#define PL_CLOCK_HZ        100e6

static ui_settings_t set;
static uint8_t       pending;

static const test_spec_t *preset_spec(void)
{
    return &PRESET_BB84;
}

static double true_qber(uint16_t p_noise_q16, uint16_t f_eve_q16)
{
    double p = p_noise_q16 / 65536.0, e = 0.25 * (f_eve_q16 / 65536.0);
    return e + p - 2.0 * e * p;
}

static uint32_t ppm(uint64_t num, uint64_t den)
{
    return den ? (uint32_t)((num * 1000000ull + den / 2u) / den) : 0u;
}

static uint32_t x10(uint64_t num, uint64_t den)
{
    return den ? (uint32_t)((num * 10ull + den / 2u) / den) : 0u;
}

static void req_from_settings(run_req_t *q, const char *mode, uint32_t idx)
{
    run_req_default(q, mode, "bb84", idx);
    params_compute(preset_spec(), &q->k);
    if (params_check_block(q->block_size, q->k.nmax, q->k.fix_n) != 0)
        q->block_size = params_min_block(q->k.nmax, q->k.fix_n);
    q->p_noise  = set.p_noise_q16;
    q->f_eve    = set.f_eve_q16;
    q->slow_div = SLOW_DIV_DEMO;
}

static void show_results(const run_req_t *q, const log_pl_t *pl)
{
    const uint64_t *v = pl->v;
    uint64_t blocks = v[QC_BLOCKS_DONE];
    double   qt  = true_qber(q->p_noise, q->f_eve);
    test_spec_t s = *preset_spec();

    int safe = qt < 0.5 * (s.p0 + s.p1);
    uint64_t wrong_sprt = safe ? v[QC_ABORT_SPRT] : blocks - v[QC_ABORT_SPRT];
    uint64_t wrong_fix  = safe ? v[QC_ABORT_FIX]  : blocks - v[QC_ABORT_FIX];

    ui_results_t r;
    memset(&r, 0, sizeof r);
    r.qber_meas_ppm     = ppm(v[QC_SIFTED_ERRS], v[QC_SIFTED]);
    r.qber_true_ppm     = (uint32_t)(qt * 1e6 + 0.5);
    r.sprt_avg_bits_x10 = x10(v[QC_SUM_N_SPRT], blocks);
    r.fix_avg_bits_x10  = x10(v[QC_SUM_N_FIX], blocks);
    r.sprt_wrong_ppm    = blocks > 1 ? ppm(wrong_sprt, blocks) : UI_NA;
    r.fix_wrong_ppm     = blocks > 1 ? ppm(wrong_fix, blocks)  : UI_NA;
    uint32_t st = qhw_status();
    r.last_sprt_abort   = (st & ST_LAST_SPRT_ABORT) != 0;
    r.last_fix_abort    = (st & ST_LAST_FIX_ABORT) != 0;
    ui_show_results(&r);
    if (blocks == 0) ui_show_status("Stopped: no block");
}

static uint64_t t_poll;
static int idle_ui(void)
{
    uint64_t t = now_ticks();
    if (t < t_poll) return 0;
    t_poll = t + POLL_TICKS;
    ui_settings_t s;
    if (ui_poll(&s)) {
        uint8_t a = s.action;
        s.action = 0;
        set = s;
        if (a && a != 4 && pending != 5) pending = a;
        if (a == 5) return 1;
    }
    return 0;
}

static uint64_t t_live;
static int      sprt_decided;
static int idle_live(void)
{
    uint64_t t = now_ticks();
    if (t >= t_poll) {
        t_poll = t + POLL_TICKS;
        ui_settings_t s;
        if (ui_poll(&s)) {
            uint8_t a = s.action;
            s.action = 0;
            set = s;
            if (a == 4) {
                if ((qhw_levels() & CTRL_MODE_MASK) == CTRL_MODE_STEP)
                    for (unsigned i = 0; i < STEPS_PER_BIT; i++) qhw_pulse(CTRL_STEP);
            } else if (a == 1 || a == 5) {
                pending = (a == 5) ? 5 : 0;
                return 1;
            } else if (a) {
                pending = a;
                return 1;
            }
        }
    }
    if (t >= t_live) {
        t_live = t + LIVE_TICKS;
        int16_t  score = (int16_t)qhw_rd(QR_LIVE_SCORE);
        uint32_t ln    = qhw_rd(QR_LIVE_N);
        uint32_t n_sprt = ln & 0xFFFFu, n_fix = ln >> 16;
        char msg[24];
        snprintf(msg, sizeof msg, "S%+6d n%3lu/%3lu", score, (unsigned long)n_sprt, (unsigned long)n_fix);
        ui_show_status(msg);
#if SLOW_FINISH_FAST

        if (!sprt_decided && n_sprt > 0 && n_fix > n_sprt) {
            sprt_decided = 1;
            qhw_set_levels((qhw_levels() & ~CTRL_MODE_MASK) | CTRL_MODE_RUN);
        }
#endif
    }
    return 0;
}

static uint32_t run_idx = 1000;

static void do_run(void)
{
    run_req_t q;
    log_pl_t  pl;
    req_from_settings(&q, LOG_MODE_SINGLE, run_idx++);
    if (set.mode == 0) {
        q.num_blocks = DEMO_BLOCKS;
        q.max_s      = 30.0;
        q.idle       = idle_ui;
    } else {
        q.ctrl_mode  = (set.mode == 1) ? CTRL_MODE_SLOW : CTRL_MODE_STEP;
        q.num_blocks = 1;
        q.max_s      = 3600.0;
        q.idle       = idle_live;
        sprt_decided = 0;
        t_live       = 0;
        ui_show_status(set.mode == 1 ? "Slow: watch LEDs" : "Step: press BTNR");
    }
    q.curtail = 0;
    if (run_once(&q, &pl, NULL) == 0) show_results(&q, &pl);
    else if (pending != 5) ui_show_status("Bad block size");
}

static void do_reliability(void)
{
    static const double qber[2] = { 0.03, 0.11 };
    ui_settings_t keep = set;
    log_comment("demo reliability: QBER 3% (safe), then 11% (unsafe)");
    for (int i = 0; i < 2 && pending != 5; i++) {
        run_req_t q;
        log_pl_t  pl;
        req_from_settings(&q, LOG_MODE_REL, 2000u + (uint32_t)i);
        q.p_noise    = params_q16(qber[i]);
        q.f_eve      = 0;
        q.num_blocks = REL_BLOCKS;
        q.idle       = idle_ui;
        ui_show_status(i ? "Reliability 11%" : "Reliability 3%");
        q.curtail    = 0;
        if (run_once(&q, &pl, NULL) == 0) {
            show_results(&q, &pl);
            if (i == 0) {
                uint64_t t_end = now_ticks() + 8u * TICKS_PER_SEC;
                while (now_ticks() < t_end && pending != 5) idle_ui();
            }
        }
    }
    set = keep;
}

static void rate_hook(const run_req_t *q, const log_pl_t *pl, const log_arm_t *arm)
{
    const uint64_t *v = pl->v;
    double secs = v[QC_CYCLES] / PL_CLOCK_HZ;
    ui_rate_t r;
    r.input_rate  = (uint32_t)(PL_CLOCK_HZ / (q->rate_div ? q->rate_div : 1u));
    r.fpga_rate   = secs > 0 ? (uint32_t)(v[QC_PHOTONS_PROC] / secs) : 0u;
    r.arm_rate    = secs > 0 ? (uint32_t)(arm->photons / secs) : 0u;
    r.arm_dropped = 8u * v[QC_STREAM_WORDS_DROPPED];
    ui_show_rate(&r);
    idle_ui();
}

static void do_rate_sweep(void)
{
    run_hook = rate_hook;
    sweep_rate(RATE_SECONDS, 0);
    run_hook = 0;
    ui_show_status("Rate sweep done");
}

static void do_reset(void)
{
    qhw_pulse(CTRL_STOP);
    qhw_set_levels(0);
    qhw_soft_reset();
    qfifo_reset();
    ui_show_status("Reset");
}

int main(void)
{
    uint32_t id = 0, ver = 0;
    printf("\r\n# QBER estimator demo (Parts 3 and 4)\r\n");
    ui_init();
    if (qhw_probe(&id, &ver) != 0 || !(ver & 0x80000000u)) {
        printf("# no full core (ID 0x%08lx VERSION 0x%08lx): program the -full bitstream\r\n",
               (unsigned long)id, (unsigned long)ver);
        ui_show_status("No full core!");
        for (;;) ;
    }
    log_header();
    ui_poll(&set);
    set.action = 0;
    ui_show_status("Ready: F to run");

    for (;;) {
        uint8_t a = pending;
        pending = 0;
        if (!a) {
            ui_settings_t s;
            uint64_t t_next = now_ticks() + POLL_TICKS;
            while (now_ticks() < t_next) ;
            if (ui_poll(&s)) { a = s.action; s.action = 0; set = s; }
        }
        switch (a) {
        case 1: do_run();         break;
        case 2: do_reliability(); break;
        case 3: do_rate_sweep();  break;
        case 4: ui_show_status(set.mode == 2 ? "F first, then BTNR" : "Step: STEP mode only"); break;
        case 5: do_reset();       break;
        default: break;
        }
    }
}
