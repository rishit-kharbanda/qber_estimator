#include "btnsw.h"
#include "ui_hw.h"
#include "xgpio.h"
#include "xstatus.h"

#define STABLE_POLLS 3

static XGpio gs;

int btnsw_init(void)
{
    if (XGpio_Initialize(&gs, UI_BTNSW_ID) != XST_SUCCESS)
        return -1;
    XGpio_SetDataDirection(&gs, 1, 0xFF);
    XGpio_SetDataDirection(&gs, 2, 0x1F);
    return 0;
}

unsigned int btnsw_switches(void) { return XGpio_DiscreteRead(&gs, 1) & 0xFF; }
unsigned int btnsw_buttons(void)  { return XGpio_DiscreteRead(&gs, 2) & 0x1F; }

unsigned int btnsw_pressed(void)
{
    static unsigned int last = 0, stable = 0;
    static int same = 0;

    unsigned int now = btnsw_buttons();
    if (now == last) {
        if (same < STABLE_POLLS) same++;
    } else {
        last = now;
        same = 0;
    }

    unsigned int newly = 0;
    if (same == STABLE_POLLS && now != stable) {
        newly  = now & ~stable;
        stable = now;
    }
    return newly;
}
