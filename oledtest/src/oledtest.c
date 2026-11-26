/* oledtest.c - find out why a 4-pin I2C OLED on JB stays dark (Parts 3 and 4).
 *
 * 1. Scans JB1 (SCL) / JB2 (SDA) at 100 kHz and 400 kHz for I2C devices.
 * 2. Then repeats three display set-ups, 8 s each, and prints which one is
 *    running; watch the screen and note which one shows text:
 *      A  SSD1306 128x64  (0.96-inch, the usual module; what the demo uses)
 *      B  SSD1306 128x32  (0.91-inch, long thin module)
 *      C  SH1106  128x64  (1.3-inch module)
 *    Each set-up lights the whole screen for 3 s, then shows its letter and text.
 * 3. Counts I2C transfers the display did not acknowledge (should stay 0).
 *
 * Vitis sources: oledtest/oledtest.c, ui/font8x8.h, ui/ui_hw.h (nothing else).
 * Output: UART 115200 baud (PuTTY or the live-plot page).
 */
#include <stdio.h>
#include <string.h>
#include "xiicps.h"
#include "xstatus.h"
#include "sleep.h"
#include "ui_hw.h"
#include "font8x8.h"

static XIicPs iic;
static unsigned addr = 0x3C;
static unsigned tx_ok, tx_err;

static int i2c_init(unsigned hz)
{
    XIicPs_Config *cfg = XIicPs_LookupConfig(UI_OLED_IIC_ID);
    if (cfg == NULL || XIicPs_CfgInitialize(&iic, cfg, cfg->BaseAddress) != XST_SUCCESS) return -1;
    XIicPs_SetSClk(&iic, hz);
    return 0;
}

static int send(unsigned a, const unsigned char *b, int n)
{
    unsigned char buf[132];
    memcpy(buf, b, n);
    int st = XIicPs_MasterSendPolled(&iic, buf, n, a);
    while (XIicPs_BusIsBusy(&iic))
        ;
    if (st == XST_SUCCESS) tx_ok++; else tx_err++;
    return st;
}

static void scan(unsigned hz)
{
    if (i2c_init(hz) != 0) { printf("# I2C0 not found in the hardware\r\n"); return; }
    int n = 0;
    printf("# I2C scan at %u kHz:", hz / 1000);
    for (unsigned a = 0x08; a <= 0x77; a++) {
        unsigned char b[1] = { 0x00 };
        if (send(a, b, 1) == XST_SUCCESS) { printf(" 0x%02X", a); n++; addr = (a == 0x3C || a == 0x3D) ? a : addr; }
        usleep(200);
    }
    printf(n ? "\r\n" : " nothing answered\r\n");
}

static void cmds(const unsigned char *c, int n)          /* control byte 0x00 + commands */
{
    unsigned char b[40];
    b[0] = 0x00;
    memcpy(&b[1], c, n);
    send(addr, b, n + 1);
}

/* write one page (8 pixel rows) of 128 columns; sh1106 = column offset 2 */
static void page(int p, const unsigned char *px, int sh1106)
{
    unsigned char pos[3] = { (unsigned char)(0xB0 + p), (unsigned char)(sh1106 ? 0x02 : 0x00), 0x10 };
    cmds(pos, 3);
    unsigned char b[17];
    b[0] = 0x40;
    for (int i = 0; i < 128; i += 16) {
        memcpy(&b[1], &px[i], 16);
        send(addr, b, 17);
    }
}

static void text_row(unsigned char *px, const char *t)
{
    memset(px, 0, 128);
    for (int c = 0; c < 16 && t[c]; c++) {
        unsigned char ch = (unsigned char)t[c];
        if (ch < 32 || ch > 126) ch = '?';
        memcpy(&px[c * 8], font8x8[ch - 32], 8);
    }
}

static void setup(char v)
{
    /* page addressing (0x20 0x02) for all three, so the same drawing code works */
    static const unsigned char a64[] = {
        0xAE, 0xD5, 0x80, 0xA8, 0x3F, 0xD3, 0x00, 0x40, 0x8D, 0x14, 0x20, 0x02,
        0xA1, 0xC8, 0xDA, 0x12, 0x81, 0xCF, 0xD9, 0xF1, 0xDB, 0x40, 0xA4, 0xA6, 0xAF };
    static const unsigned char b32[] = {
        0xAE, 0xD5, 0x80, 0xA8, 0x1F, 0xD3, 0x00, 0x40, 0x8D, 0x14, 0x20, 0x02,
        0xA1, 0xC8, 0xDA, 0x02, 0x81, 0x8F, 0xD9, 0xF1, 0xDB, 0x40, 0xA4, 0xA6, 0xAF };
    static const unsigned char c_sh[] = {
        0xAE, 0xD5, 0x80, 0xA8, 0x3F, 0xD3, 0x00, 0x40, 0xAD, 0x8B,
        0xA1, 0xC8, 0xDA, 0x12, 0x81, 0x80, 0xD9, 0x22, 0xDB, 0x35, 0xA4, 0xA6, 0xAF };
    if (v == 'A') cmds(a64, sizeof a64);
    if (v == 'B') cmds(b32, sizeof b32);
    if (v == 'C') cmds(c_sh, sizeof c_sh);
}

int main(void)
{
    printf("\r\n# OLED test v2: SCL JB1, SDA JB2\r\n");
    scan(100000);
    scan(400000);
    printf("# using address 0x%02X at 100 kHz\r\n", addr);
    i2c_init(100000);
    usleep(200000);

    static const char *name[3] = { "A: SSD1306 128x64 (0.96in)", "B: SSD1306 128x32 (0.91in)",
                                   "C: SH1106 128x64 (1.3in)" };
    unsigned char px[128];
    for (unsigned round = 1;; round++) {
        for (int k = 0; k < 3; k++) {
            char v = (char)('A' + k);
            int pages = (v == 'B') ? 4 : 8, sh = (v == 'C');
            tx_ok = tx_err = 0;
            setup(v);
            memset(px, 0xFF, sizeof px);                  /* whole screen lit */
            for (int p = 0; p < pages; p++) page(p, px, sh);
            printf("# round %u, set-up %s: screen lit", round, name[k]);
            usleep(3000000);
            char line[17];
            for (int p = 0; p < pages; p++) {
                if (p == 0)      snprintf(line, sizeof line, " SET-UP %c  OK", v);
                else if (p == 1) snprintf(line, sizeof line, "addr 0x%02X", addr);
                else             snprintf(line, sizeof line, "line %d %c%c%c%c%c%c", p, v, v, v, v, v, v);
                text_row(px, line);
                page(p, px, sh);
            }
            printf(", text shown; I2C ok %u, not acknowledged %u\r\n", tx_ok, tx_err);
            usleep(5000000);
        }
    }
}
