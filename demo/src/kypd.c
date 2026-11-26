/* ============================================================================
 * kypd.c - Pmod KYPD driver
 *
 * Scanning: GPIO bits 0-3 = columns, bits 4-7 = rows. Rows are pulled up,
 * so they read 1 when nothing is pressed. One column at a time is made an
 * output driving 0 (the others stay inputs, so two pressed keys can never
 * short two outputs). A pressed key in that column pulls its row to 0.
 *
 * Debouncing: a reading must stay the same for 3 polls (~30 ms at a 10 ms
 * poll) before it counts; each press is reported once.
 * ========================================================================== */
#include "kypd.h"
#include "ui_hw.h"
#include "xgpio.h"
#include "xstatus.h"
#include "sleep.h"

#define KYPD_CH       1
#define ALL_INPUTS    0xFF       /* direction bit 1 = input */
#define STABLE_POLLS  3

static XGpio kp;
static char  stable_key = 0;     /* debounced key currently held */

/* [row][column] in GPIO bit order. Digilent's Pmod KYPD header (reference
 * manual, J1): pin 1 = COL4, 2 = COL3, 3 = COL2, 4 = COL1, 7 = ROW4, 8 = ROW3,
 * 9 = ROW2, 10 = ROW1. JA1..JA4 are GPIO bits 0-3 and JA7..JA10 bits 4-7, so
 * GPIO column 0 is COL4 (A B C D) and GPIO row 0 is ROW4 (0 F E D): the
 * keypad's layout read from the bottom-right corner. */
static const char keymap[4][4] = {
    { 'D', 'E', 'F', '0' },     /* ROW4 */
    { 'C', '9', '8', '7' },     /* ROW3 */
    { 'B', '6', '5', '4' },     /* ROW2 */
    { 'A', '3', '2', '1' },     /* ROW1 */
};

int kypd_init(void)
{
    if (XGpio_Initialize(&kp, UI_KYPD_ID) != XST_SUCCESS)
        return -1;
    XGpio_DiscreteWrite(&kp, KYPD_CH, 0x00);           /* outputs drive 0     */
    XGpio_SetDataDirection(&kp, KYPD_CH, ALL_INPUTS);  /* start: all inputs   */
    return 0;
}

char kypd_scan(void)
{
    char key = 0;
    for (int col = 0; col < 4 && !key; col++) {
        XGpio_SetDataDirection(&kp, KYPD_CH, ALL_INPUTS & ~(1u << col));
        usleep(5);                                     /* let wires settle    */
        u32 rows = (XGpio_DiscreteRead(&kp, KYPD_CH) >> 4) & 0x0F;
        for (int row = 0; row < 4; row++) {
            if (!(rows & (1u << row))) {
                key = keymap[row][col];
                break;
            }
        }
    }
    XGpio_SetDataDirection(&kp, KYPD_CH, ALL_INPUTS);
    return key;
}

char kypd_get_key(void)
{
    static char last = 0;
    static int  same = 0;

    char now = kypd_scan();
    if (now == last) {
        if (same < STABLE_POLLS) same++;
    } else {
        last = now;
        same = 0;
    }

    if (same == STABLE_POLLS && now != stable_key) {
        stable_key = now;          /* a press (key) or a release (0) */
        return now;
    }
    return 0;
}

char kypd_state(void) { return stable_key; }

char kypd_wait_key(void)
{
    char k;
    while ((k = kypd_get_key()) == 0)
        usleep(10000);
    return k;
}
