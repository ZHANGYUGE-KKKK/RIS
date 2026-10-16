/* Volatile diagnostic harness. Calls the existing, unmodified application's
 * SPI/GPIO/DMA/reset functions at ELF-verified addresses. No FPGA rebuild.
 * PN failure is never treated as a passing capture. Incomplete DMA payload is
 * retained only as diagnostic evidence, not as an accepted sample window. */
#include "drivers/ad9361.h"
#include "drivers/gpio_9361.h"
#include "drivers/dma_9361.h"
#include "drivers/rx_9361.h"

#define RADIO ((ad9361_device *)0x00148030U)
#define CAPTURE ((gpio_9361_device *)0x001480b4U)
#define RECEIVER ((dma_9361_device *)0x001480ccU)
#define RX ((rx_9361_device *)0x00148868U)
#define RESET ((int (*)(u32))0x0011d1a8U)
#define READ ((typeof(&ad9361_reg_read))0x00100c48U)
#define WRITE ((typeof(&ad9361_reg_write))0x00100d04U)
#define GPIO_INIT ((typeof(&gpio_9361_init))0x00103498U)
#define DMA_INIT ((typeof(&dma_9361_init))0x00102554U)
#define DMA_PREPARE ((typeof(&dma_9361_prepare))0x0010274cU)
#define DMA_START ((typeof(&dma_9361_start))0x00102becU)
#define DMA_WAIT ((typeof(&dma_9361_wait))0x00103114U)
#define PN_CHECK ((typeof(&rx_9361_check_pn))0x00104648U)
#define SLEEP ((void (*)(u32))0x00124ed8U)
#define MAP ((void (*)(u32,u32))0x001247bcU)
#define FLUSH ((void (*)(void))0x001242acU)
#define REG(a) (*(volatile u32 *)(a))

struct report {
    u32 magic, mode, packets, gate, stage, done;
    s32 result, restore_result;
    u32 saved_bist, saved_observe, saved_mask;
    s32 reset_result, gpio_result, dma_init_result, prepare_result;
    s32 start_result, wait_result, pn_result;
    u32 start_attempts, pre_flags, post_flags, dma_status, bd_status;
    u32 completed_packets, received_bytes, driver_state;
    u32 samples_before, samples_after, edges_before, edges_after;
    u32 pn_status[4];
    u32 written_tuples, prefix_tuples, malformed_components, period_errors;
    s32 minimum[4], maximum[4];
    u32 restored_bist, restored_observe, restored_mask;
};
volatile struct report diagnostic_report __attribute__((section(".report")));

static void snapshot(void)
{
    volatile struct report *r = &diagnostic_report;
    r->post_flags = REG(0x80020008U);
    r->dma_status = RECEIVER->last_dma_status;
    r->bd_status = RECEIVER->last_bd_status;
    r->completed_packets = RECEIVER->completed_packets;
    r->received_bytes = RECEIVER->received_bytes;
    r->driver_state = RECEIVER->state;
    r->samples_after = REG(0x82001000U);
    r->edges_after = REG(0x82001004U);
    for (u32 i = 0; i < 4; ++i) r->pn_status[i] = RX->channel_status[i];
}

