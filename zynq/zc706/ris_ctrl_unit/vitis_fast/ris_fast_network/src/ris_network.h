#ifndef RIS_NETWORK_H
#define RIS_NETWORK_H
#include "xil_types.h"
#define RIS_NET_ADDRESS "192.168.1.11"
#define RIS_NET_PORT 7060
#define RIS_NET_REQUEST_BYTES 160
int ris_network_init(void);
void ris_network_poll(void);
u32 ris_network_session(void);
int ris_network_take(char command[RIS_NET_REQUEST_BYTES], u32 *session);
void ris_network_reply(u32 session, const char *reply);
#endif
