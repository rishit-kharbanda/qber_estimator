#include "kypd.h"
#include "ui_hw.h"
#include "xgpio.h"
#include "xstatus.h"
#include "sleep.h"

#define KYPD_CH       1
#define ALL_INPUTS    0xFF
#define STABLE_POLLS  3

static XGpio kp;
static char  stable_key = 0;

static const char keymap[4][4] = {
    { 'D', 'E', 'F', '0' },
    { 'C', '9', '8', '7' },
    { 'B', '6', '5', '4' },
    { 'A', '3', '2', '1' },
};

int kypd_init(void)
{
    if (XGpio_Initialize(&kp, UI_KYPD_ID) != XST_SUCCESS)
        return -1;
    XGpio_DiscreteWrite(&kp, KYPD_CH, 0x00);
    XGpio_SetDataDirection(&kp, KYPD_CH, ALL_INPUTS);
    return 0;
}

char kypd_scan(void)
{
    char key = 0;
    for (int col = 0; col < 4 && !key; col++) {
        XGpio_SetDataDirection(&kp, KYPD_CH, ALL_INPUTS & ~(1u << col));
        usleep(5);
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
        stable_key = now;
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
