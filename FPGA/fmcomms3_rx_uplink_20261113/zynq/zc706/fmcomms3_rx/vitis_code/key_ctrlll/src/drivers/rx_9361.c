/* Official ADI receive core behind PS GP1 AXI-Lite. */
#include "rx_9361.h"
static void (*service_hook)(void);
void rx_9361_set_service_hook(void (*service)(void)) { service_hook = service; }
#include <string.h>
#include "xil_io.h"
#include "sleep.h"
#include "xtime_l.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xpseudo_asm.h"

#define RX_9361_RSTN 0x0040U
#define RX_9361_CONTROL 0x0044U
#define RX_9361_STATUS 0x005CU
#define RX_9361_CLOCK_MONITOR 0x0054U
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
    XTime started, now;
    if (dev == NULL || lane >= 7U || taps > 31U) return RX_9361_ERR_ARGUMENT;
    if (!dev->ready) return RX_9361_ERR_CONFIG;
    Xil_Out32(dev->base_address + RX_9361_DELAY(lane), taps);
    /* The new receiver loads IDELAYE2 on m_axis_aclk (100 MHz). Allow the
     * ADI register request/readback pipeline to complete before checking. */
    XTime_GetTime(&started);
    do {
        readback = Xil_In32(dev->base_address + RX_9361_DELAY(lane));
        if (readback == taps) break;
        XTime_GetTime(&now);
        if (now - started > (XTime)COUNTS_PER_SECOND / 1000U)
            return RX_9361_ERR_CONFIG;
    } while (1);
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
    /* DATA_CLK's 24-bit counter wraps in ~273 ms at 61.44 MHz. */
    if (dev == NULL || observe_us < 100U || observe_us > 200000U)
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
    if (dev->edge_delta + 128U < 4U * dev->sample_delta ||
        dev->edge_delta > 4U * dev->sample_delta + 128U)
        return RX_9361_ERR_UNSTABLE;
    if (errors || !(dev->interface_status & 1U)) return RX_9361_ERR_PN;
    return RX_9361_OK;
}

static void rx_9361_read_counters(rx_9361_device *dev, u32 values[10])
{
    u32 n;
    values[0] = Xil_In32(dev->base_address + RX_9361_SAMPLE_COUNTER);
    values[1] = Xil_In32(dev->base_address + RX_9361_EDGE_COUNTER);
    values[2] = Xil_In32(dev->base_address + RX_9361_FRAME_RISE_COUNTER);
    values[3] = Xil_In32(dev->base_address + RX_9361_FRAME_FAULT_COUNTER);
    values[4] = Xil_In32(dev->base_address + RX_9361_UNLOCKED_COUNTER);
    values[5] = Xil_In32(dev->base_address + RX_9361_DELAY_NOT_READY_COUNTER);
    for (n = 0U; n < 4U; ++n)
        values[6U+n] = Xil_In32(dev->base_address + RX_9361_FRAME_PAIR_COUNTER(n));
}

static XTime rx_9361_counter_snapshot(rx_9361_device *dev, u32 values[10])
{
    XTime begin, end;
    /* Keep Ethernet IRQ latency out of this multi-register measurement. */
    u32 saved_cpsr = mfcpsr();
    mtcpsr(saved_cpsr | 0x80U);
    XTime_GetTime(&begin);
    rx_9361_read_counters(dev, values);
    XTime_GetTime(&end);
    mtcpsr(saved_cpsr);
    /* Timestamp the middle of the ten-register read, so timer skew does not
     * include a whole MMIO transaction group at either end of the window. */
    return begin + (end - begin) / 2U;
}

