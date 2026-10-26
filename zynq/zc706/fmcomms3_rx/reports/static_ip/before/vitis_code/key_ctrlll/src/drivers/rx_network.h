#ifndef RX_NETWORK_H
#define RX_NETWORK_H
#include "xil_types.h"
#include "capture_format.h"
#define RX_NET_ADDRESS "192.168.10.10"
#define RX_NET_MASK "255.255.255.0"
#define RX_NET_GATEWAY "0.0.0.0"
#define RX_NET_CONSOLE_PORT 5000U
#define RX_NET_CONTROL_PORT 5001U
#define RX_NET_COMMAND_BYTES 192U
#define RX_NET_FRAME_BYTES (CAPTURE_CHUNK_BYTES + 2048U)
int rx_network_init(void);
/* Transport only: safe during SPI diagnostics/reset; never accesses PL DDR. */
void rx_network_poll(void);
void rx_network_set_foreground(void (*service)(void), int (*keys_blocked)(void));
int rx_network_take_request(char *command, u32 *ticket);
unsigned char *rx_network_frame(void);
void rx_network_reply(u32 ticket, u32 length);
int rx_network_queue_key(char key);
u32 rx_network_link_mbps(void);
u32 rx_network_log_overruns(void);
#endif
