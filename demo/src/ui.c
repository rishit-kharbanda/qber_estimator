/* ============================================================================
 * sw/ui.c - Part 3 user interface (INTERFACES.md 6b)
 *
 * Owns the keypad, the 128x64 OLED, the switches and the buttons.
 * Part 4's main.c calls ui_poll() every ~10 ms and the ui_show_*()
 * functions when it has something to display. See ui.h for the controls.
 *
 * Screens (8 rows x 16 characters):
 *
 *   SETTINGS            RESULTS             FPGA vs ARM
 *   ----------------    ----------------    ----------------
 *    QBER ESTIMATOR      RESULTS             FPGA vs ARM
 *                       Meas QBER 3.01%     Input  100.0M/s
 *   Noise : 3%          True QBER 3.00%     FPGA   100.0M/s
 *   Eve   : 0%          SPRT 102.7 SAFE     ARM     18.6M/s
 *   Proto : BB84        Fix  202.0 SAFE     ARM drop 81.4M
 *   Mode  : RUN         Err% S0.68 F0.84    FPGA keeps up
 *   A/B set D=mode      Bits saved   49%    ARM falls behind
 *   F=run hold=sweep    F=run hold=sweep    (status line)
 *
 * Results: bits revealed per decision by the SPRT and the fixed test, the last
 * block's decisions, the wrong-decision rates (S = SPRT, F = fixed test) and
 * the bits the SPRT saved against the fixed test.
 * ========================================================================== */
#include "ui.h"
#include "kypd.h"
#include "oled.h"
#include "btnsw.h"
#include "xil_printf.h"
#include "platform.h"           /* now_ticks(): the A9 global timer (no xtime_l.h needed) */
#include <stdio.h>
#include <string.h>

#define LONG_PRESS_MS 1000            /* hold F this long = rate sweep  */
#define DEFAULT_NOISE 3               /* % at power-up                  */
#define DEFAULT_EVE   0

enum { EDIT_NONE, EDIT_NOISE, EDIT_EVE };
enum { SCR_SETTINGS, SCR_RESULTS, SCR_RATE };

static ui_settings_t cur;             /* confirmed settings             */
static int  noise_pct = DEFAULT_NOISE, eve_pct = DEFAULT_EVE;
static int  edit = EDIT_NONE;         /* which value is being typed     */
static int  edit_val, edit_digits;
static int  screen = SCR_SETTINGS;
static char status[OLED_COLS + 1];
static int  first_poll = 1;
static unsigned int last_sw;
static int   f_held, f_long;          /* long-press tracking for F      */
static uint64_t f_t0;

static const char *mode_txt[3]   = { "RUN", "SLOW", "STEP" };
static const char *action_txt[6] = { "", "Running...", "Reliability...",
                                     "Rate sweep...", "Step", "Reset" };

/* ---------------------------------------------------------------- helpers */

/* percent -> register value round(p x 65536); 100 % saturates at 65535 */
static uint16_t pct_to_q16(int pct)
{
    uint32_t q = ((uint32_t)pct * 65536u + 50u) / 100u;
    return (q > 65535u) ? 65535u : (uint16_t)q;
}

static uint32_t ms_since(uint64_t t0)
{
    return (uint32_t)((now_ticks() - t0) * 1000u / TICKS_PER_SEC);
}

/* 30100 ppm -> "3.01%"  (with_sign = 0 -> "3.01") */
static void fmt_ppm(char *b, size_t n, uint32_t ppm, int with_sign)
{
    snprintf(b, n, "%lu.%02lu%s", (unsigned long)(ppm / 10000),
             (unsigned long)((ppm % 10000) / 100), with_sign ? "%" : "");
}

/* wrong-decision rate without the % sign, 4 characters at most:
 * 6800 ppm -> "0.68", 123000 -> "12.3", 1000000 -> "100", UI_NA -> "n/a" */
static void fmt_rate4(char *b, size_t n, uint32_t ppm)
{
    if (ppm == UI_NA)          snprintf(b, n, "n/a");
    else if (ppm >= 1000000u)  snprintf(b, n, "100");
    else if (ppm >= 100000u)   snprintf(b, n, "%lu.%lu", (unsigned long)(ppm / 10000),
                                        (unsigned long)((ppm % 10000) / 1000));
    else                       snprintf(b, n, "%lu.%02lu", (unsigned long)(ppm / 10000),
                                        (unsigned long)((ppm % 10000) / 100));
}

/* bits saved by the SPRT against another test, whole percent (may be negative) */
static long saved_pct(uint32_t sprt_x10, uint32_t other_x10)
{
    if (other_x10 == 0) return 0;
    long d = (long)other_x10 - (long)sprt_x10;
    return (d * 100 + (d >= 0 ? (long)other_x10 / 2 : -(long)other_x10 / 2)) / (long)other_x10;
}

