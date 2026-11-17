#ifndef UPLINK_MOCK_H
#define UPLINK_MOCK_H
#include <stdint.h>
#include <stddef.h>
typedef uint8_t u8_t;
typedef uint16_t u16_t;
typedef uint32_t u32;
typedef uint64_t XTime;
typedef int err_t;
typedef struct {uint32_t addr;} ip_addr_t;
struct netif {int up,link; unsigned base;};
struct pbuf {struct pbuf *next; void *payload; u16_t len,tot_len;};
struct tcp_pcb;
struct udp_pcb;
typedef err_t (*tcp_recv_fn)(void *,struct tcp_pcb *,struct pbuf *,err_t);
typedef err_t (*tcp_accept_fn)(void *,struct tcp_pcb *,err_t);
typedef void (*tcp_err_fn)(void *,err_t);
typedef void (*udp_recv_fn)(void *,struct udp_pcb *,struct pbuf *,const ip_addr_t *,u16_t);
struct tcp_pcb {
    tcp_recv_fn recv; tcp_accept_fn accept; tcp_err_fn error;
    const struct netif *bound_netif; ip_addr_t address; unsigned port;
    void *arg; unsigned aborted;
};
struct udp_pcb {udp_recv_fn recv; void *arg; const struct netif *bound_netif;
    ip_addr_t address; unsigned port;};
#define ERR_OK 0
#define ERR_MEM -1
#define ERR_ABRT -13
#define TCP_WRITE_FLAG_COPY 1
#define COUNTS_PER_SECOND 1000u
#define XPAR_XEMACPS_1_BASEADDR 0xe000c000u
extern struct netif *mock_input_netif;
extern ip_addr_t mock_dest;
#define ip_current_input_netif() (mock_input_netif)
#define ip_current_dest_addr() (&mock_dest)
#define ip_addr_cmp(a,b) ((a)->addr==(b)->addr)
#define netif_is_link_up(n) ((n)->link)
void XTime_GetTime(XTime *now);
int inet_aton(const char *,ip_addr_t *);
struct tcp_pcb *tcp_new(void);
void tcp_bind_netif(struct tcp_pcb *,const struct netif *);
err_t tcp_bind(struct tcp_pcb *,const ip_addr_t *,u16_t);
struct tcp_pcb *tcp_listen(struct tcp_pcb *);
void tcp_accept(struct tcp_pcb *,tcp_accept_fn);
void tcp_recv(struct tcp_pcb *,tcp_recv_fn);
void tcp_err(struct tcp_pcb *,tcp_err_fn);
void tcp_arg(struct tcp_pcb *,void *);
void tcp_nagle_disable(struct tcp_pcb *);
void tcp_abort(struct tcp_pcb *);
err_t tcp_close(struct tcp_pcb *);
unsigned tcp_sndbuf(struct tcp_pcb *);
err_t tcp_write(struct tcp_pcb *,const void *,u16_t,unsigned);
err_t tcp_output(struct tcp_pcb *);
struct udp_pcb *udp_new(void);
void udp_bind_netif(struct udp_pcb *,const struct netif *);
err_t udp_bind(struct udp_pcb *,const ip_addr_t *,u16_t);
void udp_remove(struct udp_pcb *);
void udp_recv(struct udp_pcb *,udp_recv_fn,void *);
void pbuf_free(struct pbuf *);
u16_t pbuf_copy_partial(const struct pbuf *,void *,u16_t,u16_t);
struct netif *xemac_add(struct netif *,ip_addr_t *,ip_addr_t *,ip_addr_t *,unsigned char *,unsigned);
void netif_set_up(struct netif *);
int xemacif_input(struct netif *);
void xemacpsif_resetrx_on_no_rxdata(struct netif *);
void eth_link_detect(struct netif *);
int ris_pl_eth_board_init(void);
#endif
