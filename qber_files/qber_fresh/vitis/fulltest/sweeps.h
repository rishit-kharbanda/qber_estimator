#ifndef SWEEPS_H
#define SWEEPS_H

#include <stdint.h>
#include "params.h"
#include "uart_log.h"

typedef struct {
    const char  *mode, *preset;
    est_consts_t k;
    uint16_t     p_noise, f_eve;
    uint32_t     rate_div;
    uint32_t     block_size;
    uint32_t     num_blocks;
    int          curtail, test_all;
    int          stream;
    int          arm_estimate;
    uint64_t     seed[5];
    double       max_s;
    uint32_t     ctrl_mode;
    uint32_t     slow_div;
    int        (*idle)(void);

} run_req_t;

extern void (*run_hook)(const run_req_t *q, const log_pl_t *pl, const log_arm_t *arm);

void run_req_default(run_req_t *q, const char *mode, const char *preset, uint32_t idx);

int  run_once(const run_req_t *q, log_pl_t *pl, log_arm_t *arm);

void sweep_graph1(uint32_t blocks_per_point);
void sweep_reliability(uint32_t blocks);
void sweep_rate(double seconds_per_point, int readonly_pass);
void run_long(double seconds);

#endif
