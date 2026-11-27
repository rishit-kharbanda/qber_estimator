#include <stdio.h>
#include "qber_hw.h"
#include "platform.h"

static uint32_t ctrl_levels;
static uint32_t pkt_left;

uint32_t qhw_rd(uint32_t off)           { return Xil_In32(QBER_REGS_BASE + off); }
void     qhw_wr(uint32_t off, uint32_t v) { Xil_Out32(QBER_REGS_BASE + off, v); }

uint64_t qhw_rd64(uint32_t off)
{
    uint32_t lo = qhw_rd(off);
    uint32_t hi = qhw_rd(off + 4u);
    return ((uint64_t)hi << 32) | lo;
}

int qhw_probe(uint32_t *id, uint32_t *version)
{
    uint32_t i = qhw_rd(QR_ID);
    if (id) *id = i;
    if (version) *version = qhw_rd(QR_VERSION);
    return i == QBER_ID_VALUE ? 0 : -1;
}

int qhw_reg_selftest(int verbose)
{
    static const uint32_t pats[] = { 0xFFFFFFFFu, 0x00000000u, 0xA5A55A5Au, 0x5A5AA5A5u };
    int errors = 0;

    for (int b = 0; b < 32; b++) {
        qhw_wr(QR_SCRATCH, 1u << b);
        if (qhw_rd(QR_SCRATCH) != (1u << b)) errors++;
    }

    for (uint32_t off = QR_P_NOISE; off <= QR_CFG_LAST; off += 4u) {
        uint32_t orig = qhw_rd(off);
        for (unsigned p = 0; p < sizeof(pats) / sizeof(pats[0]); p++) {
            qhw_wr(off, pats[p]);
            uint32_t got = qhw_rd(off);
            if (got != pats[p]) {
                errors++;
                if (verbose) printf("  reg 0x%03lx: wrote %08lx read %08lx\r\n",
                                    (unsigned long)off, (unsigned long)pats[p], (unsigned long)got);
            }
        }
        qhw_wr(off, orig);
    }

    uint32_t st = qhw_rd(QR_STATUS);
    qhw_wr(QR_STATUS, 0xFFFFFFFFu);
    if (qhw_rd(QR_STATUS) != st) errors++;
    return errors;
}

void qhw_set_levels(uint32_t levels)
{
    ctrl_levels = levels & ~CTRL_PULSES;
    qhw_wr(QR_CTRL, ctrl_levels);
}

uint32_t qhw_levels(void) { return ctrl_levels; }

void qhw_pulse(uint32_t pulses)
{
    qhw_wr(QR_CTRL, ctrl_levels | (pulses & CTRL_PULSES));
}

void qhw_soft_reset(void) { qhw_pulse(CTRL_SOFT_RST); }

uint32_t qhw_status(void) { return qhw_rd(QR_STATUS); }

int qhw_wait_idle(uint32_t timeout_ms)
{
    uint64_t t_end = now_ticks() + (uint64_t)timeout_ms * TICKS_PER_SEC / 1000u;
    while (qhw_status() & ST_BUSY)
        if (now_ticks() > t_end) return -1;
    return 0;
}

void qhw_write_consts(const est_consts_t *k)
{

    qhw_wr(QR_SPRT_INC_ERR, (uint32_t)(int32_t)k->inc_err);
    qhw_wr(QR_SPRT_INC_OK,  (uint32_t)(int32_t)k->inc_ok);
    qhw_wr(QR_SPRT_THR_A,   (uint32_t)(int32_t)k->thr_a);
    qhw_wr(QR_SPRT_THR_B,   (uint32_t)(int32_t)k->thr_b);
    qhw_wr(QR_SPRT_NMAX,    k->nmax);
    qhw_wr(QR_FIX_N,        k->fix_n);
    qhw_wr(QR_FIX_C,        k->fix_c);
}

void qhw_write_seeds(const uint64_t seeds[5])
{
    for (unsigned n = 0; n < 5; n++) {
        uint64_t s = seeds[n];
        qhw_wr(QR_SEED_LO(n), (uint32_t)s);
        qhw_wr(QR_SEED_HI(n), (uint32_t)(s >> 32));
    }
}

void qhw_read_counters(qhw_counters_t *c)
{
    for (unsigned k = 0; k < QC_COUNT; k++)
        c->v[k] = QC_IS_COUNTER(k) ? qhw_rd64(QR_CNT(k)) : 0;
}

void qfifo_reset(void)
{
    Xil_Out32(QBER_FIFO_BASE + FIFO_RDFR, FIFO_RESET_KEY);
    Xil_Out32(QBER_FIFO_BASE + FIFO_ISR, 0xFFFFFFFFu);
    pkt_left = 0;
}

uint32_t qfifo_read(uint32_t *buf, uint32_t max)
{
    uint32_t n = 0;
    while (n < max) {
        if (pkt_left == 0) {
            if (qfifo_occupancy() == 0) break;
            pkt_left = qfifo_packet_words();
            if (pkt_left == 0) break;
        }
        uint32_t take = pkt_left < (max - n) ? pkt_left : (max - n);
        for (uint32_t i = 0; i < take; i++)
            buf[n++] = qfifo_word();
        pkt_left -= take;
    }
    return n;
}
