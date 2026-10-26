/* Raw lwIP callbacks only collect requests. AXI operations run in main(). */
#include "ris_network.h"
#include "xparameters.h"
#include "xgpiops.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xtime_l.h"
#include "sleep.h"
#include "lwip/init.h"
#include "lwip/tcp.h"
#include "lwip/priv/tcp_priv.h"
#include "lwip/etharp.h"
#include "lwip/ip4_frag.h"
#include "lwip/inet.h"
#include "netif/xadapter.h"
#include "netif/xemacpsif.h"
#include <string.h>

static struct netif board;
static struct tcp_pcb *client;
static char request[RIS_NET_REQUEST_BYTES], response[512];
static u32 used, pending, response_bytes, generation;
static int active;
static XTime last_tcp, last_arp, last_link, last_health, last_receive;

static void clear_client(void)
{
    client=NULL; used=pending=response_bytes=0;
}
static void failed(void *arg, err_t error)
{
    (void)arg; (void)error;
    clear_client();
}
static void detach(struct tcp_pcb *pcb)
{
    tcp_arg(pcb,NULL); tcp_recv(pcb,NULL); tcp_err(pcb,NULL);
}
static err_t received(void *arg, struct tcp_pcb *pcb, struct pbuf *p, err_t error)
{
    struct pbuf *part;
    (void)arg;
    if (!p) {
        clear_client(); detach(pcb);
        if (tcp_close(pcb)!=ERR_OK) {tcp_abort(pcb); return ERR_ABRT;}
        return ERR_OK;
    }
    if (error!=ERR_OK) {
        pbuf_free(p); clear_client(); detach(pcb); tcp_abort(pcb);
        return ERR_ABRT;
    }
    for (part=p; part; part=part->next) {
        const char *s=part->payload;
        u32 i;
        for (i=0; i<part->len; ++i) {
            char c=s[i];
            if (c=='\r') continue;
            if (!c || pending || response_bytes || used+1>=sizeof(request)) {
                pbuf_free(p); clear_client(); detach(pcb); tcp_abort(pcb);
                return ERR_ABRT;
            }
            if (c=='\n') {
                request[used]=0;
                if (used) pending=1;
                used=0;
            } else request[used++]=c;
        }
    }
    XTime_GetTime(&last_receive);
    tcp_recved(pcb,p->tot_len); pbuf_free(p);
    return ERR_OK;
}
static err_t accepted(void *arg, struct tcp_pcb *pcb, err_t error)
{
    (void)arg;
    if (error!=ERR_OK) return error;
    if (client) {tcp_abort(pcb); return ERR_ABRT;}
    clear_client(); client=pcb;
    if (!++generation) ++generation;
    tcp_recv(pcb,received); tcp_err(pcb,failed); tcp_nagle_disable(pcb);
    XTime_GetTime(&last_receive);
    return ERR_OK;
}
int ris_network_init(void)
{
    ip_addr_t ip,mask,gw;
    unsigned char mac[6]={0x02,0x0a,0x35,0x07,0x06,0x02};
    XGpioPs gpio;
    XGpioPs_Config *config=XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID);
    struct tcp_pcb *pcb,*listener;
    if (!config || XGpioPs_CfgInitialize(&gpio,config,config->BaseAddr)!=XST_SUCCESS) return -1;
    XGpioPs_SetDirectionPin(&gpio,47,1); XGpioPs_SetOutputEnablePin(&gpio,47,1);
    XGpioPs_WritePin(&gpio,47,0); usleep(10000);
    XGpioPs_WritePin(&gpio,47,1); usleep(10000);
    Xil_ExceptionInit();
    if (XScuGic_DeviceInitialize(XPAR_SCUGIC_SINGLE_DEVICE_ID)!=XST_SUCCESS) return -1;
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
        (Xil_ExceptionHandler)XScuGic_DeviceInterruptHandler,(void *)XPAR_SCUGIC_SINGLE_DEVICE_ID);
    lwip_init();
    if (!inet_aton(RIS_NET_ADDRESS,&ip) || !inet_aton("255.255.255.0",&mask) || !inet_aton("0.0.0.0",&gw)) return -1;
    if (!xemac_add(&board,&ip,&mask,&gw,mac,XPAR_XEMACPS_0_BASEADDR)) return -1;
    netif_set_default(&board); netif_set_up(&board);
    Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
    pcb=tcp_new();
    if (!pcb) return -1;
    if (tcp_bind(pcb,IP_ADDR_ANY,RIS_NET_PORT)!=ERR_OK) {tcp_abort(pcb); return -1;}
    listener=tcp_listen(pcb);
    if (!listener) {tcp_abort(pcb); return -1;}
    tcp_accept(listener,accepted);
    XTime_GetTime(&last_tcp); last_arp=last_link=last_health=last_tcp;
    active=1;
    return 0;
}
void ris_network_poll(void)
{
    XTime now;
    if (!active) return;
    xemacif_input(&board);
    XTime_GetTime(&now);
    if (now-last_tcp>=COUNTS_PER_SECOND/4) {tcp_tmr(); last_tcp=now;}
    if (now-last_arp>=COUNTS_PER_SECOND) {
        etharp_tmr();
#if IP_REASSEMBLY
        ip_reass_tmr();
#endif
        last_arp=now;
    }
    if (now-last_health>=COUNTS_PER_SECOND/10) {xemacpsif_resetrx_on_no_rxdata(&board); last_health=now;}
    if (now-last_link>=COUNTS_PER_SECOND) {eth_link_detect(&board); last_link=now;}
    if (client && now-last_receive>10ULL*COUNTS_PER_SECOND) {
        struct tcp_pcb *old=client;
        clear_client(); detach(old); tcp_abort(old);
    }
    if (client && response_bytes && tcp_sndbuf(client)>=response_bytes &&
        tcp_write(client,response,(u16_t)response_bytes,TCP_WRITE_FLAG_COPY)==ERR_OK) {
        response_bytes=0; tcp_output(client);
    }
}
u32 ris_network_session(void) {return client ? generation : 0;}
int ris_network_take(char command[RIS_NET_REQUEST_BYTES],u32 *session)
{
    if (!client || !pending || response_bytes || tcp_sndbuf(client)!=TCP_SND_BUF) return 0;
    strcpy(command,request); *session=generation; pending=0;
    return 1;
}
void ris_network_reply(u32 session,const char *reply)
{
    size_t n=strlen(reply);
    if (!client || session!=generation || n>=sizeof(response)) return;
    memcpy(response,reply,n); response_bytes=(u32)n;
}
