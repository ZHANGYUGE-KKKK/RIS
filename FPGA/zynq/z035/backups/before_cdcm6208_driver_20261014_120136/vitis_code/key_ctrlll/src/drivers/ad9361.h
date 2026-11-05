#ifndef RFMC6000_AD9361_H
#define RFMC6000_AD9361_H

#include "xspips.h"
#include "xgpiops.h"

#ifdef __cplusplus
extern "C" {
#endif

#define AD9361_REG_SPI_CONF       0x000U
#define AD9361_REG_PRODUCT_ID     0x037U
#define AD9361_PRODUCT_ID_MASK    0xF8U
#define AD9361_PRODUCT_ID         0x08U
#define AD9361_REVISION_MASK      0x07U

/* Current XSA hardware contract: RESETB on PS GPIO EMIO[0] / FPGA T29.
 * XGpioPs uses absolute pin numbers: MIO[0:53], then EMIO[0:63].
 */
#define AD9361_RESET_EMIO_INDEX   0U
#define AD9361_RESET_GPIO_PIN     (54U + AD9361_RESET_EMIO_INDEX)

enum ad9361_status {
    AD9361_OK = 0,
    AD9361_ERR_ARGUMENT = -1,
    AD9361_ERR_NOT_READY = -2,
    AD9361_ERR_CONTROLLER = -3,
    AD9361_ERR_TIMEOUT = -4,
    AD9361_ERR_SPI = -5,
    AD9361_ERR_PRODUCT_ID = -6,
    AD9361_ERR_SPI_CONF = -7,
    AD9361_ERR_UNSTABLE_ID = -8,
    AD9361_ERR_GPIO = -9,
    AD9361_ERR_RESET_ASSERT = -10,
    AD9361_ERR_RESET_RELEASE = -11
};

typedef struct {
    XSpiPs spi;
    XGpioPs gpio;
    u32 spi_clk_hz;
    u32 last_spi_status;
    u16 last_register;
    u8 product_id;
    u8 spi_conf;
    u8 spi_ready;
    u8 gpio_ready;
    u8 online;
    u8 reset_done; /* FPGA-pad feedback checked; chip ID checked separately. */
    u8 reset_low_readback;
    u8 reset_high_readback;
} ad9361_device;

/* SPI0 EMIO/SS0 bring-up: mode 1, GPIO hardware reset, 4-wire/MSB-first,
 * then ID check. Requires RESETB routed to AD9361_RESET_EMIO_INDEX.
 * This is NOT a complete RF initialization: no LO, sample rate, bandwidth,
 * reference-clock setup, clock-chip setup or RF calibrations are performed.
 * Requires the matching bitstream and successful PS initialization first.
 * The caller exclusively owns SPI0 and the RESETB GPIO; APIs are blocking
 * and not thread-safe. RESETB is left high after initialization/close.
 */
int ad9361_init(ad9361_device *dev);
/* Commands RESETB high even on readback failure. A reset attempt invalidates
 * online; after success call check_online to establish a fresh ID check.
 */
int ad9361_reset(ad9361_device *dev);
int ad9361_check_online(ad9361_device *dev);
int ad9361_reg_read(ad9361_device *dev, u16 reg, u8 *value);
int ad9361_reg_write(ad9361_device *dev, u16 reg, u8 value);
/* One continuous-CS raw transaction for the reference no-OS driver.
 * 3..10 bytes: two command bytes plus up to eight register bytes.
 * Same bounded FIFO polling, mode 1 and SS0 as register read/write.
 */
int ad9361_spi_transfer(ad9361_device *dev, const u8 *tx, u8 *rx, u32 bytes);
void ad9361_close(ad9361_device *dev);
const char *ad9361_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