int rx_9361_monitor(rx_9361_device *dev, u32 pn_enabled,
                    volatile rx_9361_monitor_report *report)
{
    u32 previous[10], current[10], delta[10], n, channel, interval;
    u32 bad_pn, bad_rate, ratio_error, frame_error, adi_clock_count;
    XTime started, before, now, ticks;
    const XTime window_ticks = ((XTime)COUNTS_PER_SECOND + 9U) / 10U;
    volatile rx_9361_monitor_window *window;
    int result = RX_9361_OK;
    if (dev == NULL || report == NULL || pn_enabled > 1U)
        return RX_9361_ERR_ARGUMENT;
    memset((void *)report, 0, sizeof(*report));
    report->magic = 0x52584D4FU; /* RXMO */
    report->result = RX_9361_ERR_CONFIG;
    report->pn_enabled = pn_enabled;
    report->requested_windows = RX_9361_MONITOR_WINDOWS;
    report->interval_us = 100000U;
    report->timer_hz = (u32)COUNTS_PER_SECOND;
    report->sample_hz_min = report->clock_hz_min = report->frame_hz_min = 0xFFFFFFFFU;
    if (!dev->ready || Xil_In32(dev->base_address + RX_9361_DIAGNOSTIC_VERSION_REG) !=
                        RX_9361_DIAGNOSTIC_VERSION)
        goto finished;
    if (pn_enabled) {
        usleep(1000U);
        for (channel = 0U; channel < 4U; ++channel)
            Xil_Out32(dev->base_address + RX_9361_CH_STATUS(channel), RX_9361_PN_MASK);
    }
    started = rx_9361_counter_snapshot(dev, previous);
    before = started;
    for (interval = 0U; interval < RX_9361_MONITOR_WINDOWS; ++interval) {
        window = &report->window[interval];
        memset(delta, 0, sizeof(delta));
        do {
            /* Accumulate modulo-24-bit deltas every ~1 ms. A single 100 ms
             * delta aliases above 167.77 MHz; these short subwindows also
             * cover 245.76 MHz and the observed extra-edge clock fault.
             * Use the CPU timer deadline: usleep(100000) alone can return
             * slightly early and make fifty windows shorter than 5 s. */
            usleep(1000U);
            if (service_hook) service_hook();
            now = rx_9361_counter_snapshot(dev, current);
            for (n = 0U; n < 10U; ++n) {
                delta[n] += (current[n] - previous[n]) & RX_9361_COUNTER_MASK;
                previous[n] = current[n];
            }
            ticks = now - before;
        } while (ticks < window_ticks);
        before = now;
        window->elapsed_ticks_low = (u32)ticks;
        window->elapsed_ticks_high = (u32)(ticks >> 32);
        window->samples = delta[0]; window->clocks = delta[1];
        window->frame_rises = delta[2]; window->frame_faults = delta[3];
        window->unlocked_cycles = delta[4]; window->delay_not_ready_cycles = delta[5];
        for (n = 0U; n < 4U; ++n) window->frame_pairs[n] = delta[6U+n];
        if (!ticks || !delta[0] || !delta[1] || !delta[2]) {
            ++report->no_progress_windows;
            result = RX_9361_ERR_NO_DATA;
        }
        if (ticks) {
            window->sample_hz = (u32)(((u64)delta[0] * COUNTS_PER_SECOND) / ticks);
            window->clock_hz = (u32)(((u64)delta[1] * COUNTS_PER_SECOND) / ticks);
            window->frame_hz = (u32)(((u64)delta[2] * COUNTS_PER_SECOND) / ticks);
        }
        if (window->sample_hz < report->sample_hz_min) report->sample_hz_min = window->sample_hz;
        if (window->sample_hz > report->sample_hz_max) report->sample_hz_max = window->sample_hz;
        if (window->clock_hz < report->clock_hz_min) report->clock_hz_min = window->clock_hz;
        if (window->clock_hz > report->clock_hz_max) report->clock_hz_max = window->clock_hz;
        if (window->frame_hz < report->frame_hz_min) report->frame_hz_min = window->frame_hz;
        if (window->frame_hz > report->frame_hz_max) report->frame_hz_max = window->frame_hz;
        ratio_error = delta[1] > 4U*delta[0] ? delta[1]-4U*delta[0] : 4U*delta[0]-delta[1];
        frame_error = delta[2] > delta[0] ? delta[2]-delta[0] : delta[0]-delta[2];
        window->ratio_error = ratio_error;
        window->frame_sample_error = frame_error;
        if (ratio_error > report->worst_ratio_error) report->worst_ratio_error = ratio_error;
        if (frame_error > report->worst_frame_sample_error) report->worst_frame_sample_error = frame_error;
        report->frame_fault_total += delta[3];
        report->unlocked_cycle_total += delta[4];
        report->delay_not_ready_total += delta[5];
        window->interface_status = Xil_In32(dev->base_address + RX_9361_STATUS);
        if (!(window->interface_status & 1U) || delta[3] || delta[4] || delta[5]) {
            ++report->unlocked_windows;
            result = RX_9361_ERR_UNSTABLE;
        }
        /* Frequency tolerance is 1%; independent MMIO reads allow 128 clocks
         * and 32 frames of skew in the exact ratio checks. */
        bad_rate = window->sample_hz < 15206400U || window->sample_hz > 15513600U ||
                   window->clock_hz < 60825600U || window->clock_hz > 62054400U ||
                   window->frame_hz < 15206400U || window->frame_hz > 15513600U ||
                   ratio_error > 128U || frame_error > 32U;
        if (bad_rate) { ++report->rate_error_windows; result = RX_9361_ERR_UNSTABLE; }
        bad_pn = 0U;
        for (channel = 0U; channel < 4U; ++channel) {
            window->channel_status[channel] = Xil_In32(dev->base_address + RX_9361_CH_STATUS(channel));
            if (pn_enabled && (window->channel_status[channel] & RX_9361_PN_MASK)) {
                ++report->pn_channel_error_windows[channel];
                bad_pn = 1U;
            }
            if (pn_enabled)
                Xil_Out32(dev->base_address + RX_9361_CH_STATUS(channel), RX_9361_PN_MASK);
        }
        if (bad_pn) { ++report->pn_error_windows; result = RX_9361_ERR_PN; }
        report->completed_windows = interval + 1U;
        report->elapsed_us = (u32)(((u64)(now-started) * 1000000U) / COUNTS_PER_SECOND);
        dsb();
        Xil_DCacheFlushRange((INTPTR)report, sizeof(*report));
    }
    report->result = result;
    /* Independent ADI clock monitor: 16 fractional ratio bits, referenced
     * to the unchanged 100 MHz AXI-Lite clock. This only reads the core. */
    adi_clock_count = Xil_In32(dev->base_address + RX_9361_CLOCK_MONITOR);
    xil_printf("[RX monitor] PN=%u ADI_CLKMON=0x%08x (%u Hz @100MHz AXI)\r\n",
               pn_enabled, adi_clock_count,
               (u32)(((u64)adi_clock_count * 100000000U) / 65536U));
finished:
    dsb(); report->done = 1U; dsb();
    Xil_DCacheFlushRange((INTPTR)report, sizeof(*report));
    return report->result;
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
    case RX_9361_ERR_UNSTABLE: return "receive clock/frame cadence unstable";
    default: return "unknown error";
    }
}
