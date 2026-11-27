#ifndef KYPD_H
#define KYPD_H

int  kypd_init(void);
char kypd_scan(void);
char kypd_get_key(void);

char kypd_state(void);

char kypd_wait_key(void);

#endif
