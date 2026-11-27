#ifndef QBER_HW_H
#define QBER_HW_H

#include <stdint.h>
#include "xil_io.h"
#include "qber_regs.h"
#include "params.h"

typedef struct {
    uint64_t v[QC_COUNT];
} qhw_counters_t;

uint32_t qhw_rd(uint32_t off);
void     qhw_wr(uint32_t off, uint32_t v);
uint64_t qhw_rd64(uint32_t off);

int  qhw_probe(uint32_t *id, uint32_t *version);
int  qhw_reg_selftest(int verbose);

void     qhw_set_levels(uint32_t levels);
uint32_t qhw_levels(void);
void     qhw_pulse(uint32_t pulses);
void     qhw_soft_reset(void);
uint32_t qhw_status(void);
int      qhw_wait_idle(uint32_t timeout_ms);

void qhw_write_consts(const est_consts_t *k);
void qhw_write_seeds(const uint64_t seeds[5]);
void qhw_read_counters(qhw_counters_t *c);

void     qfifo_reset(void);
static inline uint32_t qfifo_occupancy(void) { return Xil_In32(QBER_FIFO_BASE + FIFO_RDFO); }
static inline uint32_t qfifo_packet_words(void) { return (Xil_In32(QBER_FIFO_BASE + FIFO_RLR) & FIFO_RLR_MASK) >> 2; }
static inline uint32_t qfifo_word(void) { return Xil_In32(QBER_FIFO_BASE + FIFO_RDFD); }

uint32_t qfifo_read(uint32_t *buf, uint32_t max);

#endif
