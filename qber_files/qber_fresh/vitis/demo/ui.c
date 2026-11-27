#include "ui.h"
#include "kypd.h"
#include "oled.h"
#include "btnsw.h"
#include "xil_printf.h"
#include "platform.h"
#include <stdio.h>
#include <string.h>

#define LONG_PRESS_MS 1000
#define DEFAULT_NOISE 3
#define DEFAULT_EVE   0

enum { EDIT_NONE, EDIT_NOISE, EDIT_EVE };
enum { SCR_SETTINGS, SCR_RESULTS, SCR_RATE };

static ui_settings_t cur;
static int  noise_pct = DEFAULT_NOISE, eve_pct = DEFAULT_EVE;
static int  edit = EDIT_NONE;
static int  edit_val, edit_digits;
static int  screen = SCR_SETTINGS;
static char status[OLED_COLS + 1];
static int  first_poll = 1;
static unsigned int last_sw;
static int   f_held, f_long;
static uint64_t f_t0;

static const char *mode_txt[3]   = { "RUN", "SLOW", "STEP" };
static const char *action_txt[6] = { "", "Running...", "Reliability...",
                                     "Rate sweep...", "Step", "Reset" };

static uint16_t pct_to_q16(int pct)
{
    uint32_t q = ((uint32_t)pct * 65536u + 50u) / 100u;
    return (q > 65535u) ? 65535u : (uint16_t)q;
}

static uint32_t ms_since(uint64_t t0)
{
    return (uint32_t)((now_ticks() - t0) * 1000u / TICKS_PER_SEC);
}

static void fmt_ppm(char *b, size_t n, uint32_t ppm, int with_sign)
{
    snprintf(b, n, "%lu.%02lu%s", (unsigned long)(ppm / 10000),
             (unsigned long)((ppm % 10000) / 100), with_sign ? "%" : "");
}

static void fmt_rate4(char *b, size_t n, uint32_t ppm)
{
    if (ppm == UI_NA)          snprintf(b, n, "n/a");
    else if (ppm >= 1000000u)  snprintf(b, n, "100");
    else if (ppm >= 100000u)   snprintf(b, n, "%lu.%lu", (unsigned long)(ppm / 10000),
                                        (unsigned long)((ppm % 10000) / 1000));
    else                       snprintf(b, n, "%lu.%02lu", (unsigned long)(ppm / 10000),
                                        (unsigned long)((ppm % 10000) / 100));
}

static long saved_pct(uint32_t sprt_x10, uint32_t other_x10)
{
    if (other_x10 == 0) return 0;
    long d = (long)other_x10 - (long)sprt_x10;
    return (d * 100 + (d >= 0 ? (long)other_x10 / 2 : -(long)other_x10 / 2)) / (long)other_x10;
}

static void fmt_x10(char *b, size_t n, uint32_t v)
{
    snprintf(b, n, "%lu.%lu", (unsigned long)(v / 10), (unsigned long)(v % 10));
}

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

static int commit_edit(void)
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

static int toggle_edit(int field)
{
    if (edit == field) return commit_edit();
    int changed = commit_edit();
    edit        = field;
    edit_val    = (field == EDIT_NOISE) ? noise_pct : eve_pct;
    edit_digits = 0;
    return changed;
}

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

    unsigned int b = btnsw_pressed();
    if      (b & BTN_D) action = 5;
    else if (b & BTN_C) action = 1;
    else if (b & BTN_U) action = 2;
    else if (b & BTN_R) action = 4;

    unsigned int sw = btnsw_switches();
    if ((sw ^ last_sw) & 1u) {
        cur.mode = (sw & 1u) ? 1 : 0;
        changed = 1;
        redraw  = 1;
    }
    last_sw = sw;

    if (action) {
        changed |= commit_edit();
        set_status(action_txt[action]);
        if (screen == SCR_SETTINGS) redraw = 1;
        else { oled_line(7, "%s", status); oled_refresh(); }
    }

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