int diag_run(u32 mode, u32 packets)
{
    MAP(0x02100000U, 0x11de2U); /* report/gate must be visible to JTAG */
    volatile struct report *r = &diagnostic_report;
    for (u32 i = 0; i < sizeof(*r)/4; ++i) ((volatile u32 *)r)[i] = 0;
    r->magic = 0x46524354U; r->mode = mode; r->packets = packets;
    r->result = -999; r->start_result = -999; r->wait_result = -999;
    r->pn_result = -999;
    u8 value;
    r->stage = 1;
    if (READ(RADIO,0x3f4,&value)) return r->result = -101;
    r->saved_bist = value;
    if (READ(RADIO,0x3f5,&value)) return r->result = -102;
    r->saved_observe = value;
    if (READ(RADIO,0x3f6,&value)) return r->result = -103;
    if (packets == 0 || packets > 256 || mode > 2) return r->result = -104;
    r->saved_mask = value;
    if ((r->reset_result = RESET(1U))) return r->result = -105;
    r->stage = 2;
    if (mode != 0) {
        if (WRITE(RADIO,0x3f4,0) || WRITE(RADIO,0x3f5,0) ||
            WRITE(RADIO,0x3f6,0) || WRITE(RADIO,0x3f4,mode == 1 ? 0x5b : 0x09))
            return r->result = -106;
    }
    if ((r->reset_result = RESET(0U))) return r->result = -107;
    r->stage = 3;
    if ((r->gpio_result = GPIO_INIT(CAPTURE))) return r->result = -108;
    if ((r->dma_init_result = DMA_INIT(RECEIVER,CAPTURE))) return r->result = -109;
    if (mode == 2) {
        r->pn_result = PN_CHECK(RX,100000U);
        snapshot(); r->result = r->pn_result;
        r->stage = 100; r->done = 1; FLUSH(); return r->result;
    }
    r->stage = 4;
    if ((r->prepare_result = DMA_PREPARE(RECEIVER,0x40000000U,0x40100000U,packets)))
        return r->result = -110;
    /* Sentinel is outside the sign-extended 12-bit range. */
    volatile u32 *buffer = (volatile u32 *)0x40100000U;
    u32 words = packets * 32768U / 4U;
    for (u32 i = 0; i < words; ++i) buffer[i] = 0x5a5a5a5aU;
    __asm__ volatile("dsb" ::: "memory");
    r->pre_flags = REG(0x80020008U);
    r->samples_before = REG(0x82001000U); r->edges_before = REG(0x82001004U);
    r->stage = 7;
    while (!r->gate) SLEEP(1000U); /* host arms ILA before releasing gate */
    r->stage = 8;
    for (u32 i = 0; i < 1000; ++i) {
        r->start_attempts = i + 1;
        r->start_result = DMA_START(RECEIVER);
        if (r->start_result != DMA_9361_ERR_NOT_READY) break;
    }
    r->stage = 9;
    if (r->start_result == DMA_9361_OK) r->wait_result = DMA_WAIT(RECEIVER,1000000U);
    r->result = r->start_result ? r->start_result : r->wait_result;
    snapshot();
    r->stage = 10;
    u32 prefix = 1;
    for (u32 c = 0; c < 4; ++c) {r->minimum[c] = 32767; r->maximum[c] = -32768;}
    for (u32 n = 0; n < words/2; ++n) {
        if (buffer[2*n] == 0x5a5a5a5aU && buffer[2*n+1] == 0x5a5a5a5aU) {
            prefix = 0; continue;
        }
        ++r->written_tuples;
        if (prefix) ++r->prefix_tuples;
        for (u32 c = 0; c < 4; ++c) {
            s16 v = ((volatile s16 *)buffer)[4*n+c];
            if (v < -2048 || v > 2047) ++r->malformed_components;
            if (v < r->minimum[c]) r->minimum[c] = v;
            if (v > r->maximum[c]) r->maximum[c] = v;
            if (mode == 1 && n >= 16 && prefix &&
                v != ((volatile s16 *)buffer)[4*(n&15)+c]) ++r->period_errors;
        }
    }
    r->stage = 100; r->done = 1; FLUSH();
    return r->result;
}

int diag_restore(void)
{
    volatile struct report *r = &diagnostic_report;
    int result = RESET(1U);
    if (WRITE(RADIO,0x3f4,0) || WRITE(RADIO,0x3f5,r->saved_observe) ||
        WRITE(RADIO,0x3f6,r->saved_mask) || WRITE(RADIO,0x3f4,r->saved_bist)) result = -1;
    if (RESET(0U) || GPIO_INIT(CAPTURE) || DMA_INIT(RECEIVER,CAPTURE)) result = -2;
    u8 value;
    if (READ(RADIO,0x3f4,&value)) result = -3;
    r->restored_bist = value;
    if (value != r->saved_bist) result = -4;
    if (READ(RADIO,0x3f5,&value)) result = -5;
    r->restored_observe = value;
    if (value != r->saved_observe) result = -6;
    if (READ(RADIO,0x3f6,&value)) result = -7;
    r->restored_mask = value;
    if (value != r->saved_mask) result = -8;
    r->restore_result = result; FLUSH();
    return result;
}
