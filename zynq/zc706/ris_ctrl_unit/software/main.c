#include "ris_controller.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xuartps_hw.h"
#include "xtime_l.h"
#ifdef RIS_ENABLE_NETWORK
#include "ris_network.h"
#include "ris_protocol.h"
#endif

/* JTAG mailbox ABI, all 32-bit words. Cache is disabled for debugger visibility.
 * Write command, then a new request_seq; wait until ack_seq equals request_seq.
 * Commands: 1=all low, 2=all high, 3=blink, 4=status, 5=OE off, 6=OE on.
 * This reports command execution and internal mirrors, never physical Q readback. */
typedef struct {
    u32 magic, abi, ready, request_seq, command, ack_seq, result;
    u32 pattern, frame_lo, frame_hi, status, errors;
    u32 image[13];
} ris_mailbox_t;

volatile ris_mailbox_t ris_mailbox = { .magic = 0x52495331u, .abi = 1u };
static ris_controller controller;
static int pattern;
static u32 blink;
static XTime last_toggle;

static void snapshot(int rc)
{
    u64 frames = ris_frame_count(&controller);
    u32 n;
    ris_mailbox.result = (u32)rc;
    ris_mailbox.pattern = (u32)pattern;
    ris_mailbox.frame_lo = (u32)frames;
    ris_mailbox.frame_hi = (u32)(frames >> 32);
    ris_mailbox.status = ris_read(&controller, RIS_REG_STATUS);
    ris_mailbox.errors = ris_read(&controller, RIS_REG_ERROR_FLAGS);
    for (n = 0u; n < 13u; ++n)
        ris_mailbox.image[n] = ris_read(&controller, RIS_REG_IMAGE + n * 4u);
    __asm__ volatile ("dmb sy" ::: "memory");
}

static void report(int rc)
{
    snapshot(rc);
    xil_printf("RIS rc=%d pattern=%s status=%08x errors=%08x frames=%u\r\n",
               rc, pattern ? "HIGH" : "LOW", ris_mailbox.status,
               ris_mailbox.errors, ris_mailbox.frame_lo);
}

static int set_pattern(int high)
{
    int rc = ris_set_all(&controller, high);
    if (rc == RIS_OK) {
        pattern = high;
        rc = ris_output_enable(&controller, 1);
    }
    if (rc != RIS_OK) {
        blink = 0;
        (void)ris_output_enable(&controller, 0);
    }
    return rc;
}

static int execute(u32 command)
{
    switch (command) {
    case 1u: blink = 0; return set_pattern(0);
    case 2u: blink = 0; return set_pattern(1);
    case 3u:
        XTime_GetTime(&last_toggle);
        blink = 1000;
        return RIS_OK;
    case 4u: return RIS_OK;
    case 5u: blink = 0; return ris_output_enable(&controller, 0);
    case 6u: return ris_output_enable(&controller, 1);
    default: return -7;
    }
}

static void help(void)
{
    xil_printf("0: all 400 LOW; 1: all 400 HIGH; b: 1-second toggle; s: status\r\n"
               "d: disable outputs (high-Z); e: enable; h: help\r\n"
               "HIGH/LOW are electrical levels; no external Q feedback is fitted.\r\n");
}

int main(void)
{
    int rc;
    Xil_DCacheDisable();
    Xil_ICacheEnable();
    xil_printf("\r\nRIS ZC706 board v1 / AXI4 / 50 x 595 / 400 outputs\r\n");
    rc = ris_initialize(&controller, RIS_BASE_ADDRESS);
    report(rc);
    if (rc != RIS_OK) {
        ris_mailbox.ready = 0xdead0001u;
        xil_printf("Initialization failed. Check status/errors and reset.\r\n");
        for (;;) { }
    }
    help();
#ifdef RIS_ENABLE_NETWORK
    rc=ris_network_init();
    xil_printf("RIS network rc=%d TCP %s:%u\r\n",rc,RIS_NET_ADDRESS,RIS_NET_PORT);
#endif
    ris_mailbox.ready = 1u;
    for (;;) {
        XTime now;
#ifdef RIS_ENABLE_NETWORK
        static u32 previous_session;
        char line[RIS_NET_REQUEST_BYTES],reply[512];
        u32 session;
        ris_network_poll();
        session=ris_network_session();
        if (session!=previous_session) {
            blink=0; (void)ris_fast_stop(&controller); ris_mt_cancel_upload(&controller); previous_session=session;
        }
        if (ris_network_take(line,&session)) {
            if (ris_protocol_execute(&controller,line,reply,sizeof(reply),&blink))
                XTime_GetTime(&last_toggle);
            pattern=ris_read(&controller,RIS_REG_IMAGE)==0xffffffffu;
            ris_network_reply(session,reply);
            snapshot(0);
        }
#endif
        u32 request = ris_mailbox.request_seq;
        if (request != ris_mailbox.ack_seq) {
            __asm__ volatile ("dmb sy" ::: "memory");
            rc = execute(ris_mailbox.command);
            report(rc);
            ris_mailbox.ack_seq = request;
        }
        if (XUartPs_IsReceiveData(XPAR_PS7_UART_1_BASEADDR)) {
            u32 action = 0u;
            char c = (char)XUartPs_ReadReg(XPAR_PS7_UART_1_BASEADDR, XUARTPS_FIFO_OFFSET);
            switch (c) {
            case '0': action = 1u; break;
            case '1': action = 2u; break;
            case 'b': case 'B': action = 3u; break;
            case 's': case 'S': action = 4u; break;
            case 'd': case 'D': action = 5u; break;
            case 'e': case 'E': action = 6u; break;
            case '\r': case '\n': break;
            default: help(); break;
            }
            if (action != 0u) report(execute(action));
        }
        XTime_GetTime(&now);
        if (blink && now - last_toggle >= ((u64)COUNTS_PER_SECOND*blink)/1000u) {
            last_toggle = now;
            report(set_pattern(!pattern));
        }
    }
}
