/* qber_regs.h - register map of the QBER estimator (INTERFACES.md section 5)
 * and of the AXI-Stream FIFO (Xilinx axi_fifo_mm_s, PG080). Part 4.
 *
 * Entries marked [proposed] are not in INTERFACES.md v0.2 yet; they read 0
 * on a design that lacks them.
 */
#ifndef QBER_REGS_H
#define QBER_REGS_H

/* Base addresses: fixed by vivado/build.tcl (settings.tcl). Override with -D
 * if the block design changes. */
#ifndef QBER_REGS_BASE
#define QBER_REGS_BASE 0x43C00000u
#endif
#ifndef QBER_FIFO_BASE
#define QBER_FIFO_BASE 0x43C10000u
#endif

/* ---------------- configuration (RW) ---------------- */
#define QR_CTRL          0x000u
#define QR_STATUS        0x004u   /* RO */
#define QR_P_NOISE       0x008u
#define QR_F_EVE         0x00Cu
#define QR_RATE_DIV      0x010u
#define QR_SLOW_DIV      0x014u
#define QR_BLOCK_SIZE    0x018u
#define QR_NUM_BLOCKS    0x01Cu
#define QR_SPRT_INC_ERR  0x020u
#define QR_SPRT_INC_OK   0x024u
#define QR_SPRT_THR_A    0x028u
#define QR_SPRT_THR_B    0x02Cu
#define QR_SPRT_NMAX     0x030u
#define QR_FIX_N         0x034u
#define QR_FIX_C         0x038u
#define QR_STREAM_PKT    0x03Cu
#define QR_SEED_LO(n)    (0x040u + 8u * (n))   /* n = 0..4 */
#define QR_SEED_HI(n)    (0x044u + 8u * (n))
#define QR_CFG_LAST      0x064u

/* CTRL bits */
#define CTRL_START       (1u << 0)   /* pulse */
#define CTRL_SOFT_RST    (1u << 1)   /* pulse */
#define CTRL_MODE_SHIFT  2
#define CTRL_MODE_MASK   (3u << 2)
#define CTRL_MODE_RUN    (0u << 2)
#define CTRL_MODE_SLOW   (1u << 2)
#define CTRL_MODE_STEP   (2u << 2)
#define CTRL_MODE_PAUSE  (3u << 2)   /* no ce [proposed, Part 1] */
#define CTRL_STEP        (1u << 4)   /* pulse */
#define CTRL_CURTAIL_EN  (1u << 5)
#define CTRL_TEST_ALL    (1u << 6)
#define CTRL_STREAM_EN   (1u << 7)
#define CTRL_STOP        (1u << 8)   /* pulse [proposed] */
#define CTRL_PULSES      (CTRL_START | CTRL_SOFT_RST | CTRL_STEP | CTRL_STOP)

/* STATUS bits */
#define ST_BUSY             (1u << 0)
#define ST_DONE             (1u << 1)
#define ST_LAST_SPRT_ABORT  (1u << 2)
#define ST_LAST_FIX_ABORT   (1u << 3)
#define ST_LAST_TRUNC       (1u << 4)
#define ST_PL_DROP          (1u << 5)
#define ST_STREAM_DROP      (1u << 6)
#define ST_PE_ERR           (1u << 7)   /* [proposed, Part 1] block reached D bits undecided */

/* ---------------- 64-bit counters (RO): read LO first, it latches HI ---------------- */
#define QR_CNT(k)            (0x100u + 8u * (k))
#define QC_CYCLES               0
#define QC_PHOTONS_IN           1
#define QC_PL_DROPPED           2
#define QC_SIFTED               3
#define QC_SIFTED_ERRS          4
#define QC_BLOCKS_DONE          5
#define QC_SUM_N_SPRT           6
#define QC_SUM_N_FIX            7
#define QC_ABORT_SPRT           8
#define QC_ABORT_FIX            9
#define QC_TRUNC_SPRT          10
#define QC_KEY_SPRT            11
#define QC_KEY_FIX             12
#define QC_STREAM_WORDS_SENT   13
#define QC_STREAM_WORDS_DROPPED 14
#define QC_PHOTONS_PROC        15   /* [proposed, Parts 2 and 4] */
#define QC_PHOTONS_PROCESSED   QC_PHOTONS_PROC
/* k = 16, 17 (0x180-0x18C) hold the live and latency words below */
#define QC_DISCLOSED           18   /* 0x190 [proposed, Part 1] bits revealed on the public channel */
#define QC_KEY_OUT             19   /* 0x198 [proposed, Part 1] key bits released by key_out */
#define QC_COUNT               20
#define QC_IS_COUNTER(k)       ((k) != 16u && (k) != 17u)

/* ---------------- live values (RO) ---------------- */
#define QR_LIVE_SCORE    0x180u   /* s16, sign-extended */
#define QR_LIVE_N        0x184u   /* [15:0] n_sprt, [31:16] n_fix */
#define QR_LAT_LAST      0x188u   /* [proposed, Part 2] clock cycles blk_start -> blk_done, last block */
#define QR_LAT_MAX       0x18Cu   /* [proposed, Part 2] largest since start */

/* ---------------- identification [proposed] ---------------- */
#define QR_ID            0x1F0u
#define QR_VERSION       0x1F4u
#define QR_SCRATCH       0x1F8u
#define QBER_ID_VALUE    0x51424552u   /* "QBER" */

/* ---------------- axi_fifo_mm_s (AXI4-Lite data interface) ---------------- */
#define FIFO_ISR   0x00u
#define FIFO_IER   0x04u
#define FIFO_RDFR  0x18u   /* write 0xA5 to reset the receive side */
#define FIFO_RDFO  0x1Cu   /* receive occupancy (words) */
#define FIFO_RDFD  0x20u   /* receive data (read pops one word) */
#define FIFO_RLR   0x24u   /* receive length in bytes; read before the data */
#define FIFO_SRR   0x28u   /* write 0xA5 to reset the whole core */
#define FIFO_RESET_KEY 0xA5u
#define FIFO_RLR_MASK  0x007FFFFFu

#endif /* QBER_REGS_H */