/* 614 -> "61.4" */
static void fmt_x10(char *b, size_t n, uint32_t v)
{
    snprintf(b, n, "%lu.%lu", (unsigned long)(v / 10), (unsigned long)(v % 10));
}

/* 8200000 -> "8.2M" */
static void fmt_rate(char *b, size_t n, uint64_t r)
{
    if (r >= 1000000000ull)
        snprintf(b, n, "%lu.%luG", (unsigned long)(r / 1000000000ull),
                 (unsigned long)((r % 1000000000ull) / 100000000ull));
    else if (r >= 1000000ull)
        snprintf(b, n, "%lu.%luM", (unsigned long)(r / 1000000ull),
                 (unsigned long)((r % 1000000ull) / 100000ull));
    else if (r >= 1000ull)
        snprintf(b, n, "%lu.%luk", (unsigned long)(r / 1000ull),
                 (unsigned long)((r % 1000ull) / 100ull));
    else
        snprintf(b, n, "%lu", (unsigned long)r);
}

/* ---------------------------------------------------------------- drawing */

static void draw_settings(void)
{
    oled_clear();
    oled_line_inv(0, " QBER ESTIMATOR");

    if (edit == EDIT_NOISE) oled_line_inv(2, "Noise : %d_%%", edit_val);
    else                    oled_line    (2, "Noise : %d%%",  noise_pct);
    if (edit == EDIT_EVE)   oled_line_inv(3, "Eve   : %d_%%", edit_val);
    else                    oled_line    (3, "Eve   : %d%%",  eve_pct);

    oled_line(4, "Proto : BB84");
    oled_line(5, "Mode  : %s", mode_txt[cur.mode % 3]);

    if (edit != EDIT_NONE) oled_line(6, "0-9 E=clr %c=ok", edit == EDIT_NOISE ? 'A' : 'B');
    else                   oled_line(6, "A/B set D=mode");

    oled_line(7, "%s", status);
    oled_refresh();
}

static void set_status(const char *msg)
{
    snprintf(status, sizeof(status), "%s", msg);
}

/* ---------------------------------------------------------------- editing */

static int commit_edit(void)          /* returns 1 if a value changed */
{
    if (edit == EDIT_NONE) return 0;
    int v = (edit_val > 100) ? 100 : edit_val;
    int changed;
    if (edit == EDIT_NOISE) {
        changed = (v != noise_pct);
        noise_pct = v;
        cur.p_noise_q16 = pct_to_q16(v);
    } else {
        changed = (v != eve_pct);
        eve_pct = v;
        cur.f_eve_q16 = pct_to_q16(v);
    }
    edit = EDIT_NONE;
    return changed;
}

static int toggle_edit(int field)     /* A/B: start editing, or confirm */
{
    if (edit == field) return commit_edit();
    int changed = commit_edit();
    edit        = field;
    edit_val    = (field == EDIT_NOISE) ? noise_pct : eve_pct;
    edit_digits = 0;                  /* first digit replaces the value */
    return changed;
}

/* ================================================================ public */

void ui_init(void)
{
    if (kypd_init()  != 0) xil_printf("# ui: keypad GPIO not found\r\n");
    if (btnsw_init() != 0) xil_printf("# ui: switch/button GPIO not found\r\n");
    int o = oled_init();
    if (o != 0) xil_printf("# ui: OLED: no I2C0 in the hardware (I2C 0 on EMIO, port oled_iic)\r\n");
    else        xil_printf("# ui: OLED on I2C address 0x%02X, 400 kHz (SCL JB1, SDA JB2)\r\n", oled_address());

    last_sw         = btnsw_switches();
    cur.p_noise_q16 = pct_to_q16(noise_pct);
    cur.f_eve_q16   = pct_to_q16(eve_pct);
    cur.mode        = (last_sw & 1u) ? 1 : 0;
    cur.action      = 0;

    set_status("F=run hold=sweep");
    screen = SCR_SETTINGS;
    draw_settings();
}

