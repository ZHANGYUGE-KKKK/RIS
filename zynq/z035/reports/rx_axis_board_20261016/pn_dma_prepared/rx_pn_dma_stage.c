/* End-to-end PN capture. Call only while RX BIST09 is active, after the
 * long PN test passes and board ILA confirms MIG calibration is complete.
 * This routine never writes AD9361 SPI registers. */
volatile struct {
    u32 magic, done, stage;
    s32 result, restore_status;
    u32 samples, bytes, completed_packets, dma_status, bd_status, capture_status;
    u32 sign_errors, iq_overlap_errors[2], pn_sequence_errors[2];
    u32 seed[2], saved_taps[7], first_words[16];
} rx_pn_dma_report;
static dma_9361_sample rx_pn_dma_snapshot[DMA_9361_PACKET_SAMPLES];

static u16 rx_pn_reverse12(u16 value)
{
    u32 bit;
    u16 result = 0U;
    for (bit = 0U; bit < 12U; ++bit)
        result |= ((value >> bit) & 1U) << (11U-bit);
    return result;
}

static u16 rx_pn_next(u16 state)
{
    u32 bit, feedback = ((state >> 1) ^ (state >> 2)) & 1U;
    for (bit = 4U; bit < 16U; ++bit) feedback ^= (state >> bit) & 1U;
    return (u16)((state << 1) | feedback);
}

static int rx_pn_validate_samples(const dma_9361_sample *samples, u32 count)
{
    u32 n, channel, component;
    u16 predicted[2] = {0U, 0U}, observed, i_word, q_reversed;
    s16 values[4];
        for (n = 0U; n < count; ++n) {
            memcpy(values, &samples[n], sizeof(values));
            for (component = 0U; component < 4U; ++component)
                if (values[component] < -2048 || values[component] > 2047)
                    ++rx_pn_dma_report.sign_errors;
            if (n < 8U) {
                rx_pn_dma_report.first_words[n*2U] = (u16)values[0] | ((u32)(u16)values[1] << 16);
                rx_pn_dma_report.first_words[n*2U+1U] = (u16)values[2] | ((u32)(u16)values[3] << 16);
            }
            for (channel = 0U; channel < 2U; ++channel) {
                i_word = (u16)values[channel*2U] & 0x0FFFU;
                q_reversed = rx_pn_reverse12((u16)values[channel*2U+1U] & 0x0FFFU);
                if ((i_word & 0xFFU) != (q_reversed >> 4))
                    ++rx_pn_dma_report.iq_overlap_errors[channel];
                observed = (u16)((i_word << 4) | (q_reversed & 0xFU));
                if (!n) {
                    rx_pn_dma_report.seed[channel] = observed;
                    predicted[channel] = observed;
                    if (!observed) ++rx_pn_dma_report.pn_sequence_errors[channel];
                } else {
                    predicted[channel] = rx_pn_next(predicted[channel]);
                    if (observed != predicted[channel])
                        ++rx_pn_dma_report.pn_sequence_errors[channel];
                }
            }
        }
        if (rx_pn_dma_report.sign_errors || rx_pn_dma_report.iq_overlap_errors[0] ||
            rx_pn_dma_report.iq_overlap_errors[1] || rx_pn_dma_report.pn_sequence_errors[0] ||
            rx_pn_dma_report.pn_sequence_errors[1]) return RX_9361_ERR_PN;
    return RX_9361_OK;
}

static void rx_pn_dma_publish(void)
{
    dsb();
    Xil_DCacheFlushRange((INTPTR)&rx_pn_dma_report, sizeof(rx_pn_dma_report));
}

