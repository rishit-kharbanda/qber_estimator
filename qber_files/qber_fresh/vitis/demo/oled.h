#ifndef OLED_H
#define OLED_H

#define OLED_ROWS 8
#define OLED_COLS 16

int  oled_init(void);
unsigned oled_address(void);
void oled_clear(void);
void oled_print(int row, int col, const char *text);
void oled_print_inv(int row, int col, const char *text);
void oled_line(int row, const char *fmt, ...);
void oled_line_inv(int row, const char *fmt, ...);
void oled_refresh(void);
void oled_contrast(unsigned char level);

#endif
