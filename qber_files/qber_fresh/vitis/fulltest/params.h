#ifndef PARAMS_H
#define PARAMS_H

#include <stdint.h>

typedef struct {
    double p0;
    double p1;
    double alpha;
    double beta;
} test_spec_t;

typedef struct {
    int16_t  inc_err;
    int16_t  inc_ok;
    int16_t  thr_a;
    int16_t  thr_b;
    uint16_t nmax;
    uint16_t fix_n;
    uint16_t fix_c;
} est_consts_t;

#define PARAMS_SCALE 256

int params_compute(const test_spec_t *s, est_consts_t *k);

int params_fixed_design(double p0, double p1, double alpha, double beta,
                        int n_limit, int *n_out, int *c_out);

int params_check_block(uint32_t block_size, uint32_t nmax, uint32_t fix_n);

uint32_t params_min_block(uint32_t nmax, uint32_t fix_n);

uint16_t params_q16(double p);

extern const test_spec_t PRESET_BB84;

#endif