static int rx_pn_dma_selftest(void)
{
    const dma_9361_sample *samples = NULL;
    u32 count = 0U, lane, have_payload = 0U;
    int result = DMA_9361_ERR_NOT_READY, restore_result = 0;
    memset((void *)&rx_pn_dma_report, 0, sizeof(rx_pn_dma_report));
    rx_pn_dma_report.magic = 0x52585044U; /* RXPD */
    rx_pn_dma_report.result = result;
    rx_pn_dma_report.stage = 1U;
    for (lane = 0U; lane < 7U; ++lane) {
        rx_pn_dma_report.saved_taps[lane] = Xil_In32(RX_9361_BASEADDR + 0x800U + 4U*lane);
        if (rx_pn_dma_report.saved_taps[lane] > 31U) goto finished;
    }
    rx_pn_dma_publish();
    xil_printf("RX PN DMA: one4096-tuple SGpacket,32768bytes; RXBIST remains09\r\n");
    result = dma_9361_init(&receiver, &capture);
    if (result != DMA_9361_OK) goto restore;
    rx_pn_dma_report.stage = 2U;
    rx_pn_dma_publish();
    result = dma_9361_prepare(&receiver, DMA_9361_DEFAULT_BD_BASE,
                              DMA_9361_DEFAULT_BUFFER, 1U);
    if (result != DMA_9361_OK) goto restore;
    rx_pn_dma_report.stage = 3U;
    rx_pn_dma_publish();
    result = dma_9361_start(&receiver);
    if (result != DMA_9361_OK) goto restore;
    result = dma_9361_wait(&receiver, 100000U);
    rx_pn_dma_report.dma_status = receiver.last_dma_status;
    rx_pn_dma_report.bd_status = receiver.last_bd_status;
    rx_pn_dma_report.capture_status = receiver.last_capture_status;
    if (result != DMA_9361_OK) goto restore;
    result = dma_9361_get_samples(&receiver, &samples, &count);
    if (result != DMA_9361_OK) goto restore;
    rx_pn_dma_report.samples = count;
    rx_pn_dma_report.bytes = receiver.received_bytes;
    rx_pn_dma_report.completed_packets = receiver.completed_packets;
    if (count != DMA_9361_PACKET_SAMPLES || receiver.received_bytes != DMA_9361_PACKET_BYTES ||
        receiver.completed_packets != 1U) {
        result = DMA_9361_ERR_PACKET;
        goto restore;
    }
    /* Keep a PS-DDR copy before resetting the one-shot capture and FIFOs.
     * No subsequent DMA can overwrite the finite completed descriptor. */
    memcpy(rx_pn_dma_snapshot, samples, sizeof(rx_pn_dma_snapshot));
    have_payload = 1U;
restore:
    rx_pn_dma_report.stage = 4U;
    rx_pn_dma_publish();
    if (receiver.ready) (void)dma_9361_abort(&receiver);
    if (rf_capture_reset(1U) != 0) restore_result = -1;
    if (rf_capture_reset(0U) != 0) restore_result = -1;
    for (lane = 0U; lane < 7U; ++lane)
        if (rx_9361_set_delay(&rx_frontend, lane, rx_pn_dma_report.saved_taps[lane]) != RX_9361_OK)
            restore_result = -1;
    if (gpio_ris_init(&ris) != GPIO_RIS_OK || gpio_9361_init(&capture) != GPIO_9361_OK ||
        gpio_9361_wait_ready(&capture, 100000U) != GPIO_9361_OK)
        restore_result = -1;
    rx_pn_dma_report.restore_status = restore_result;
    if (have_payload) {
        rx_pn_dma_report.stage = 5U;
        result = rx_pn_validate_samples(rx_pn_dma_snapshot, count);
    }
    if (restore_result) result = RX_9361_ERR_CONFIG;
finished:
    rx_pn_dma_report.result = result;
    rx_pn_dma_report.stage = 6U;
    dsb(); rx_pn_dma_report.done = 1U; dsb();
    rx_pn_dma_publish();
    xil_printf("RX PN DMA %s: result=%d samples=%d bytes=%d sign=%d IQerr=%d/%d PNerr=%d/%d restore=%d; ARM=0\r\n",
               result == 0 ? "PASS" : "FAILED", result, (unsigned)rx_pn_dma_report.samples,
               (unsigned)rx_pn_dma_report.bytes, (unsigned)rx_pn_dma_report.sign_errors,
               (unsigned)rx_pn_dma_report.iq_overlap_errors[0], (unsigned)rx_pn_dma_report.iq_overlap_errors[1],
               (unsigned)rx_pn_dma_report.pn_sequence_errors[0], (unsigned)rx_pn_dma_report.pn_sequence_errors[1],
               restore_result);
    return result;
}

