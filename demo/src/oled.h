/* ============================================================================
 * oled.h - 128x64 I2C OLED (SSD1306; SH1106 optional) on JB (SCL JB1, SDA JB2), 0x3C, 400 kHz
 *
 * Text grid: 8 rows (0..7) x 16 columns (0..15) of 8x8 characters.
 * Drawing changes a copy of the screen in RAM; oled_refresh() sends it
 * (~25 ms at 400 kHz).
 * Shifted / noisy picture = SH1106 chip: #define OLED_SH1106 in oled.c.
 * ========================================================================== */
#ifndef OLED_H
#define OLED_H

#define OLED_ROWS 8
#define OLED_COLS 16

int  oled_init(void);                                    /* 0 = OK            */
unsigned oled_address(void);                             /* 0x3C (fixed)      */
void oled_clear(void);
void oled_print(int row, int col, const char *text);
void oled_print_inv(int row, int col, const char *text); /* inverted text     */
void oled_line(int row, const char *fmt, ...);           /* printf whole row  */
void oled_line_inv(int row, const char *fmt, ...);       /* same, inverted    */
void oled_refresh(void);
void oled_contrast(unsigned char level);

#endif
