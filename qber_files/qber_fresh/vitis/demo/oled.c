/* ============================================================================
 * oled.c - 128x64 I2C OLED driver (SSD1306, optional SH1106)
 *
 * The screen is 8 "pages" x 128 columns; one byte = 8 vertical pixels
 * (bit 0 on top). The whole screen lives in fb[1024]. Every I2C message
 * starts with a control byte: 0x00 = commands follow, 0x40 = pixel data.
 * ========================================================================== */
/* #define OLED_SH1106 */

#include "oled.h"
#include "font8x8.h"
#include "ui_hw.h"
#include "xiicps.h"
#include "xstatus.h"
#include "sleep.h"
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

#define OLED_ADDR 0x3C            /* some modules use 0x3D */
#define I2C_HZ    400000

static XIicPs iic;
static unsigned char fb[OLED_ROWS * 128];

static void i2c_send(unsigned char *buf, int len)
{
    XIicPs_MasterSendPolled(&iic, buf, len, OLED_ADDR);
    while (XIicPs_BusIsBusy(&iic))
        ;
}

static void oled_cmds(const unsigned char *c, int n)
{
    unsigned char buf[40];
    buf[0] = 0x00;
    memcpy(&buf[1], c, n);
    i2c_send(buf, n + 1);
}

int oled_init(void)
{
    XIicPs_Config *cfg = XIicPs_LookupConfig(UI_OLED_IIC_ID);
    if (cfg == NULL) return -1;
    if (XIicPs_CfgInitialize(&iic, cfg, cfg->BaseAddress) != XST_SUCCESS) return -1;
    XIicPs_SetSClk(&iic, I2C_HZ);

    static const unsigned char init[] = {
        0xAE,             /* display off                                 */
        0xD5, 0x80,       /* clock                                       */
        0xA8, 0x3F,       /* 64 rows                                     */
        0xD3, 0x00,       /* no offset                                   */
        0x40,             /* start line 0                                */
        0x8D, 0x14,       /* charge pump on                              */
        0x20, 0x00,       /* horizontal addressing                       */
        0xA1,             /* 0xA0 instead if text is mirrored            */
        0xC8,             /* 0xC0 instead if text is upside down         */
        0xDA, 0x12,       /* COM pins, 128x64                            */
        0x81, 0xCF,       /* contrast                                    */
        0xD9, 0xF1,       /* pre-charge                                  */
        0xDB, 0x40,       /* VCOMH                                       */
        0xA4, 0xA6,       /* show RAM, not inverted                      */
        0xAF              /* display on                                  */
    };
    usleep(100000);
    oled_cmds(init, sizeof(init));
    oled_clear();
    oled_refresh();
    return 0;
}

void oled_contrast(unsigned char level)
{
    unsigned char c[2] = { 0x81, level };
    oled_cmds(c, 2);
}

void oled_clear(void) { memset(fb, 0, sizeof(fb)); }

static void draw_text(int row, int col, const char *text, int invert)
{
    if (row < 0 || row >= OLED_ROWS) return;
    for (; *text && col < OLED_COLS; text++, col++) {
        if (col < 0) continue;
        unsigned char ch = (unsigned char)*text;
        if (ch < 32 || ch > 126) ch = '?';
        const unsigned char *g = font8x8[ch - 32];
        unsigned char *dst = &fb[row * 128 + col * 8];
        for (int i = 0; i < 8; i++)
            dst[i] = invert ? (unsigned char)~g[i] : g[i];
    }
}

void oled_print(int row, int col, const char *t)     { draw_text(row, col, t, 0); }
void oled_print_inv(int row, int col, const char *t) { draw_text(row, col, t, 1); }

static void vline(int row, int invert, const char *fmt, va_list ap)
{
    char buf[OLED_COLS + 1];
    vsnprintf(buf, sizeof(buf), fmt, ap);
    size_t n = strlen(buf);
    memset(buf + n, ' ', OLED_COLS - n);       /* pad: erase old text */
    buf[OLED_COLS] = '\0';
    draw_text(row, 0, buf, invert);
}

void oled_line(int row, const char *fmt, ...)
{
    va_list ap; va_start(ap, fmt); vline(row, 0, fmt, ap); va_end(ap);
}

void oled_line_inv(int row, const char *fmt, ...)
{
    va_list ap; va_start(ap, fmt); vline(row, 1, fmt, ap); va_end(ap);
}

void oled_refresh(void)
{
    unsigned char buf[17];
    buf[0] = 0x40;
#ifndef OLED_SH1106
    static const unsigned char win[] = { 0x21, 0, 127, 0x22, 0, 7 };
    oled_cmds(win, sizeof(win));
    for (int i = 0; i < (int)sizeof(fb); i += 16) {
        memcpy(&buf[1], &fb[i], 16);
        i2c_send(buf, 17);
    }
#else
    for (int page = 0; page < OLED_ROWS; page++) {
        unsigned char pos[3] = { (unsigned char)(0xB0 + page), 0x02, 0x10 };
        oled_cmds(pos, 3);
        for (int i = 0; i < 128; i += 16) {
            memcpy(&buf[1], &fb[page * 128 + i], 16);
            i2c_send(buf, 17);
        }
    }
#endif
}

/* the fixed I2C address (used for the start-up message) */
unsigned oled_address(void) { return OLED_ADDR; }
