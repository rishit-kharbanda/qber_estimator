/* sweeps.h - one complete PL run, and the automatic experiments (Part 4).
 * Every run ends with one CSV line (uart_log.h). ZedBoard only.
 */
#ifndef SWEEPS_H
#define SWEEPS_H

#include <stdint.h>
#include "params.h"
#include "uart_log.h"

typedef struct {
    const char  *mode, *preset;     /* CSV columns 1-2 */
    est_consts_t k;                 /* SPRT and fixed-test constants */
    uint16_t     p_noise, f_eve;    /* register values (params_q16) */
    uint32_t     rate_div;          /* 1 = one photon per clock */
    uint32_t     block_size;        /* must pass params_check_block() */
    uint32_t     num_blocks;        /* 0 = until max_s, then stop */
    int          curtail, test_all;
    int          stream;            /* stream photons to the ARM through the FIFO */
    int          arm_estimate;      /* run the C estimator on the stream (else read only) */
    uint64_t     seed[5];           /* SEED0..SEED4 */
    double       max_s;             /* time limit; the run is stopped after it */
    uint32_t     ctrl_mode;         /* CTRL_MODE_RUN (default), _SLOW or _STEP */
    uint32_t     slow_div;          /* SLOW_DIV for slow mode */
    int        (*idle)(void);       /* optional, called while the run is in progress
                                       (UI polling, step pulses); return 1 to stop the run */
} run_req_t;

/* Optional: called after every run with its results (e.g. to update the OLED). */
extern void (*run_hook)(const run_req_t *q, const log_pl_t *pl, const log_arm_t *arm);

/* Defaults: BB84 constants, BLOCK_SIZE 4096, full rate, no stream, seeds from idx. */
void run_req_default(run_req_t *q, const char *mode, const char *preset, uint32_t idx);

/* Run once on the PL, log one CSV line. Returns 0, or -1 if the configuration
 * is invalid (nothing is run). pl/arm may be NULL. */
int  run_once(const run_req_t *q, log_pl_t *pl, log_arm_t *arm);

/* The experiments (INTERFACES.md section 6, modes g1, rel, rate, long) */
void sweep_graph1(uint32_t blocks_per_point);   /* bits revealed vs error rate, SPRT vs fixed test */
void sweep_reliability(uint32_t blocks);         /* wrong-abort at 3 %, wrong-accept at 11 % */
void sweep_rate(double seconds_per_point, int readonly_pass);   /* Graph 2: FPGA vs ARM processed rate */
void run_long(double seconds);                   /* sustained one photon per clock, no drops */

#endif /* SWEEPS_H */
