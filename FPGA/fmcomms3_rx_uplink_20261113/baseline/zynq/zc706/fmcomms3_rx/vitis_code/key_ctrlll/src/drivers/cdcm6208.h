#ifndef CDCM6208_H
#define CDCM6208_H

#include "xspips.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CDCM6208_REFERENCE_HZ 40000000U
#define CDCM6208_REG_STATUS   21U
#define CDCM6208_REG_ID       40U
#define CDCM6208_STATUS_MASK  0x0007U

enum cdcm6208_status {
    CDCM6208_OK = 0,
    CDCM6208_ERR_ARGUMENT = -1,
    CDCM6208_ERR_NOT_READY = -2,
    CDCM6208_ERR_CONTROLLER = -3,
    CDCM6208_ERR_TIMEOUT = -4,
    CDCM6208_ERR_SPI = -5,
    CDCM6208_ERR_ID = -6,
    CDCM6208_ERR_READBACK = -7,
    CDCM6208_ERR_LOCK = -8
};

typedef struct {
    XSpiPs spi;
    u32 spi_clk_hz;
    u32 last_spi_status;
    u16 last_register;
    u16 identity;
    u16 clock_status;
    u8 spi_ready;
    u8 ready;
} cdcm6208_device;

/* All diagnostic fields are 32-bit and visible through XSDB in PS DDR. */
typedef struct {
    u32 magic, done;
    s32 result;
    u32 stage, identity, spi_clk_hz, last_register, last_spi_status;
    u32 written_registers, checked_registers, expected, actual;
    u32 clock_status, lock_polls, sync_done, elapsed_ms;
    u32 registers[21];
} cdcm6208_report_type;

extern volatile cdcm6208_report_type cdcm6208_report;

/* SPI1 EMIO / SS0, mode 0, MSB first, PCLK/256. Apply the RFMC6000 V1
 * profile (10 MHz TCXO -> Y1 40 MHz). Force primary selection through R4
 * and use software SYNCN R3.5; extra EMIO GPIOs are not required.
 * A floating/held-low physical SYNCN can still prevent output clocks.
 * Does not initialize/reset AD9361, arm capture or start DMA.
 */
int cdcm6208_init(cdcm6208_device *dev);
int cdcm6208_reg_read(cdcm6208_device *dev, u16 reg, u16 *value);
int cdcm6208_reg_write(cdcm6208_device *dev, u16 reg, u16 value);
int cdcm6208_check_lock(cdcm6208_device *dev);
void cdcm6208_close(cdcm6208_device *dev);
const char *cdcm6208_status_string(int status);

#ifdef __cplusplus
}
#endif
#endif