int ui_poll(ui_settings_t *s)
{
    int     changed = first_poll;
    int     redraw  = 0;
    uint8_t action  = 0;
    first_poll = 0;

    /* ---- keypad ---- */
    char k = kypd_get_key();
    if (k) {
        redraw = 1;
        if (k >= '0' && k <= '9') {
            if (edit != EDIT_NONE) {
                if (edit_digits == 0) edit_val = 0;
                if (edit_digits < 3) {
                    edit_val = edit_val * 10 + (k - '0');
                    edit_digits++;
                }
                if (edit_val > 100) edit_val = 100;
            }
        } else switch (k) {
            case 'A': changed |= toggle_edit(EDIT_NOISE); break;
            case 'B': changed |= toggle_edit(EDIT_EVE);   break;
            case 'D': commit_edit(); cur.mode = (cur.mode + 1) % 3; changed = 1; break;
            case 'E': if (edit != EDIT_NONE) { edit_val = 0; edit_digits = 0; } break;
            case 'F': changed |= commit_edit();
                      f_held = 1; f_long = 0; f_t0 = now_ticks();
                      break;
        }
    }

    /* ---- F: short press = run, held LONG_PRESS_MS = rate sweep ---- */
    if (f_held) {
        if (kypd_state() == 'F') {
            if (!f_long && ms_since(f_t0) >= LONG_PRESS_MS) {
                f_long = 1;
                action = 3;
            }
        } else {
            if (!f_long) action = 1;
            f_held = 0;
        }
    }

    /* ---- buttons ---- */
    unsigned int b = btnsw_pressed();
    if      (b & BTN_D) action = 5;
    else if (b & BTN_C) action = 1;
    else if (b & BTN_U) action = 2;
    else if (b & BTN_R) action = 4;

    /* ---- SW0 = mode ---- */
    unsigned int sw = btnsw_switches();
    if ((sw ^ last_sw) & 1u) {
        cur.mode = (sw & 1u) ? 1 : 0;
        changed = 1;
        redraw  = 1;
    }
    last_sw = sw;

    /* ---- an action uses whatever was being typed ---- */
    if (action) {
        changed |= commit_edit();
        set_status(action_txt[action]);
        if (screen == SCR_SETTINGS) redraw = 1;
        else { oled_line(7, "%s", status); oled_refresh(); }
    }

    /* ---- keys and setting changes bring back the settings screen ---- */
    if (redraw) {
        screen = SCR_SETTINGS;
        draw_settings();
    }

    cur.action = action;
    *s = cur;
    return changed || action;
}

void ui_show_status(const char *msg)
{
    set_status(msg);
    oled_line(7, "%s", status);
    oled_refresh();
}

void ui_show_results(const ui_results_t *r)
{
    char a[12], b[12];
    screen = SCR_RESULTS;
    oled_clear();
    oled_line_inv(0, " RESULTS");

    fmt_ppm(a, sizeof a, r->qber_meas_ppm, 1);  oled_line(1, "Meas QBER %s", a);
    fmt_ppm(a, sizeof a, r->qber_true_ppm, 1);  oled_line(2, "True QBER %s", a);

    fmt_x10(a, sizeof a, r->sprt_avg_bits_x10);
    oled_line(3, "SPRT %5s %s", a, r->last_sprt_abort ? "ABRT" : "SAFE");
    fmt_x10(a, sizeof a, r->fix_avg_bits_x10);
    oled_line(4, "Fix  %5s %s", a, r->last_fix_abort ? "ABRT" : "SAFE");

    fmt_rate4(a, sizeof a, r->sprt_wrong_ppm);
    fmt_rate4(b, sizeof b, r->fix_wrong_ppm);
    oled_line(5, "Err%% S%s F%s", a, b);

    oled_line(6, "Bits saved  %3ld%%", saved_pct(r->sprt_avg_bits_x10, r->fix_avg_bits_x10));
    set_status("F=run hold=sweep");
    oled_line(7, "%s", status);
    oled_refresh();
}

void ui_show_rate(const ui_rate_t *r)
{
    char a[12];
    screen = SCR_RATE;
    oled_clear();
    oled_line_inv(0, " FPGA vs ARM");

    fmt_rate(a, sizeof a, r->input_rate); oled_line(1, "Input %7s/s", a);
    fmt_rate(a, sizeof a, r->fpga_rate);  oled_line(2, "FPGA  %7s/s", a);
    fmt_rate(a, sizeof a, r->arm_rate);   oled_line(3, "ARM   %7s/s", a);
    fmt_rate(a, sizeof a, r->arm_dropped); oled_line(4, "ARM drop %s", a);

    int fpga_ok = (uint64_t)r->fpga_rate * 100u >= (uint64_t)r->input_rate * 99u;
    int arm_ok  = r->arm_dropped == 0 &&
                  (uint64_t)r->arm_rate * 100u >= (uint64_t)r->input_rate * 99u;
    oled_line(5, "%s", fpga_ok ? "FPGA keeps up" : "FPGA behind!");
    oled_line(6, "%s", arm_ok  ? "ARM keeps up"  : "ARM falls behind");
    oled_line(7, "%s", status);
    oled_refresh();
}
