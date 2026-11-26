/* suite.c - the measurement suite: the ARM program for the report's data (Part 4).
 * Needs the full bitstream (vivado/build.tcl -full). Output: CSV over the
 * USB-UART at 115200 baud (uart_log.h); capture it with host/capture.py or a
 * terminal with logging, then plot with host/plot.py.
 *
 * Runs the measurement suite once, in this order:
 *   1. Graph 1     error levels 0-25 %, SPRT vs fixed test               ~15 s
 *   2. reliability 100,000 blocks at QBER 3 % and 11 %                             ~17 s
 *   3. Graph 2     input rates 1.6-100 M photons/s, FPGA vs ARM (read+estimate,
 *                  then read only)                                                 ~40 s
 *   4. sustained   30 s at one photon per clock: processed = in, dropped = 0       ~30 s
 * and ends with "# sweep finished".
 *
 * No UI: it runs on its own (the interactive demo program is sw/main/main.c).
 * Change the sizes below for quicker runs.
 *
 * Vitis sources: suite/suite.c, sweeps.c, uart_log.c, qber_hw.c, params.c,
 * link_emu.c, sw_estimator.c (+ every .h in sw/); m library; -O2.
 */
#include <stdio.h>
#include "platform.h"
#include "qber_hw.h"
#include "uart_log.h"
#include "sweeps.h"

#ifndef G1_BLOCKS_PER_POINT
#define G1_BLOCKS_PER_POINT  10000u    /* Graph 1: ~0.8 s per point at full rate */
#endif
#ifndef REL_BLOCKS
#define REL_BLOCKS           100000u   /* reliability: 1 % measured to about +-0.06 % */
#endif
#ifndef RATE_SECONDS
#define RATE_SECONDS         1.5       /* Graph 2: per point and pass */
#endif
#ifndef LONG_SECONDS
#define LONG_SECONDS         30.0      /* sustained-rate proof */
#endif

int main(void)
{
    printf("\r\n# QBER estimator measurement suite (%s), built %s %s\r\n", PLATFORM_NAME, __DATE__, __TIME__);

    uint32_t id, ver;
    if (qhw_probe(&id, &ver) != 0 || !(ver & 0x80000000u)) {
        printf("# FAIL: ID %08lx VERSION %08lx: the full bitstream (build.tcl -full) is not loaded\r\n",
               (unsigned long)id, (unsigned long)ver);
        printf("# sweep finished\r\n");
        return 1;
    }
    est_consts_t k;
    params_compute(&PRESET_BB84, &k);
    printf("# ID %08lx, VERSION %lu.%lu.%lu (full core); BB84 preset p0=3%% p1=11%% alpha=beta=1%%:"
           " INC_ERR=%d INC_OK=%d THR=+-%d NMAX=%u FIX_N=%u FIX_C=%u\r\n",
           (unsigned long)id, (unsigned long)((ver >> 16) & 0xFF), (unsigned long)((ver >> 8) & 0xFF),
           (unsigned long)(ver & 0xFF), k.inc_err, k.inc_ok, k.thr_a, k.nmax, k.fix_n, k.fix_c);

    uint64_t t0 = now_ticks();
    log_header();
    sweep_graph1(G1_BLOCKS_PER_POINT);
    sweep_reliability(REL_BLOCKS);
    sweep_rate(RATE_SECONDS, 1);
    run_long(LONG_SECONDS);

    printf("# total %.0f s\r\n", ticks_to_s(now_ticks() - t0));
    printf("# sweep finished\r\n");
    return 0;
}
