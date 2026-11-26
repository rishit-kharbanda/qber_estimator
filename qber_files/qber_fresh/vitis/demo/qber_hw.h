/* qber_hw.h - driver for the QBER estimator registers and the photon FIFO
 * (Part 4). Register map: INTERFACES.md section 5 and qber_regs.h.
 * ZedBoard only (uses Xil_In32/Xil_Out32).
 */
#ifndef QBER_HW_H
#define QBER_HW_H

#include <stdint.h>
#include "xil_io.h"
#include "qber_regs.h"
#include "params.h"

typedef struct {
    uint64_t v[QC_COUNT];        /* indexed by QC_* */
} qhw_counters_t;

/* raw access */
uint32_t qhw_rd(uint32_t off);
void     qhw_wr(uint32_t off, uint32_t v);
uint64_t qhw_rd64(uint32_t off);              /* LO first (latches HI), then HI */

/* identification and register self-test; return 0 on success */
int  qhw_probe(uint32_t *id, uint32_t *version);
int  qhw_reg_selftest(int verbose);

/* CTRL: level bits (mode, curtail_en, test_all, stream_en) are kept in a
 * shadow so that pulses do not disturb them. */
void     qhw_set_levels(uint32_t levels);     /* CTRL_MODE_* | CTRL_CURTAIL_EN | ... */
uint32_t qhw_levels(void);
void     qhw_pulse(uint32_t pulses);          /* CTRL_START | CTRL_STOP | ... */
void     qhw_soft_reset(void);                /* clears the core and its counters */
uint32_t qhw_status(void);
int      qhw_wait_idle(uint32_t timeout_ms);  /* 0 when STATUS.busy = 0 */

/* configuration */
void qhw_write_consts(const est_consts_t *k);
void qhw_write_seeds(const uint64_t seeds[5]);
void qhw_read_counters(qhw_counters_t *c);

/* AXI-Stream FIFO (receive side) */
void     qfifo_reset(void);
static inline uint32_t qfifo_occupancy(void) { return Xil_In32(QBER_FIFO_BASE + FIFO_RDFO); }
static inline uint32_t qfifo_packet_words(void) { return (Xil_In32(QBER_FIFO_BASE + FIFO_RLR) & FIFO_RLR_MASK) >> 2; }
static inline uint32_t qfifo_word(void) { return Xil_In32(QBER_FIFO_BASE + FIFO_RDFD); }

/* Read whole packets into buf (up to max words). Returns words read. */
uint32_t qfifo_read(uint32_t *buf, uint32_t max);

#endif /* QBER_HW_H */
