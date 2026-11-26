/* platform.h - the few things that differ between the ZedBoard (bare-metal,
 * Xilinx standalone BSP) and a laptop build (-DHOST) used for unit tests and
 * the estimator benchmark. Part 4.
 *
 * On the board the timer is the Cortex-A9 global timer, read directly from
 * its registers, so the code does not depend on xtime_l.h (missing from the
 * Vitis 2025.2 standalone BSP).
 */
#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>

#if defined(HOST) && defined(MOCK_TIME)
/* laptop run of the board programs against sw/host/mock_hw.c: virtual time */
#define TICKS_PER_SEC 1000000000ull
uint64_t mock_now_ticks(void);
static inline uint64_t now_ticks(void) { return mock_now_ticks(); }
#define PLATFORM_NAME "host-mock"

#elif defined(HOST)
#include <time.h>

#define TICKS_PER_SEC 1000000000ull
static inline uint64_t now_ticks(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}
#define PLATFORM_NAME "host"

#else /* ZedBoard */
#include "xil_io.h"
#include "xparameters.h"

/* Global timer: runs at half the CPU clock (CPU 666.67 MHz on the ZedBoard). */
#if defined(XPAR_CPU_CORTEXA9_0_CPU_CLK_FREQ_HZ)
#define TICKS_PER_SEC ((uint64_t)XPAR_CPU_CORTEXA9_0_CPU_CLK_FREQ_HZ / 2u)
#elif defined(XPAR_CPU_CORE_CLOCK_FREQ_HZ)
#define TICKS_PER_SEC ((uint64_t)XPAR_CPU_CORE_CLOCK_FREQ_HZ / 2u)
#else
#define TICKS_PER_SEC 333333343ull
#endif

#define A9_GTIMER_LO   0xF8F00200u
#define A9_GTIMER_HI   0xF8F00204u
#define A9_GTIMER_CTRL 0xF8F00208u

static inline uint64_t now_ticks(void)
{
    if ((Xil_In32(A9_GTIMER_CTRL) & 1u) == 0u)           /* start it if the BSP has not */
        Xil_Out32(A9_GTIMER_CTRL, Xil_In32(A9_GTIMER_CTRL) | 1u);
    uint32_t hi, lo;
    do {                                                 /* consistent 64-bit read */
        hi = Xil_In32(A9_GTIMER_HI);
        lo = Xil_In32(A9_GTIMER_LO);
    } while (Xil_In32(A9_GTIMER_HI) != hi);
    return ((uint64_t)hi << 32) | lo;
}
#define MMIO_RD(addr)    Xil_In32((UINTPTR)(addr))
#define MMIO_WR(addr, v) Xil_Out32((UINTPTR)(addr), (u32)(v))
#define PLATFORM_NAME "zedboard-a9"
#endif

static inline double ticks_to_s(uint64_t t) { return (double)t / (double)TICKS_PER_SEC; }

#endif /* PLATFORM_H */
