/* ============================================================================
 * sw/ui.h - Part 3 user-interface API (INTERFACES.md section 6b)
 * Implemented by Part 3 (ui.c), called by Part 4 (main.c).
 *
 * How main.c uses it:
 *     ui_settings_t s;
 *     ui_init();
 *     while (1) {
 *         if (ui_poll(&s)) {              // call every ~10 ms
 *             write s.p_noise_q16 / s.f_eve_q16 / mode to the core (BB84 only)
 *             switch (s.action) { 1 run, 2 reliability, 3 rate sweep,
 *                                 4 step, 5 reset }
 *         }
 *         ...  ui_show_results(&r);  ui_show_rate(&rt);  ui_show_status("...");
 *     }
 *
 * Controls
 *   Keypad: A noise %, B Eve %, D mode, 0-9 digits, E clear (C unused),
 *           F run (press), F held 1 s = rate sweep.
 *           A or B starts editing; type digits; press the same letter again
 *           (or any other letter / F / a button) to confirm.
 *   SW0   : down = RUN mode, up = SLOW mode (D cycles RUN/SLOW/STEP)
 *   BTNC run, BTNR step, BTNU reliability test, BTND reset.
 *
 * ui_poll() returns 1 on the first call (defaults: noise 3 %, Eve 0 %,
 * mode from SW0), then whenever a setting changed or an action was
 * requested. s->action is 0 unless an action was requested in that call.
 * ========================================================================== */
#ifndef UI_H
#define UI_H

#include <stdint.h>

typedef struct {
    uint16_t p_noise_q16;   /* P_NOISE register value */
    uint16_t f_eve_q16;     /* F_EVE register value   */
    uint8_t  mode;          /* 0 run, 1 slow, 2 step  */
    uint8_t  action;        /* 0 none, 1 run, 2 reliability test, 3 rate sweep, 4 step, 5 reset */
} ui_settings_t;

#define UI_NA 0xFFFFFFFFu                       /* wrong-decision rate not meaningful (one block) */

typedef struct {
    uint32_t qber_meas_ppm, qber_true_ppm;      /* error rates, parts per million */
    uint32_t sprt_avg_bits_x10;                 /* bits revealed per decision, x10 */
    uint32_t fix_avg_bits_x10;                  /* fixed sample test (always FIX_N = 202) */
    uint32_t sprt_wrong_ppm, fix_wrong_ppm;     /* wrong-decision rates, or UI_NA */
    uint8_t  last_sprt_abort, last_fix_abort;   /* last block's decisions */
} ui_results_t;

typedef struct {
    uint32_t input_rate, fpga_rate, arm_rate;   /* photons per second */
    uint64_t arm_dropped;
} ui_rate_t;

void ui_init(void);                        /* keypad, OLED, GPIO set-up      */
int  ui_poll(ui_settings_t *s);            /* non-blocking; 1 if s changed or an action was requested */
void ui_show_status(const char *msg);      /* one-line message               */
void ui_show_results(const ui_results_t *r);
void ui_show_rate(const ui_rate_t *r);

#endif
