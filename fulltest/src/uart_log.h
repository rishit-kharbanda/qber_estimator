#ifndef UART_LOG_H
#define UART_LOG_H

#include <stdint.h>
#include "qber_regs.h"
#include "sw_estimator.h"

#define LOG_MODE_SINGLE "single"
#define LOG_MODE_G1     "g1"
#define LOG_MODE_REL    "rel"
#define LOG_MODE_RATE   "rate"
#define LOG_MODE_LONG   "long"

typedef struct {
    const char *mode;
    const char *preset;
    uint16_t    p_noise, f_eve;
    uint32_t    rate_div, block_size;
} log_run_t;

typedef struct {
    uint64_t v[QC_COUNT];
    uint32_t lat_max;
} log_pl_t;

typedef struct {
    uint64_t photons, blocks, sum_n_sprt, abort_sprt;
    int      match;
} log_arm_t;

void log_header(void);
void log_row(const log_run_t *r, const log_pl_t *pl, const log_arm_t *arm);
void log_comment(const char *text);

void log_arm_from_estimator(log_arm_t *a, const swe_counts_t *c, const log_pl_t *pl, int compare);

#endif
