#ifndef BTNSW_H
#define BTNSW_H

#define BTN_C 0x01
#define BTN_D 0x02
#define BTN_L 0x04
#define BTN_R 0x08
#define BTN_U 0x10

int          btnsw_init(void);
unsigned int btnsw_switches(void);
unsigned int btnsw_buttons(void);
unsigned int btnsw_pressed(void);

#endif
