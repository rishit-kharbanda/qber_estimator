/* ============================================================================
 * kypd.h - Pmod KYPD (4x4 keypad) on JA through AXI GPIO
 *
 *      1 2 3 A
 *      4 5 6 B
 *      7 8 9 C
 *      0 F E D
 * ========================================================================== */
#ifndef KYPD_H
#define KYPD_H

int  kypd_init(void);      /* 0 = OK, -1 = GPIO not found                       */
char kypd_scan(void);      /* raw key held right now, 0 = none (not debounced)  */
char kypd_get_key(void);   /* debounced: a key ONCE per press, else 0.
                              Call every ~10 ms.                                */
char kypd_state(void);     /* debounced key currently held, 0 = none
                              (updated by kypd_get_key)                         */
char kypd_wait_key(void);  /* blocks until a key is pressed                     */

#endif
