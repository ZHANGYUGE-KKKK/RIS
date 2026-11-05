/* Official ADI receive core behind PS GP1 AXI-Lite. */
#include "rx_9361.h"
#include <string.h>
#include "xil_io.h"
#include "sleep.h"
#include "xtime_l.h"

#define RX_9361_RSTN 0x0040U
#define RX_9361_CONTROL 0x0044U
#define RX_9361_STATUS 0x005CU
#define RX_9361_CH_CONTROL(n) (0x0400U + 0x40U * (n))
#define RX_9361_CH_STATUS(n) (0x0404U + 0x40U * (n))
#define RX_9361_CH_PN_SELECT(n) (0x0418U + 0x40U * (n))
#define RX_9361_DELAY(n) (0x0800U + 4U * (n))
#define RX_9361_COUNTER_MASK 0x00FFFFFFU

int rx_9361_init(rx_9361_device *dev)
{
    XTime started, now;
    u32 channel;
    if (dev == NULL) return RX_9361_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    dev->base_address = RX_9361_BASEADDR;
    if (Xil_In32(dev->base_address + RX_9361_SIGNATURE_REG) != RX_9361_SIGNATURE)
        return RX_9361_ERR_CONFIG;
    dev->version = Xil_In32(dev->base_address);
    if (dev->version == 0U || dev->version == 0xFFFFFFFFU)
        return RX_9361_ERR_CONFIG;
    Xil_Out32(dev->base_address + RX_9361_CONTROL, 0U); /* 2R2T */
    Xil_Out32(dev->base_address + RX_9361_RSTN, 3U);
    for (channel = 0U; channel < RX_9361_CHANNELS; ++channel) {
        Xil_Out32(dev->base_address + RX_9361_CH_CONTROL(channel), 1U);
        /* AD9361 RX BIST: PN9 (0) selects the device-specific I/Q sequence.
         * PN_CUSTOM (9) checks the FPGA TX core's standard PRBS instead. */
        Xil_Out32(dev->base_address + RX_9361_CH_PN_SELECT(channel), 0U);
        Xil_Out32(dev->base_address + RX_9361_CH_STATUS(channel), RX_9361_PN_MASK);
    }
    XTime_GetTime(&started);
    do {
        if (Xil_In32(dev->base_address + RX_9361_DELAY(0U)) != 0xFFFFFFFFU) break;
        XTime_GetTime(&now);
        if (now - started > (XTime)COUNTS_PER_SECOND / 10U)
            return RX_9361_ERR_TIMEOUT;
        usleep(10U);
    } while (1);
    dev->ready = 1U;
    dev->interface_status = Xil_In32(dev->base_address + RX_9361_STATUS);
    return RX_9361_OK;
}
int rx_9361_set_delay(rx_9361_device *dev, u32 lane, u32 taps)
{
    u32 readback;
    if (dev == NULL || lane >= 7U || taps > 31U) return RX_9361_ERR_ARGUMENT;
    if (!dev->ready) return RX_9361_ERR_CONFIG;
    Xil_Out32(dev->base_address + RX_9361_DELAY(lane), taps);
    readback = Xil_In32(dev->base_address + RX_9361_DELAY(lane));
    if (readback != taps) return RX_9361_ERR_CONFIG;
    dev->delay_taps[lane] = (u8)taps;
    return RX_9361_OK;
}
int rx_9361_set_uniform_delay(rx_9361_device *dev, u32 data_taps, u32 frame_taps)
{
    u32 lane;
    int status;
    for (lane = 0U; lane < 7U; ++lane) {
        status = rx_9361_set_delay(dev, lane, lane == 6U ? frame_taps : data_taps);
        if (status != RX_9361_OK) return status;
    }
    return RX_9361_OK;
}
int rx_9361_check_pn(rx_9361_device *dev, u32 observe_us)
{
    u32 before_samples, before_edges, channel, errors = 0U;
    if (dev == NULL || observe_us < 100U || observe_us > 1000000U)
        return RX_9361_ERR_ARGUMENT;
    if (!dev->ready) return RX_9361_ERR_CONFIG;
    /* Allow the receiver and PN monitors to acquire before clearing latches. */
    usleep(100U);
    for (channel = 0U; channel < RX_9361_CHANNELS; ++channel)
        Xil_Out32(dev->base_address + RX_9361_CH_STATUS(channel), RX_9361_PN_MASK);
    before_samples = Xil_In32(dev->base_address + RX_9361_SAMPLE_COUNTER);
    before_edges = Xil_In32(dev->base_address + RX_9361_EDGE_COUNTER);
    usleep(observe_us);
    dev->sample_delta = (Xil_In32(dev->base_address + RX_9361_SAMPLE_COUNTER) - before_samples) & RX_9361_COUNTER_MASK;
    dev->edge_delta = (Xil_In32(dev->base_address + RX_9361_EDGE_COUNTER) - before_edges) & RX_9361_COUNTER_MASK;
    dev->interface_status = Xil_In32(dev->base_address + RX_9361_STATUS);
    for (channel = 0U; channel < RX_9361_CHANNELS; ++channel) {
        dev->channel_status[channel] = Xil_In32(dev->base_address + RX_9361_CH_STATUS(channel));
        errors |= dev->channel_status[channel] & RX_9361_PN_MASK;
    }
    if (dev->sample_delta < 32U || dev->edge_delta < 128U)
        return RX_9361_ERR_NO_DATA;
    if (errors || !(dev->interface_status & 1U)) return RX_9361_ERR_PN;
    return RX_9361_OK;
}
const char *rx_9361_status_string(int status)
{
    switch (status) {
    case RX_9361_OK: return "OK";
    case RX_9361_ERR_ARGUMENT: return "invalid argument";
    case RX_9361_ERR_CONFIG: return "core configuration/readback failed";
    case RX_9361_ERR_TIMEOUT: return "IDELAY calibration timeout";
    case RX_9361_ERR_PN: return "PN data mismatch/out of sync";
    case RX_9361_ERR_NO_DATA: return "no valid receive data";
    default: return "unknown error";
    }
}
