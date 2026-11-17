/* Two independent TCP streams: text console and framed data/control.
 * Raw lwIP callbacks only queue work; application/PL transactions happen in
 * the foreground. All TCP writes COPY, so reconnects cannot retain pointers
 * into a reused PS buffer. Exactly one outstanding request per control client.
 */
#include "rx_network.h"
#include "xparameters.h"
#include "xuartps_hw.h"
#include "xgpiops.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xpseudo_asm.h"
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
#include <stdint.h>
#include <string.h>
#include <stdio.h>

#define LOG_BYTES 131072U
#define KEY_BYTES 128U
static struct netif board_netif;
static struct tcp_pcb *console, *control;
static char log_ring[LOG_BYTES], keys[KEY_BYTES], request[RX_NET_COMMAND_BYTES];
static unsigned char frame[RX_NET_FRAME_BYTES] __attribute__((aligned(64)));
static u64 log_write, log_read;
static u32 key_in, key_out, line_used, request_ready, ticket_counter, control_ticket;
static u32 frame_len, frame_sent, log_overruns;
static int active, polling, foreground_running;
static void (*foreground)(void);
static int (*keys_blocked)(void);
static XTime last_tcp, last_arp, last_link, last_health;

static void clear_connection(int which)
{
    if (which == 1) console = NULL;
    else {
        control = NULL; request_ready = 0U; line_used = 0U;
        frame_len = frame_sent = 0U;
    }
}
static void connection_error(void *arg, err_t error)
{
    (void)error;
    clear_connection((int)(intptr_t)arg);
}
static err_t receive(void *arg, struct tcp_pcb *pcb, struct pbuf *p, err_t error)
{
    struct pbuf *part;
    u32 i, which = (u32)(uintptr_t)arg;
    if (!p) {
        clear_connection((int)which);
        /* A closing PCB may outlive this slot. Detach its callbacks before
         * accepting a new client so a late error cannot clear the new slot. */
        tcp_err(pcb, NULL); tcp_recv(pcb, NULL); tcp_arg(pcb, NULL);
        if (tcp_close(pcb) != ERR_OK) { tcp_abort(pcb); return ERR_ABRT; }
        return ERR_OK;
    }
    if (error != ERR_OK) { pbuf_free(p); return error; }
    if (which == 1U && p->tot_len > KEY_BYTES - (key_in - key_out))
        return ERR_MEM; /* lwIP retains p and retries after receive space opens. */
    for (part = p; part; part = part->next) {
        const char *s = part->payload;
        for (i = 0; i < part->len; ++i) {
            char ch = s[i];
            if (which == 1U) keys[key_in++ % KEY_BYTES] = ch;
            else if (ch != '\r') {
                if (!ch || request_ready || line_used + 1U >= sizeof(request)) {
                    pbuf_free(p); tcp_abort(pcb); return ERR_ABRT;
                }
                if (ch == '\n') {
                    request[line_used] = 0;
                    if (line_used) request_ready = 1U;
                    line_used = 0U;
                } else request[line_used++] = ch;
            }
        }
    }
    tcp_recved(pcb, p->tot_len);
    pbuf_free(p);
    return ERR_OK;
}
static err_t accepted(void *arg, struct tcp_pcb *pcb, err_t error)
{
    int which = (int)(intptr_t)arg;
    if (error != ERR_OK) return error;
    if ((which == 1 && console) || (which == 2 && control)) {
        tcp_abort(pcb); return ERR_ABRT;
    }
    tcp_arg(pcb, arg);
    tcp_recv(pcb, receive);
    tcp_err(pcb, connection_error);
    tcp_nagle_disable(pcb);
    if (which == 1) {
        console = pcb;
        log_read = log_write > LOG_BYTES ? log_write - LOG_BYTES : 0U;
        key_in = key_out = 0U;
    } else {
        control = pcb; control_ticket = ++ticket_counter;
        request_ready = line_used = frame_len = frame_sent = 0U;
    }
    return ERR_OK;
}
static int listen_port(u16_t port, int which)
{
    struct tcp_pcb *pcb = tcp_new(), *listener;
    if (!pcb) return -1;
    if (tcp_bind(pcb, IP_ADDR_ANY, port) != ERR_OK) { tcp_abort(pcb); return -1; }
    listener = tcp_listen(pcb);
    if (!listener) { tcp_abort(pcb); return -1; }
    tcp_arg(listener, (void *)(intptr_t)which);
    tcp_accept(listener, accepted);
    return 0;
}
static void flush_streams(void)
{
    unsigned budget;
    if (control && frame_len) {
        for (budget = 0; budget < 8U && frame_sent < frame_len; ++budget) {
            u32 n = frame_len - frame_sent;
            if (n > 4096U) n = 4096U;
            if (n > tcp_sndbuf(control)) n = tcp_sndbuf(control);
            if (!n || tcp_write(control, frame + frame_sent, (u16_t)n,
                                TCP_WRITE_FLAG_COPY) != ERR_OK) break;
            frame_sent += n;
        }
        tcp_output(control);
        if (frame_sent == frame_len) frame_len = frame_sent = 0U;
    }
    if (console) {
        if (log_write - log_read > LOG_BYTES) {
            ++log_overruns; log_read = log_write - LOG_BYTES;
        }
        for (budget = 0; budget < 4U && log_read < log_write; ++budget) {
            u32 pos = (u32)(log_read % LOG_BYTES), n = (u32)(log_write - log_read);
            if (n > LOG_BYTES - pos) n = LOG_BYTES - pos;
            if (n > 1460U) n = 1460U;
            if (n > tcp_sndbuf(console)) n = tcp_sndbuf(console);
            if (!n || tcp_write(console, log_ring + pos, (u16_t)n,
                                TCP_WRITE_FLAG_COPY) != ERR_OK) break;
            log_read += n;
        }
        tcp_output(console);
    }
}
int rx_network_init(void)
{
    ip_addr_t ip, mask, gw;
    XGpioPs gpio;
    XGpioPs_Config *gc;
    unsigned char mac[6] = {0x02,0x0a,0x35,0x07,0x06,0x01};
    /* ZC706 PHY reset is MIO47; preserve all RF/EMIO GPIO bits. */
    gc = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID);
    if (!gc || XGpioPs_CfgInitialize(&gpio, gc, gc->BaseAddr) != XST_SUCCESS) return -1;
    XGpioPs_SetDirectionPin(&gpio, 47U, 1U);
    XGpioPs_SetOutputEnablePin(&gpio, 47U, 1U);
    XGpioPs_WritePin(&gpio, 47U, 0U); usleep(10000U);
    XGpioPs_WritePin(&gpio, 47U, 1U); usleep(10000U);
    Xil_ExceptionInit();
    if (XScuGic_DeviceInitialize(XPAR_SCUGIC_SINGLE_DEVICE_ID) != XST_SUCCESS) return -1;
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
        (Xil_ExceptionHandler)XScuGic_DeviceInterruptHandler,
        (void *)XPAR_SCUGIC_SINGLE_DEVICE_ID);
    lwip_init();
    if (!inet_aton(RX_NET_ADDRESS, &ip) || !inet_aton(RX_NET_MASK, &mask) ||
        !inet_aton(RX_NET_GATEWAY, &gw)) return -1;
    if (!xemac_add(&board_netif, &ip, &mask, &gw, mac, XPAR_XEMACPS_0_BASEADDR)) return -1;
    netif_set_default(&board_netif);
    netif_set_up(&board_netif);
    Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
    if (listen_port(RX_NET_CONSOLE_PORT, 1) || listen_port(RX_NET_CONTROL_PORT, 2)) return -1;
    XTime_GetTime(&last_tcp); last_arp = last_link = last_health = last_tcp;
    active = 1;
    printf("\r\nRX network v3: %s/%s console=%u control=%u; UART mirrored\r\n",
           RX_NET_ADDRESS, RX_NET_MASK, RX_NET_CONSOLE_PORT, RX_NET_CONTROL_PORT);
    return 0;
}
void rx_network_poll(void)
{
    XTime now;
    /* Do not enter raw lwIP from a GEM error print inside an IRQ/critical section. */
    if (!active || polling || (mfcpsr() & 0x80U)) return;
    polling = 1;
    xemacif_input(&board_netif);
    XTime_GetTime(&now);
    if (now - last_tcp >= COUNTS_PER_SECOND / 4U) {
        tcp_tmr();
        last_tcp += COUNTS_PER_SECOND / 4U;
    }
    if (now - last_arp >= COUNTS_PER_SECOND) {
        etharp_tmr();
#if IP_REASSEMBLY
        ip_reass_tmr();
#endif
        last_arp += COUNTS_PER_SECOND;
    }
    if (now - last_health >= COUNTS_PER_SECOND / 10U) {
        xemacpsif_resetrx_on_no_rxdata(&board_netif);
        last_health = now;
    }
    if (now - last_link >= COUNTS_PER_SECOND && (!keys_blocked || !keys_blocked())) {
        eth_link_detect(&board_netif);
        last_link = now;
    }
    flush_streams();
    polling = 0;
}
void rx_network_set_foreground(void (*service)(void), int (*blocked)(void))
{ foreground = service; keys_blocked = blocked; }
int rx_network_take_request(char *command, u32 *ticket)
{
    if (!control || !request_ready || frame_len || tcp_sndbuf(control) != TCP_SND_BUF) return 0;
    strcpy(command, request); *ticket = control_ticket; request_ready = 0U;
    return 1;
}
unsigned char *rx_network_frame(void) { return frame; }
void rx_network_reply(u32 ticket, u32 length)
{
    if (!control || ticket != control_ticket || length > sizeof(frame)) return;
    frame_len = length; frame_sent = 0U;
}
int rx_network_queue_key(char key)
{
    if (key_in - key_out >= KEY_BYTES) return -1;
    keys[key_in++ % KEY_BYTES] = key; return 0;
}
u32 rx_network_link_mbps(void)
{
    struct xemac_s *mac;
    xemacpsif_s *gem;
    if (!active || !netif_is_link_up(&board_netif)) return 0U;
    mac = (struct xemac_s *)board_netif.state;
    gem = (xemacpsif_s *)mac->state;
    return XEmacPs_GetOperatingSpeed(&gem->emacps);
}
u32 rx_network_log_overruns(void) { return log_overruns; }
/* Override BSP character I/O: all existing xil_printf/printf output and
 * inbyte users are accessible on TCP without modifying RF business code. */
void outbyte(char ch)
{
    static unsigned count;
    XUartPs_SendByte(XPAR_PS7_UART_1_BASEADDR, (u8)ch);
    log_ring[log_write++ % LOG_BYTES] = ch;
    if (ch == '\n' || (++count & 63U) == 0U) rx_network_poll();
}
char inbyte(void)
{
    for (;;) {
        if (foreground && !foreground_running) {
            foreground_running = 1; foreground(); foreground_running = 0;
        }
        if (!keys_blocked || !keys_blocked()) {
            rx_network_poll();
            if (key_out != key_in) return keys[key_out++ % KEY_BYTES];
            if (XUartPs_IsReceiveData(XPAR_PS7_UART_1_BASEADDR))
                return (char)XUartPs_ReadReg(XPAR_PS7_UART_1_BASEADDR, XUARTPS_FIFO_OFFSET);
        }
    }
}
