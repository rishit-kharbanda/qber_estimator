#include <stdio.h>
#include "platform.h"
#include "qber_hw.h"
#include "uart_log.h"
#include "sweeps.h"

#ifndef G1_BLOCKS_PER_POINT
#define G1_BLOCKS_PER_POINT  10000u
#endif
#ifndef REL_BLOCKS
#define REL_BLOCKS           100000u
#endif
#ifndef RATE_SECONDS
#define RATE_SECONDS         1.5
#endif
#ifndef LONG_SECONDS
#define LONG_SECONDS         30.0
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
