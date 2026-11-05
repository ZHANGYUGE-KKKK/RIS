#ifndef RX_9361_H
#define RX_9361_H
#include "xil_types.h"
#ifdef __cplusplus
extern "C" {
#endif
#define RX_9361_BASEADDR 0x82000000U
#define RX_9361_CHANNELS 4U
#define RX_9361_PN_MASK 0x06U
#define RX_9361_SIGNATURE 0x41445258U
#define RX_9361_SAMPLE_COUNTER 0x1000U
#define RX_9361_EDGE_COUNTER 0x1004U
#define RX_9361_SIGNATURE_REG 0x1008U
#define RX_9361_FRAME_FAULT_COUNTER 0x100CU
#define RX_9361_FRAME_RISE_COUNTER 0x1010U
#define RX_9361_UNLOCKED_COUNTER 0x1014U
#define RX_9361_DELAY_NOT_READY_COUNTER 0x1018U
#define RX_9361_DIAGNOSTIC_VERSION_REG 0x101CU
#define RX_9361_DIAGNOSTIC_VERSION 0x00010001U
#define RX_9361_FRAME_PAIR_COUNTER(n) (0x1020U + 4U * (n))
#define RX_9361_MONITOR_WINDOWS 50U

enum rx_9361_status {
    RX_9361_OK = 0,
    RX_9361_ERR_ARGUMENT = -1,
    RX_9361_ERR_CONFIG = -2,
    RX_9361_ERR_TIMEOUT = -3,
    RX_9361_ERR_PN = -4,
    RX_9361_ERR_NO_DATA = -5,
    RX_9361_ERR_UNSTABLE = -6
};
typedef struct {
    UINTPTR base_address;
    u32 version;
    u32 interface_status;
    u32 channel_status[RX_9361_CHANNELS];
    u32 sample_delta;
    u32 edge_delta;
    u8 delay_taps[7];
    u8 ready;
} rx_9361_device;
/* Fixed-width words keep the report directly readable through XSDB mrd. */
typedef struct {
    u32 elapsed_ticks_low, elapsed_ticks_high;
    u32 samples, clocks, frame_rises, frame_faults, unlocked_cycles;
    u32 delay_not_ready_cycles, frame_pairs[4];
    u32 sample_hz, clock_hz, frame_hz, ratio_error, frame_sample_error;
    u32 interface_status, channel_status[4];
} rx_9361_monitor_window;
typedef struct {
    u32 magic, done;
    s32 result;
    u32 pn_enabled, completed_windows, requested_windows, interval_us;
    u32 timer_hz, elapsed_us, sample_hz_min, sample_hz_max;
    u32 clock_hz_min, clock_hz_max, frame_hz_min, frame_hz_max;
    u32 worst_ratio_error, worst_frame_sample_error, no_progress_windows;
    u32 unlocked_windows, rate_error_windows, pn_error_windows;
    u32 pn_channel_error_windows[4], frame_fault_total, unlocked_cycle_total;
    u32 delay_not_ready_total;
    rx_9361_monitor_window window[RX_9361_MONITOR_WINDOWS];
} rx_9361_monitor_report;
/* Official ADI RX registers, raw IQ with filter/format/IQ correction bypass.
 * Reinitialize after every FCLK0 fabric reset. ARM/DMA must remain stopped
 * during initialization, delay tuning and PN tests. GPIO interface-status
 * bit alone is not a data-integrity verdict; require a passing PN test.
 */
int rx_9361_init(rx_9361_device *dev);
int rx_9361_set_delay(rx_9361_device *dev, u32 lane, u32 taps);
int rx_9361_set_uniform_delay(rx_9361_device *dev, u32 data_taps, u32 frame_taps);
/* Requires AD9361 RX PRBS injection, configured separately over SPI. */
int rx_9361_check_pn(rx_9361_device *dev, u32 observe_us);
/* >=5 seconds: 50 independent 100 ms windows, measured with 64-bit CPU time.
 * No SPI writes, ARM changes or fabric resets. PN mode assumes injection has
 * already been enabled and counts failing observation windows, not bit errors.
 */
int rx_9361_monitor(rx_9361_device *dev, u32 pn_enabled,
                    volatile rx_9361_monitor_report *report);
const char *rx_9361_status_string(int status);
#ifdef __cplusplus
}
#endif
#endif
