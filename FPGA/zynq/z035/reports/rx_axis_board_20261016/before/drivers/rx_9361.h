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

enum rx_9361_status {
    RX_9361_OK = 0,
    RX_9361_ERR_ARGUMENT = -1,
    RX_9361_ERR_CONFIG = -2,
    RX_9361_ERR_TIMEOUT = -3,
    RX_9361_ERR_PN = -4,
    RX_9361_ERR_NO_DATA = -5
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
const char *rx_9361_status_string(int status);
#ifdef __cplusplus
}
#endif
#endif
