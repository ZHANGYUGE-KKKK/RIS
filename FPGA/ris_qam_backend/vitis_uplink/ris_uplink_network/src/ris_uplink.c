/* GEM1 UDP telemetry is never passed to the RIS command parser. */
#include "ris_uplink.h"
#include "ris_uplink_core.h"
#include "ris_network.h"
#include "ris_pl_eth_board.h"
#include "xparameters.h"
#include "lwip/tcp.h"
#include "lwip/udp.h"
#include "lwip/ip.h"
#include "lwip/inet.h"
#include "netif/xadapter.h"
#include "netif/xemacpsif.h"

static struct netif pl_netif;
static struct tcp_pcb *subscriber;
static ris_uplink_queue queue;
static ip_addr_t peer_ip, pl_ip;
static int pl_added, pl_ready, init_error;
static XTime last_link, last_health, last_status;
static unsigned status_pending;
static uint8_t datagram[RIS_UPLINK_MAX_DATAGRAM];
static char json_line[RIS_UPLINK_JSON_BYTES];

static void detach_subscriber(struct tcp_pcb *pcb)
{
    tcp_arg(pcb,NULL); tcp_recv(pcb,NULL); tcp_err(pcb,NULL);
}
static void subscriber_error(void *arg, err_t error)
{
    (void)arg; (void)error;
    subscriber=NULL; ++queue.disconnects;
}
static err_t subscriber_received(void *arg, struct tcp_pcb *pcb,
                                 struct pbuf *p, err_t error)
{
    (void)arg;
    /* This connection is server-to-client only, including on error. */
    if (p) pbuf_free(p);
    subscriber=NULL; ++queue.disconnects; detach_subscriber(pcb);
    if (!p && error==ERR_OK && tcp_close(pcb)==ERR_OK) return ERR_OK;
    tcp_abort(pcb);
    return ERR_ABRT;
}
static err_t subscriber_accepted(void *arg, struct tcp_pcb *pcb, err_t error)
{
    (void)arg;
    if (error!=ERR_OK) return error;
    if (subscriber) {tcp_abort(pcb); return ERR_ABRT;}
    subscriber=pcb; ++queue.subscribers; status_pending=1;
    tcp_recv(pcb,subscriber_received); tcp_err(pcb,subscriber_error);
    tcp_nagle_disable(pcb);
    return ERR_OK;
}
static void datagram_received(void *arg, struct udp_pcb *pcb, struct pbuf *p,
                              const ip_addr_t *source, u16_t port)
{
    int source_ok;
    size_t length;
    (void)arg; (void)pcb;
    if (!p) return;
    source_ok=ip_current_input_netif()==&pl_netif &&
        ip_addr_cmp(ip_current_dest_addr(),&pl_ip) &&
        ip_addr_cmp(source,&peer_ip) && port==RIS_UPLINK_UDP_PORT;
    length=p->tot_len;
    if (!source_ok || length>sizeof(datagram) ||
        pbuf_copy_partial(p,datagram,(u16_t)length,0)!=length)
        (void)ris_uplink_ingest(&queue,NULL,length,source_ok);
    else
        (void)ris_uplink_ingest(&queue,datagram,length,1);
    pbuf_free(p);
}
int ris_uplink_init(struct netif *ps_netif)
{
    ip_addr_t ps_ip;
    struct tcp_pcb *pcb,*listener;
    ris_uplink_queue_init(&queue);
    subscriber=NULL; pl_added=0; pl_ready=0; init_error=0;
    if (!inet_aton(RIS_NET_ADDRESS,&ps_ip)) return -101;
    pcb=tcp_new();
    if (!pcb) return -102;
    tcp_bind_netif(pcb,ps_netif);
    if (tcp_bind(pcb,&ps_ip,RIS_UPLINK_MONITOR_PORT)!=ERR_OK) {
        tcp_abort(pcb); return -103;
    }
    listener=tcp_listen(pcb);
    if (!listener) {tcp_abort(pcb); return -104;}
    tcp_accept(listener,subscriber_accepted);
    XTime_GetTime(&last_link); last_health=last_status=last_link;
#ifdef XPAR_XEMACPS_1_BASEADDR
    {
        ip_addr_t mask,gw;
        unsigned char mac[6]={0x02,0x0a,0x35,0x07,0x06,0x03};
        struct udp_pcb *udp;
        init_error=ris_pl_eth_board_init();
        if (init_error) return init_error;
        if (!inet_aton(RIS_UPLINK_PL_ADDRESS,&pl_ip) ||
            !inet_aton(RIS_UPLINK_PEER_ADDRESS,&peer_ip) ||
            !inet_aton("255.255.255.0",&mask) || !inet_aton("0.0.0.0",&gw))
            return init_error=-105;
        if (!xemac_add(&pl_netif,&pl_ip,&mask,&gw,mac,XPAR_XEMACPS_1_BASEADDR))
            return init_error=-106;
        pl_added=1;
        netif_set_up(&pl_netif);
        udp=udp_new();
        if (!udp) return init_error=-107;
        udp_bind_netif(udp,&pl_netif);
        if (udp_bind(udp,&pl_ip,RIS_UPLINK_UDP_PORT)!=ERR_OK) {
            udp_remove(udp); return init_error=-108;
        }
        udp_recv(udp,datagram_received,NULL);
        pl_ready=1;
    }
#else
    init_error=-109; /* Existing single-GEM BSP; no silent success. */
    (void)datagram_received;
#endif
    return init_error;
}
void ris_uplink_poll(XTime now)
{
    size_t length;
    const ris_uplink_record *record;
    if (pl_added) {
        xemacif_input(&pl_netif);
        if (now-last_health>=COUNTS_PER_SECOND/10) {
            xemacpsif_resetrx_on_no_rxdata(&pl_netif); last_health=now;
        }
        if (now-last_link>=COUNTS_PER_SECOND) {
            eth_link_detect(&pl_netif); last_link=now;
        }
    }
    if (!subscriber) return;
    if (status_pending || now-last_status>=COUNTS_PER_SECOND) {
        length=ris_uplink_stats_json(&queue,pl_ready,
            pl_added && netif_is_link_up(&pl_netif),init_error,
            json_line,sizeof(json_line));
        if (length && tcp_sndbuf(subscriber)>=length &&
            tcp_write(subscriber,json_line,(u16_t)length,TCP_WRITE_FLAG_COPY)==ERR_OK) {
            status_pending=0; last_status=now; (void)tcp_output(subscriber);
        }
        return;
    }
    record=ris_uplink_peek(&queue);
    if (!record) return;
    length=ris_uplink_record_json(record,json_line,sizeof(json_line));
    if (length && tcp_sndbuf(subscriber)>=length &&
        tcp_write(subscriber,json_line,(u16_t)length,TCP_WRITE_FLAG_COPY)==ERR_OK) {
        ris_uplink_forwarded(&queue); (void)tcp_output(subscriber);
    }
}
