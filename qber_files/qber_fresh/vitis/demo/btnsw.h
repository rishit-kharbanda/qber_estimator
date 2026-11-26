/* ============================================================================
 * btnsw.h - ZedBoard switches SW0..SW7 and buttons through AXI GPIO
 * ========================================================================== */
#ifndef BTNSW_H
#define BTNSW_H

#define BTN_C 0x01
#define BTN_D 0x02
#define BTN_L 0x04
#define BTN_R 0x08
#define BTN_U 0x10

int          btnsw_init(void);       /* 0 = OK                                 */
unsigned int btnsw_switches(void);   /* bit n = SWn, 1 = up                    */
unsigned int btnsw_buttons(void);    /* buttons held now                       */
unsigned int btnsw_pressed(void);    /* newly pressed, debounced; every ~10 ms */

#endif
