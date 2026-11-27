#ifndef UI_H
#define UI_H

#include <stdint.h>

typedef struct {
    uint16_t p_noise_q16;
    uint16_t f_eve_q16;
    uint8_t  mode;
    uint8_t  action;
} ui_settings_t;

#define UI_NA 0xFFFFFFFFu

typedef struct {
    uint32_t qber_meas_ppm, qber_true_ppm;
    uint32_t sprt_avg_bits_x10;
    uint32_t fix_avg_bits_x10;
    uint32_t sprt_wrong_ppm, fix_wrong_ppm;
    uint8_t  last_sprt_abort, last_fix_abort;
} ui_results_t;

typedef struct {
    uint32_t input_rate, fpga_rate, arm_rate;
    uint64_t arm_dropped;
} ui_rate_t;

void ui_init(void);
int  ui_poll(ui_settings_t *s);
void ui_show_status(const char *msg);
void ui_show_results(const ui_results_t *r);
void ui_show_rate(const ui_rate_t *r);

#endif
