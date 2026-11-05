/* RX LVDS -> RTL XPM FIFO -> AXIS Data FIFO -> AXI DMA SG S2MM -> MIG. */
#include "dma_9361.h"

#include <string.h>
#include "xparameters.h"
#include "xstatus.h"
#include "xtime_l.h"
#include "xpseudo_asm.h"

#ifndef XPAR_AXI_DMA_0_DEVICE_ID
#error "Regenerate the key_ctrl BSP from the XSA containing axi_dma_0."
#endif

#define DMA_9361_RESET_US   10000U
#define DMA_9361_POLL_LIMIT 1000000U
static void (*service_hook)(void);
static dma_diag_record last_debug;
const dma_diag_record *dma_9361_last_debug(void) { return &last_debug; }
void dma_9361_set_service_hook(void (*service)(void)) { service_hook = service; }

typedef char dma_9361_sample_must_be_eight_bytes[
    sizeof(dma_9361_sample) == DMA_9361_SAMPLE_BYTES ? 1 : -1];

static u32 dma_status(dma_9361_device *dev)
{
    dev->last_dma_status = XAxiDma_ReadReg(dev->dma.RegBase,
                              XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
    return dev->last_dma_status;
}

static int reset_dma(dma_9361_device *dev)
{
    XTime start, now;
    u32 polls;
    const XTime timeout = (XTime)COUNTS_PER_SECOND * DMA_9361_RESET_US
                         / 1000000U;

    XAxiDma_Reset(&dev->dma);
    XTime_GetTime(&start);
    for (polls = 0U; polls < DMA_9361_POLL_LIMIT; ++polls) {
        if (XAxiDma_ResetIsDone(&dev->dma)) {
            XAxiDma_IntrDisable(&dev->dma, XAXIDMA_IRQ_ALL_MASK,
                               XAXIDMA_DEVICE_TO_DMA);
            return DMA_9361_OK;
        }
        XTime_GetTime(&now);
        if (now - start >= timeout)
            break;
    }
    dev->ready = 0U;
    return DMA_9361_ERR_TIMEOUT;
}

static int capture_status(dma_9361_device *dev)
{
    if (gpio_9361_get_status(dev->capture, &dev->last_capture_status)
        != GPIO_9361_OK)
        return DMA_9361_ERR_NOT_READY;
    if (dev->last_capture_status & GPIO_9361_ERROR_MASK)
        return DMA_9361_ERR_CAPTURE;
    return DMA_9361_OK;
}

static void save_debug(dma_9361_device *dev, int result)
{
    dma_diag_record *d = &dev->debug;
    d->control = XAxiDma_ReadReg(dev->dma.RegBase, XAXIDMA_RX_OFFSET + XAXIDMA_CR_OFFSET);
    d->status = XAxiDma_ReadReg(dev->dma.RegBase, XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
    d->current = XAxiDma_ReadReg(dev->dma.RegBase, XAXIDMA_RX_OFFSET + XAXIDMA_CDESC_OFFSET);
    d->tail = XAxiDma_ReadReg(dev->dma.RegBase, XAXIDMA_RX_OFFSET + XAXIDMA_TDESC_OFFSET);
    d->result = result;
    if (d->issues && d->address) {
        const volatile u32 *raw = (const volatile u32 *)(UINTPTR)d->address;
        u32 i;
        dsb();
        for (i = 0U; i < 16U; ++i) {
            d->repeat[i] = raw[i];
            if (d->repeat[i] != d->raw[i]) d->changed_words |= 1U << i;
        }
        dsb();
    }
    last_debug = *d;
}

static u32 inspect_bd(dma_9361_device *dev, XAxiDma_Bd *bd, u32 index, u32 receiving)
{
    dma_diag_record *d = &dev->debug;
    const volatile u32 *raw = (const volatile u32 *)bd;
    u32 i;
    d->index = index;
    d->address = (u32)(UINTPTR)bd;
    d->expected_next = (u32)dev->bd_base + (index + 1U == dev->packet_count ? 0U : (index + 1U) * 64U);
    d->expected_buffer = (u32)dev->buffer_base + index * DMA_9361_PACKET_BYTES;
    d->max_length = XAxiDma_GetRxRing(&dev->dma)->MaxTransferLen;
    dsb();
    for (i = 0U; i < 16U; ++i) d->raw[i] = raw[i];
    dsb();
    d->issues = dma_diag_check(d->raw, d->expected_next, d->expected_buffer,
                              index, DMA_9361_PACKET_BYTES, d->max_length, receiving);
    return d->issues;
}

static int inspect_chain(dma_9361_device *dev, u32 stage)
{
    XAxiDma_BdRing *ring = XAxiDma_GetRxRing(&dev->dma);
    XAxiDma_Bd *bd = dev->bd_set;
    u32 i;
    dev->debug.stage = stage;
    for (i = 0U; i < dev->packet_count; ++i) {
        if (inspect_bd(dev, bd, i, 0U)) return -1;
        if (stage == DMA_DIAG_PREPARE) ++dev->debug.prepared_checked;
        else ++dev->debug.submitted_checked;
        bd = (XAxiDma_Bd *)XAxiDma_BdRingNext(ring, bd);
        if (service_hook && (i & 63U) == 63U) service_hook();
    }
    return 0;
}

static int fail(dma_9361_device *dev, int reason)
{
    int reset_status;

    /* Snapshot before XAxiDma_Reset, and preserve the original terminal
     * transfer record when rearm later calls abort on COMPLETE/FAILED. */
    if (dev->state != DMA_9361_COMPLETE && dev->state != DMA_9361_FAILED)
        save_debug(dev, reason);
    gpio_9361_release_arm(dev->capture);
    if (dev->started)
        dev->needs_pl_reset = 1U;
    reset_status = reset_dma(dev);
    dev->state = DMA_9361_FAILED;
    dev->last_error = reset_status == DMA_9361_OK ? reason : reset_status;
    return dev->last_error;
}

int dma_9361_init(dma_9361_device *dev, gpio_9361_device *capture)
{
    XAxiDma_Config *config;
    int status;

    if (dev == NULL || capture == NULL)
        return DMA_9361_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    dev->capture = capture;
    if (!capture->ready)
        return DMA_9361_ERR_NOT_READY;
    status = capture_status(dev);
    if (status != DMA_9361_OK)
        return status;
    if (capture->armed || (dev->last_capture_status & GPIO_9361_ACTIVE_MASK))
        return DMA_9361_ERR_RESET_REQUIRED;
    if (mig_ddr_init(&dev->memory) != MIG_DDR_OK)
        return DMA_9361_ERR_MEMORY;
    config = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_DEVICE_ID);
    if (config == NULL || config->BaseAddr != XPAR_AXI_DMA_0_BASEADDR ||
        !config->HasSg || !config->HasS2Mm || config->HasMm2S ||
        config->S2MmDataWidth != 64 || config->AddrWidth != 32 ||
        config->MicroDmaMode || config->S2MmNumChannels != 1 ||
        config->SgLengthWidth < 16)
        return DMA_9361_ERR_CONFIG;
    if (XAxiDma_CfgInitialize(&dev->dma, config) != XST_SUCCESS)
        return DMA_9361_ERR_CONFIG;
    status = reset_dma(dev);
    if (status != DMA_9361_OK)
        return status;
    dev->ready = 1U;
    dev->state = DMA_9361_IDLE;
    return DMA_9361_OK;
}

int dma_9361_prepare(dma_9361_device *dev, UINTPTR bd_base,
                     UINTPTR buffer_base, u32 packet_count)
{
    XAxiDma_BdRing *ring;
    XAxiDma_Bd template, *bd;
    u64 bd_bytes, buffer_bytes;
    u32 i;
    int status;

    if (dev == NULL || packet_count == 0U)
        return DMA_9361_ERR_ARGUMENT;
    if (!dev->ready)
        return DMA_9361_ERR_NOT_READY;
    if (dev->needs_pl_reset || dev->started)
        return DMA_9361_ERR_RESET_REQUIRED;
    if (dev->state != DMA_9361_IDLE)
        return DMA_9361_ERR_STATE;
    status = capture_status(dev);
    if (status != DMA_9361_OK)
        return status;
    if (dev->capture->armed || (dev->last_capture_status & GPIO_9361_ACTIVE_MASK))
        return DMA_9361_ERR_RESET_REQUIRED;
    bd_bytes = (u64)packet_count * XAXIDMA_BD_MINIMUM_ALIGNMENT;
    buffer_bytes = (u64)packet_count * DMA_9361_PACKET_BYTES;
    if (bd_bytes > 0xFFFFFFFFU || buffer_bytes > 0xFFFFFFFFU)
        return DMA_9361_ERR_ARGUMENT;
    if (mig_ddr_check_region(&dev->memory, bd_base, (u32)bd_bytes,
                            XAXIDMA_BD_MINIMUM_ALIGNMENT) != MIG_DDR_OK ||
        mig_ddr_check_region(&dev->memory, buffer_base, (u32)buffer_bytes,
                            MIG_DDR_ALIGNMENT) != MIG_DDR_OK ||
        ((u64)bd_base < (u64)buffer_base + buffer_bytes &&
         (u64)buffer_base < (u64)bd_base + bd_bytes))
        return DMA_9361_ERR_MEMORY;
    ring = XAxiDma_GetRxRing(&dev->dma);
    if (ring->MaxTransferLen < DMA_9361_PACKET_BYTES)
        return DMA_9361_ERR_CONFIG;
    if (mig_ddr_map_uncached(&dev->memory, bd_base, (u32)bd_bytes)
        != MIG_DDR_OK ||
        mig_ddr_prepare_rx(&dev->memory, buffer_base, (u32)buffer_bytes)
        != MIG_DDR_OK)
        return DMA_9361_ERR_MEMORY;
    dev->bd_base = bd_base;
    dev->buffer_base = buffer_base;
    dev->bd_bytes = (u32)bd_bytes;
    dev->buffer_bytes = (u32)buffer_bytes;
    dev->packet_count = packet_count;
    memset(&dev->debug, 0, sizeof(dev->debug));
    if (XAxiDma_BdRingCreate(ring, bd_base, bd_base,
                            XAXIDMA_BD_MINIMUM_ALIGNMENT, packet_count)
        != XST_SUCCESS)
        return fail(dev, DMA_9361_ERR_RING);
    XAxiDma_BdClear(&template);
    if (XAxiDma_BdRingClone(ring, &template) != XST_SUCCESS ||
        XAxiDma_BdRingSetCoalesce(ring, 1U, 0U) != XST_SUCCESS ||
        XAxiDma_BdRingAlloc(ring, packet_count, &dev->bd_set) != XST_SUCCESS)
        return fail(dev, DMA_9361_ERR_RING);
    bd = dev->bd_set;
    for (i = 0U; i < packet_count; ++i) {
        UINTPTR address = buffer_base + i * DMA_9361_PACKET_BYTES;
        if (XAxiDma_BdSetBufAddr(bd, address) != XST_SUCCESS ||
            XAxiDma_BdSetLength(bd, DMA_9361_PACKET_BYTES,
                               ring->MaxTransferLen) != XST_SUCCESS)
            return fail(dev, DMA_9361_ERR_RING);
        XAxiDma_BdSetCtrl(bd, 0U); /* TX SOF/EOF control bits do not apply. */
        XAxiDma_BdSetId(bd, i);
        bd = (XAxiDma_Bd *)XAxiDma_BdRingNext(ring, bd);
        if (service_hook && (i & 63U) == 63U) service_hook();
    }
    if (inspect_chain(dev, DMA_DIAG_PREPARE)) return fail(dev, DMA_9361_ERR_RING);
    dev->state = DMA_9361_PREPARED;
    return DMA_9361_OK;
}

int dma_9361_start(dma_9361_device *dev)
{
    XAxiDma_BdRing *ring;
    int status;

    if (dev == NULL)
        return DMA_9361_ERR_ARGUMENT;
    if (!dev->ready)
        return DMA_9361_ERR_NOT_READY;
    if (dev->needs_pl_reset || dev->started)
        return DMA_9361_ERR_RESET_REQUIRED;
    if (dev->state != DMA_9361_PREPARED)
        return DMA_9361_ERR_STATE;
    status = gpio_9361_check_ready(dev->capture);
    if (status != GPIO_9361_OK) {
        if (status == GPIO_9361_ERR_CAPTURE)
            return DMA_9361_ERR_CAPTURE;
        if (status == GPIO_9361_ERR_RESET_REQUIRED)
            return DMA_9361_ERR_RESET_REQUIRED;
        return DMA_9361_ERR_NOT_READY;
    }
    ring = XAxiDma_GetRxRing(&dev->dma);
    if (XAxiDma_BdRingToHw(ring, dev->packet_count, dev->bd_set) != XST_SUCCESS)
        return fail(dev, DMA_9361_ERR_DMA);
    /* Channel is still stopped: read back the complete submitted chain
     * before enabling hardware, so CPU/DDR/SG setup faults are distinguishable. */
    if (inspect_chain(dev, DMA_DIAG_SUBMIT)) return fail(dev, DMA_9361_ERR_RING);
    if (XAxiDma_BdRingStart(ring) != XST_SUCCESS) return fail(dev, DMA_9361_ERR_DMA);
    /* Set this conservatively before ARM, so a startup race/error cannot
     * permit reuse of potentially nonempty FIFOs without system reset.
     */
    dev->started = 1U;
    if (gpio_9361_arm(dev->capture) != GPIO_9361_OK)
        return fail(dev, DMA_9361_ERR_CAPTURE);
    dev->state = DMA_9361_RUNNING;
    return DMA_9361_OK;
}

int dma_9361_poll(dma_9361_device *dev)
{
    XAxiDma_BdRing *ring;
    XAxiDma_Bd *set, *bd;
    int count, i, status;

    if (dev == NULL)
        return DMA_9361_ERR_ARGUMENT;
    if (dev->state == DMA_9361_FAILED)
        return dev->last_error;
    if (!dev->ready)
        return DMA_9361_ERR_NOT_READY;
    if (dev->state == DMA_9361_COMPLETE)
        return DMA_9361_OK;
    if (dev->state != DMA_9361_RUNNING)
        return DMA_9361_ERR_STATE;
    if (dma_status(dev) & XAXIDMA_ERR_ALL_MASK)
        return fail(dev, DMA_9361_ERR_DMA);
    status = capture_status(dev);
    if (status != DMA_9361_OK)
        return fail(dev, status);
    ring = XAxiDma_GetRxRing(&dev->dma);
    count = XAxiDma_BdRingFromHw(ring, XAXIDMA_ALL_BDS, &set);
    bd = set;
    dev->debug.stage = DMA_DIAG_RECEIVE;
    for (i = 0; i < count; ++i) {
        u32 issues = inspect_bd(dev, bd, dev->completed_packets, 1U);
        /* Read status/length/address/ID once into PS memory, then validate
         * that same snapshot. BdGetSts intentionally masks out the length. */
        dev->last_bd_status = dev->debug.raw[7] & XAXIDMA_BD_STS_ALL_MASK;
        if (issues & DMA_DIAG_HWERROR)
            return fail(dev, DMA_9361_ERR_DMA);
        if (issues)
            return fail(dev, DMA_9361_ERR_PACKET);
        ++dev->debug.completed_checked;
        ++dev->completed_packets;
        dev->received_bytes += DMA_9361_PACKET_BYTES;
        bd = (XAxiDma_Bd *)XAxiDma_BdRingNext(ring, bd);
    }
    if (count && XAxiDma_BdRingFree(ring, count, set) != XST_SUCCESS)
        return fail(dev, DMA_9361_ERR_RING);
    if (dev->completed_packets != dev->packet_count)
        return DMA_9361_PENDING;
    if (dma_status(dev) & XAXIDMA_ERR_ALL_MASK)
        return fail(dev, DMA_9361_ERR_DMA);
    status = capture_status(dev);
    if (status != DMA_9361_OK)
        return fail(dev, status);
    if (mig_ddr_complete_rx(&dev->memory, dev->buffer_base, dev->buffer_bytes)
        != MIG_DDR_OK)
        return fail(dev, DMA_9361_ERR_MEMORY);
    gpio_9361_release_arm(dev->capture);
    dev->needs_pl_reset = 1U;
    dev->state = DMA_9361_COMPLETE;
    dev->debug.stage = DMA_DIAG_DONE;
    save_debug(dev, DMA_9361_OK);
    return DMA_9361_OK;
}

int dma_9361_wait(dma_9361_device *dev, u32 timeout_us)
{
    XTime start, now;
    XTime timeout;
    u32 polls;
    int status;

    if (dev == NULL || timeout_us == 0U)
        return DMA_9361_ERR_ARGUMENT;
    timeout = (XTime)COUNTS_PER_SECOND * timeout_us / 1000000U;
    XTime_GetTime(&start);
    for (polls = 0U; polls < DMA_9361_POLL_LIMIT; ++polls) {
        status = dma_9361_poll(dev);
        if (status != DMA_9361_PENDING)
            return status;
        XTime_GetTime(&now);
        if (now - start >= timeout)
            break;
        /* Keep the final ~2 ms free of network work so a post-window FIFO
         * tail cannot hide the completed window behind a late status poll. */
        if (service_hook && (polls & 127U) == 0U &&
            dev->packet_count - dev->completed_packets > 8U) service_hook();
    }
    return fail(dev, DMA_9361_ERR_TIMEOUT);
}

int dma_9361_abort(dma_9361_device *dev)
{
    if (dev == NULL)
        return DMA_9361_ERR_ARGUMENT;
    if (!dev->ready)
        return DMA_9361_ERR_NOT_READY;
    return fail(dev, DMA_9361_ERR_ABORTED);
}

int dma_9361_quiesce(dma_9361_device *dev)
{
    if (!dev || !dev->ready || dev->state != DMA_9361_COMPLETE)
        return DMA_9361_ERR_STATE;
    dsb();
    return reset_dma(dev);
}

int dma_9361_get_samples(const dma_9361_device *dev,
                         const dma_9361_sample **samples, u32 *sample_count)
{
    if (samples != NULL)
        *samples = NULL;
    if (sample_count != NULL)
        *sample_count = 0U;
    if (dev == NULL || samples == NULL || sample_count == NULL)
        return DMA_9361_ERR_ARGUMENT;
    if (!dev->ready)
        return DMA_9361_ERR_NOT_READY;
    if (dev->state != DMA_9361_COMPLETE)
        return DMA_9361_ERR_STATE;
    *samples = (const dma_9361_sample *)dev->buffer_base;
    *sample_count = dev->received_bytes / DMA_9361_SAMPLE_BYTES;
    return DMA_9361_OK;
}

const char *dma_9361_status_string(int status)
{
    switch (status) {
    case DMA_9361_OK: return "OK";
    case DMA_9361_PENDING: return "capture in progress";
    case DMA_9361_ERR_ARGUMENT: return "invalid argument or size overflow";
    case DMA_9361_ERR_NOT_READY: return "DMA/GPIO or RX/FRAME not ready";
    case DMA_9361_ERR_CONFIG: return "DMA BSP configuration mismatch";
    case DMA_9361_ERR_MEMORY: return "MIG range/alignment/overlap error";
    case DMA_9361_ERR_STATE: return "invalid DMA lifecycle state";
    case DMA_9361_ERR_RING: return "SG descriptor ring operation failed";
    case DMA_9361_ERR_DMA: return "DMA or descriptor hardware error";
    case DMA_9361_ERR_CAPTURE: return "capture overflow/FRAME/IDELAY error";
    case DMA_9361_ERR_PACKET: return "IQ packet length/order/SOF/EOF mismatch";
    case DMA_9361_ERR_TIMEOUT: return "DMA transfer or reset timed out";
    case DMA_9361_ERR_RESET_REQUIRED: return "reset PL/FIFOs before another capture";
    case DMA_9361_ERR_ABORTED: return "DMA aborted; partial capture invalid";
    default: return "unknown error";
    }
}
