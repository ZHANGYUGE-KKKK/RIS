/* Actual network adapter + actual packet parser; lwIP/BSP I/O is mocked. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "uplink_mock.h"
#include "uplink_vectors.h"
#include "../software/network/ris_uplink.c"

struct netif *mock_input_netif;
ip_addr_t mock_dest;
static struct tcp_pcb mock_listener;
static struct udp_pcb mock_udp;
static unsigned mock_send_space=8192, mock_frees, mock_writes;
static int mock_write_error, mock_board_error;
static char mock_output[8192];

void XTime_GetTime(XTime *now) {*now=0;}
int inet_aton(const char *s,ip_addr_t *ip)
{
    unsigned a,b,c,d;
    if(sscanf(s,"%u.%u.%u.%u",&a,&b,&c,&d)!=4)return 0;
    ip->addr=a<<24|b<<16|c<<8|d; return 1;
}
struct tcp_pcb *tcp_new(void) {memset(&mock_listener,0,sizeof(mock_listener));return &mock_listener;}
void tcp_bind_netif(struct tcp_pcb *p,const struct netif *n){p->bound_netif=n;}
err_t tcp_bind(struct tcp_pcb *p,const ip_addr_t *ip,u16_t port){p->address=*ip;p->port=port;return 0;}
struct tcp_pcb *tcp_listen(struct tcp_pcb *p){return p;}
void tcp_accept(struct tcp_pcb *p,tcp_accept_fn f){p->accept=f;}
void tcp_recv(struct tcp_pcb *p,tcp_recv_fn f){p->recv=f;}
void tcp_err(struct tcp_pcb *p,tcp_err_fn f){p->error=f;}
void tcp_arg(struct tcp_pcb *p,void *a){p->arg=a;}
void tcp_nagle_disable(struct tcp_pcb *p){(void)p;}
void tcp_abort(struct tcp_pcb *p){++p->aborted;}
err_t tcp_close(struct tcp_pcb *p){(void)p;return 0;}
unsigned tcp_sndbuf(struct tcp_pcb *p){(void)p;return mock_send_space;}
err_t tcp_write(struct tcp_pcb *p,const void *data,u16_t n,unsigned flags)
{
    (void)p;assert(flags==TCP_WRITE_FLAG_COPY);
    if(mock_write_error)return ERR_MEM;
    assert(n<sizeof(mock_output));memcpy(mock_output,data,n);mock_output[n]=0;
    ++mock_writes;return 0;
}
err_t tcp_output(struct tcp_pcb *p){(void)p;return 0;}
struct udp_pcb *udp_new(void){memset(&mock_udp,0,sizeof(mock_udp));return &mock_udp;}
void udp_bind_netif(struct udp_pcb *p,const struct netif *n){p->bound_netif=n;}
err_t udp_bind(struct udp_pcb *p,const ip_addr_t *ip,u16_t port){p->address=*ip;p->port=port;return 0;}
void udp_remove(struct udp_pcb *p){(void)p;}
void udp_recv(struct udp_pcb *p,udp_recv_fn f,void *a){p->recv=f;p->arg=a;}
void pbuf_free(struct pbuf *p){(void)p;++mock_frees;}
u16_t pbuf_copy_partial(const struct pbuf *p,void *destination,u16_t n,u16_t offset)
{
    unsigned copied=0;uint8_t *out=destination;
    while(p && copied<n) {
        unsigned take;
        if(offset>=p->len){offset-=p->len;p=p->next;continue;}
        take=p->len-offset;if(take>n-copied)take=n-copied;
        memcpy(out+copied,(uint8_t *)p->payload+offset,take);
        copied+=take;offset=0;p=p->next;
    }
    return (u16_t)copied;
}
struct netif *xemac_add(struct netif *n,ip_addr_t *ip,ip_addr_t *mask,
    ip_addr_t *gw,unsigned char *mac,unsigned base)
{(void)ip;(void)mask;(void)gw;assert(mac[5]==3);n->base=base;n->link=1;return n;}
void netif_set_up(struct netif *n){n->up=1;}
int xemacif_input(struct netif *n){assert(n==&pl_netif);return 0;}
void xemacpsif_resetrx_on_no_rxdata(struct netif *n){assert(n==&pl_netif);}
void eth_link_detect(struct netif *n){assert(n==&pl_netif);}
int ris_pl_eth_board_init(void){return mock_board_error;}

static void deliver(const unsigned char *packet,size_t length,int split,
                    const ip_addr_t *source,u16_t port)
{
    struct pbuf tail={NULL,(void *)(packet+split),(u16_t)(length-split),(u16_t)(length-split)};
    struct pbuf head={&tail,(void *)packet,(u16_t)split,(u16_t)length};
    unsigned before=mock_frees;
    mock_udp.recv(mock_udp.arg,&mock_udp,&head,source,port);
    assert(mock_frees==before+1);
}
int main(void)
{
    struct netif ps={0};struct tcp_pcb client={0},second={0};
    ip_addr_t foreign;unsigned i,old;char line[RIS_UPLINK_JSON_BYTES];
    uint8_t damaged[sizeof(vector_small)];
    assert(ris_uplink_init(&ps)==0);
    assert(mock_listener.bound_netif==&ps && mock_listener.port==7070);
    assert(mock_listener.address.addr==0xc0a8010bu);
    assert(mock_udp.bound_netif==&pl_netif && mock_udp.port==7061);
    assert(mock_udp.address.addr==0xc0a8020bu && pl_netif.up);
    mock_input_netif=&pl_netif;mock_dest=pl_ip;
    assert(mock_listener.accept(NULL,&client,0)==0);
    assert(mock_listener.accept(NULL,&second,0)==ERR_ABRT && second.aborted==1);
    ris_uplink_poll(1);assert(strstr(mock_output,"uplink_status"));

    /* A chained pbuf split inside the header must decode without alignment assumptions. */
    deliver(vector_small,sizeof(vector_small),3,&peer_ip,7061);
    assert(queue.count==1 && queue.accepted==1);
    assert(ris_uplink_peek(&queue)->sequence==0x12345678u);
    assert(ris_uplink_record_json(ris_uplink_peek(&queue),line,4)==0);
    mock_send_space=0;old=mock_writes;ris_uplink_poll(2);
    assert(queue.count==1 && mock_writes==old);
    mock_send_space=8192;mock_write_error=1;ris_uplink_poll(3);
    assert(queue.count==1 && queue.forwarded==0);
    mock_write_error=0;ris_uplink_poll(4);
    assert(queue.count==0 && queue.forwarded==1);
    assert(strstr(mock_output,"6100620a1b") && strstr(mock_output,"305419896"));

    /* Filter by actual receiving interface, destination, source address and port. */
    mock_input_netif=&ps;deliver(vector_small,sizeof(vector_small),8,&peer_ip,7061);
    mock_input_netif=&pl_netif;mock_dest.addr^=1;
    deliver(vector_small,sizeof(vector_small),8,&peer_ip,7061);mock_dest=pl_ip;
    foreign=peer_ip;foreign.addr^=1;
    deliver(vector_small,sizeof(vector_small),8,&foreign,7061);
    deliver(vector_small,sizeof(vector_small),8,&peer_ip,1234);
    assert(queue.source_rejected==4 && queue.count==0);

    for(i=0;i<sizeof(vector_small);++i) {
        memcpy(damaged,vector_small,sizeof(damaged));damaged[i]^=1;
        deliver(damaged,sizeof(damaged),7,&peer_ip,7061);
    }
    for(i=0;i<24;++i)deliver(vector_small,i,0,&peer_ip,7061);
    assert(queue.invalid==sizeof(vector_small)+24 && queue.count==0);
    /* Version/type/reserved fields are rejected even with a recomputed valid CRC. */
    for(i=0;i<sizeof(invalid_packets)/sizeof(invalid_packets[0]);++i)
        assert(!ris_uplink_ingest(&queue,invalid_packets[i],sizeof(vector_small),1));
    assert(!ris_uplink_ingest(&queue,vector_max,sizeof(vector_max)+1,1));
    assert(ris_uplink_ingest(&queue,vector_empty,sizeof(vector_empty),1));
    ris_uplink_poll(5);assert(strstr(mock_output,"\"length\":0"));
    assert(ris_uplink_ingest(&queue,vector_max,sizeof(vector_max),1));
    ris_uplink_poll(6);assert(strstr(mock_output,"\"length\":1024"));
    assert(strlen(mock_output)<RIS_UPLINK_JSON_BYTES);

    /* Disconnect keeps queued records; a slow/absent subscriber cannot grow memory. */
    client.error(NULL,ERR_MEM);assert(!subscriber && queue.disconnects==1);
    for(i=0;i<RIS_UPLINK_QUEUE_DEPTH+3;++i)
        deliver(vector_small,sizeof(vector_small),13,&peer_ip,7061);
    assert(queue.count==RIS_UPLINK_QUEUE_DEPTH && queue.queue_dropped==3);
    assert(mock_listener.accept(NULL,&client,0)==0);
    ris_uplink_poll(7);assert(strstr(mock_output,"\"queue_dropped\":3"));
    for(i=0;i<RIS_UPLINK_QUEUE_DEPTH;++i)ris_uplink_poll(8+i);
    assert(queue.count==0);
    {struct pbuf input={NULL,(void *)"STOP\n",5,5};
        assert(client.recv(NULL,&client,&input,0)==ERR_ABRT);}
    assert(!subscriber && client.aborted==1);

    /* Board bring-up failure still exposes diagnostics through the PS listener. */
    mock_board_error=-22;assert(ris_uplink_init(&ps)==-22);
    assert(!pl_ready && mock_listener.accept(NULL,&client,0)==0);
    ris_uplink_poll(1);assert(strstr(mock_output,"\"ready\":false"));
    assert(strstr(mock_output,"\"init_error\":-22"));
    puts("RIS_UPLINK_NETWORK_TEST_PASS: CRC/framing, chained pbuf, ingress filters, bounded queue, backpressure, subscribers, failure diagnostics");
    return 0;
}
