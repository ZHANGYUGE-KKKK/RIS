#include "rx_uplink.h"
#include "ris_pl_eth_board.h"
#include "xparameters.h"
#include "lwip/inet.h"
#include "lwip/udp.h"
#include "netif/xadapter.h"
#include "netif/xemacpsif.h"

#define RX_UPLINK_PORT 7061U
#define RX_UPLINK_ADDRESS "192.168.2.12"
#define RX_UPLINK_PEER "192.168.2.11"

static struct netif pl_netif;
static struct udp_pcb *uplink;
static ip_addr_t peer;
static XTime last_link, last_health;
static int pl_added, init_error;
static uint8_t datagram[RX_UPLINK_HEADER_BYTES + RX_UPLINK_MAX_PAYLOAD];

int rx_uplink_init(void)
{
    ip_addr_t address, mask, gateway;
    unsigned char mac[6] = {0x02, 0x0a, 0x35, 0x07, 0x06, 0x04};
    int rc = ris_pl_eth_board_init();

    if (rc) return init_error = rc;
    if (!inet_aton(RX_UPLINK_ADDRESS, &address) ||
        !inet_aton(RX_UPLINK_PEER, &peer) ||
        !inet_aton("255.255.255.0", &mask) || !inet_aton("0.0.0.0", &gateway))
        return init_error = -101;
    if (!xemac_add(&pl_netif, &address, &mask, &gateway, mac, XPAR_XEMACPS_1_BASEADDR))
        return init_error = -102;
    pl_added = 1;
    netif_set_up(&pl_netif);
    XTime_GetTime(&last_link);
    last_health = last_link;

    uplink = udp_new();
    if (!uplink) return init_error = -103;
    udp_bind_netif(uplink, &pl_netif);
    if (udp_bind(uplink, &address, RX_UPLINK_PORT) != ERR_OK) {
        udp_remove(uplink);
        uplink = NULL;
        return init_error = -104;
    }
    return init_error = 0;
}

void rx_uplink_poll(XTime now)
{
    if (!pl_added) return;
    xemacif_input(&pl_netif);
    if (now - last_health >= COUNTS_PER_SECOND / 10U) {
        xemacpsif_resetrx_on_no_rxdata(&pl_netif);
        last_health = now;
    }
    if (now - last_link >= COUNTS_PER_SECOND) {
        eth_link_detect(&pl_netif);
        last_link = now;
    }
}

int rx_uplink_link_up(void)
{
    return pl_added && netif_is_link_up(&pl_netif);
}

int rx_uplink_init_error(void)
{
    return init_error;
}

int rx_uplink_send(uint32_t sequence, unsigned type, const uint8_t *payload,
                   size_t length)
{
    XTime now;
    uint32_t sender_ms;
    size_t size;
    struct pbuf *packet;
    err_t rc;

    if (!uplink) return ERR_IF;
    if (!rx_uplink_link_up()) return ERR_RTE;
    XTime_GetTime(&now);
    sender_ms = (uint32_t)((now / COUNTS_PER_SECOND) * 1000U +
                          ((now % COUNTS_PER_SECOND) * 1000U) / COUNTS_PER_SECOND);
    size = rx_uplink_encode(datagram, sizeof(datagram), sequence, sender_ms,
                            type, payload, length);
    if (!size) return ERR_VAL;

    packet = pbuf_alloc(PBUF_TRANSPORT, (u16_t)size, PBUF_RAM);
    if (!packet) return ERR_MEM;
    rc = pbuf_take(packet, datagram, (u16_t)size);
    if (rc == ERR_OK) rc = udp_sendto_if(uplink, packet, &peer, RX_UPLINK_PORT, &pl_netif);
    pbuf_free(packet);
    return rc;
}
