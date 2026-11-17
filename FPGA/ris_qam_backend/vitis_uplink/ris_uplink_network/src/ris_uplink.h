#ifndef RIS_UPLINK_H
#define RIS_UPLINK_H
#include "xtime_l.h"
struct netif;
#define RIS_UPLINK_PL_ADDRESS "192.168.2.11"
#define RIS_UPLINK_PEER_ADDRESS "192.168.2.12"
#define RIS_UPLINK_UDP_PORT 7061
#define RIS_UPLINK_MONITOR_PORT 7070
/* Failure does not stop the existing RIS command server. */
int ris_uplink_init(struct netif *ps_netif);
void ris_uplink_poll(XTime now);
#endif
