#ifndef RX_UPLINK_H
#define RX_UPLINK_H

#include "rx_uplink_packet.h"
#include "xtime_l.h"

int rx_uplink_init(void);
void rx_uplink_poll(XTime now);
int rx_uplink_link_up(void);
int rx_uplink_init_error(void);

/* Success means lwIP accepted the datagram for this interface, including ARP. */
int rx_uplink_send(uint32_t sequence, unsigned type, const uint8_t *payload,
                   size_t length);

#endif
