/* uart_log.h - results to the laptop as CSV over the USB-UART (Part 4).
 * Format: part4/INTERFACES_change_proposal.md section 6 (INTERFACES.md section 6).
 * One header line starting with '#', then one line per run. Lines starting
 * with '#' are comments; host/plot.py reads only data lines.
 */
#ifndef UART_LOG_H
#define UART_LOG_H

#include <stdint.h>
#include "qber_regs.h"
#include "sw_estimator.h"

/* Run modes (first CSV column) */
#define LOG_MODE_SINGLE "single"   /* one run (UI or demo) */
#define LOG_MODE_G1     "g1"       /* Graph 1: error-level sweep, FPGA only */
#define LOG_MODE_REL    "rel"      /* reliability runs, FPGA only */
#define LOG_MODE_RATE   "rate"     /* Graph 2: input-rate sweep, FPGA + ARM */
#define LOG_MODE_LONG   "long"     /* sustained-rate proof: long run at one photon per clock */

/* What the PL was asked to do in one run */
typedef struct {
    const char *mode;              /* LOG_MODE_* */
    const char *preset;            /* "bb84", ... */
    uint16_t    p_noise, f_eve;    /* register values */
    uint32_t    rate_div, block_size;
} log_run_t;

/* Counters read back from the PL, indexed like qhw_counters_t (QC_*), plus LAT_MAX */
typedef struct {
    uint64_t v[QC_COUNT];
    uint32_t lat_max;
} log_pl_t;

/* ARM side of a run (zeros and arm_match = -1 when the ARM did not take part) */
typedef struct {
    uint64_t photons, blocks, sum_n_sprt, abort_sprt;
    int      match;                /* 1: ARM decisions = PL decisions, 0: differ, -1: not run */
} log_arm_t;

void log_header(void);
void log_row(const log_run_t *r, const log_pl_t *pl, const log_arm_t *arm);
void log_comment(const char *text);

/* Fill an ARM record from the estimator, comparing with the PL counters. */
void log_arm_from_estimator(log_arm_t *a, const swe_counts_t *c, const log_pl_t *pl, int compare);

#endif /* UART_LOG_H */
