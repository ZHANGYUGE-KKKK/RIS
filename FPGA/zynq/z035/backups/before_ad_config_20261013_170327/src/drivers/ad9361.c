/* RFMC6000 connectivity bring-up, based on ADI UG-570/UG-671 and the
 * RFMC6000 schematic/example supplied in /home/yyz/ALLdoc/RFMC6000.
 * Single-byte SPI framing: bit 15 = 1 for WRITE, 0 for READ; bits 9:0
 * contain the address. Each operation is one continuous 24-clock CS pulse.
 */
#include "ad9361.h"

#include <string.h>
#include "sleep.h"
#include "xparameters.h"
#include "xspips_hw.h"
#include "xstatus.h"
#include "xtime_l.h"

#define AD9361_ADDRESS_MAX       0x3FFU
#define AD9361_WRITE_COMMAND     0x8000U
#define AD9361_SPI_MODE_MASK     0xE7U /* Ignore reserved bits D4:D3. */
#define AD9361_TRANSFER_BYTES    3U
#define AD9361_ID_READ_COUNT     8U
#define AD9361_TIMEOUT_US        20000U
#define AD9361_POLL_LIMIT        1000000U /* Also bounds a stopped timer. */
#define AD9361_SPI_ERROR_MASK    (XSPIPS_IXR_MODF_MASK | XSPIPS_IXR_RXOVR_MASK)

static int gpio_initialize(ad9361_device *dev)
{
    XGpioPs_Config *config;

    config = XGpioPs_LookupConfig(XPAR_PS7_GPIO_0_DEVICE_ID);
    if (config == NULL)
        return AD9361_ERR_GPIO;
    if (XGpioPs_CfgInitialize(&dev->gpio, config, config->BaseAddr)
        != XST_SUCCESS)
        return AD9361_ERR_GPIO;

    /* Change only EMIO[0]. Preload high before enabling output to avoid an
     * accidental low pulse; the explicit pulse below matches the example.
     */
    XGpioPs_SetOutputEnablePin(&dev->gpio, AD9361_RESET_GPIO_PIN, 0U);
    XGpioPs_WritePin(&dev->gpio, AD9361_RESET_GPIO_PIN, 1U);
    XGpioPs_SetDirectionPin(&dev->gpio, AD9361_RESET_GPIO_PIN, 1U);
    XGpioPs_SetOutputEnablePin(&dev->gpio, AD9361_RESET_GPIO_PIN, 1U);
    if (XGpioPs_GetDirectionPin(&dev->gpio, AD9361_RESET_GPIO_PIN) != 1U ||
        XGpioPs_GetOutputEnablePin(&dev->gpio, AD9361_RESET_GPIO_PIN) != 1U)
        return AD9361_ERR_GPIO;
    dev->gpio_ready = 1U;
    return AD9361_OK;
}

static void spi_release(ad9361_device *dev);

int ad9361_reset(ad9361_device *dev)
{
    if (dev == NULL)
        return AD9361_ERR_ARGUMENT;
    if (!dev->gpio_ready)
        return AD9361_ERR_NOT_READY;
    if (dev->spi_ready)
        spi_release(dev); /* CS stays inactive throughout the reset pulse. */
    dev->online = 0U;
    dev->reset_done = 0U;
    dev->product_id = 0U;
    dev->spi_conf = 0U;

    XGpioPs_WritePin(&dev->gpio, AD9361_RESET_GPIO_PIN, 1U);
    usleep(1000U);
    XGpioPs_WritePin(&dev->gpio, AD9361_RESET_GPIO_PIN, 0U);
    usleep(1000U);
    dev->reset_low_readback =
        (u8)XGpioPs_ReadPin(&dev->gpio, AD9361_RESET_GPIO_PIN);
    /* Always release RESETB, including an unexpected low-phase readback. */
    XGpioPs_WritePin(&dev->gpio, AD9361_RESET_GPIO_PIN, 1U);
    usleep(1000U);
    dev->reset_high_readback =
        (u8)XGpioPs_ReadPin(&dev->gpio, AD9361_RESET_GPIO_PIN);
    if (dev->reset_high_readback != 1U)
        return AD9361_ERR_RESET_RELEASE;
    if (dev->reset_low_readback != 0U)
        return AD9361_ERR_RESET_ASSERT;
    dev->reset_done = 1U;
    return AD9361_OK;
}

static void spi_release(ad9361_device *dev)
{
    u32 base = dev->spi.Config.BaseAddress;
    u32 control = XSpiPs_ReadReg(base, XSPIPS_CR_OFFSET);

    control &= ~XSPIPS_CR_MANSTRT_MASK;
    XSpiPs_WriteReg(base, XSPIPS_CR_OFFSET,
                   control | XSPIPS_CR_SSCTRL_MASK);
    XSpiPs_Disable(&dev->spi);
}

/* XSpiPs_PolledTransfer has an unbounded FIFO wait in this BSP version.
 * Use the same controller configuration with a bounded, three-byte transfer.
 */
static int spi_transfer(ad9361_device *dev, const u8 tx[3], u8 rx[3])
{
    XTime start;
    XTime now;
    const XTime timeout = ((XTime)COUNTS_PER_SECOND * AD9361_TIMEOUT_US)
                          / 1000000U;
    u32 base;
    u32 control;
    u32 status;
    u32 polls = 0U;
    unsigned int count = 0U;
    unsigned int i;
    int result = AD9361_OK;

    if (dev == NULL || !dev->spi_ready)
        return AD9361_ERR_NOT_READY;

    base = dev->spi.Config.BaseAddress;
    spi_release(dev);
    /* Drain stale RX bytes; the controller has a 128-byte FIFO. */
    for (i = 0U; i < XSPIPS_FIFO_DEPTH; ++i) {
        if (!(XSpiPs_ReadReg(base, XSPIPS_SR_OFFSET)
              & XSPIPS_IXR_RXNEMPTY_MASK))
            break;
        (void)XSpiPs_ReadReg(base, XSPIPS_RXD_OFFSET);
    }
    XSpiPs_WriteReg(base, XSPIPS_SR_OFFSET, XSPIPS_IXR_WR_TO_CLR_MASK);
    XSpiPs_Enable(&dev->spi);
    control = XSpiPs_ReadReg(base, XSPIPS_CR_OFFSET);
    control &= ~(XSPIPS_CR_SSCTRL_MASK | XSPIPS_CR_MANSTRT_MASK);
    control |= dev->spi.SlaveSelect;
    XSpiPs_WriteReg(base, XSPIPS_CR_OFFSET, control);

    for (i = 0U; i < AD9361_TRANSFER_BYTES; ++i)
        XSpiPs_WriteReg(base, XSPIPS_TXD_OFFSET, tx[i]);

    XTime_GetTime(&start);
    XSpiPs_WriteReg(base, XSPIPS_CR_OFFSET,
                   control | XSPIPS_CR_MANSTRT_MASK);
    while (count < AD9361_TRANSFER_BYTES) {
        status = XSpiPs_ReadReg(base, XSPIPS_SR_OFFSET);
        dev->last_spi_status = status;
        if (status & AD9361_SPI_ERROR_MASK) {
            result = AD9361_ERR_SPI;
            break;
        }
        if (status & XSPIPS_IXR_RXNEMPTY_MASK)
            rx[count++] = (u8)XSpiPs_ReadReg(base, XSPIPS_RXD_OFFSET);
        if (count == AD9361_TRANSFER_BYTES)
            break;
        XTime_GetTime(&now);
        if ((now - start >= timeout) || (++polls >= AD9361_POLL_LIMIT)) {
            result = AD9361_ERR_TIMEOUT;
            break;
        }
    }

    /* At PCLK/256 (~651 kHz), leave a full clock period before releasing CS. */
    if (result == AD9361_OK)
        usleep(2U);
    spi_release(dev);
    if (result != AD9361_OK) {
        /* Do not reuse a controller with an incomplete transaction. Calling
         * the BSP's reset here would introduce another unbounded FIFO wait.
         */
        dev->spi_ready = 0U;
        dev->online = 0U;
    }
    usleep(2U);
    return result;
}

int ad9361_reg_read(ad9361_device *dev, u16 reg, u8 *value)
{
    u8 tx[3];
    u8 rx[3];
    int status;

    if (dev == NULL || value == NULL || reg > AD9361_ADDRESS_MAX)
        return AD9361_ERR_ARGUMENT;
    dev->last_register = reg;
    tx[0] = (u8)(reg >> 8); /* READ=0, byte count field=0 (one byte). */
    tx[1] = (u8)reg;
    tx[2] = 0U;
    status = spi_transfer(dev, tx, rx);
    if (status == AD9361_OK)
        *value = rx[2];
    return status;
}

int ad9361_reg_write(ad9361_device *dev, u16 reg, u8 value)
{
    u16 command;
    u8 tx[3];
    u8 rx[3];

    if (dev == NULL || reg > AD9361_ADDRESS_MAX)
        return AD9361_ERR_ARGUMENT;
    dev->last_register = reg;
    command = AD9361_WRITE_COMMAND | reg;
    tx[0] = (u8)(command >> 8);
    tx[1] = (u8)command;
    tx[2] = value;
    dev->online = 0U; /* Any register write invalidates the cached check. */
    return spi_transfer(dev, tx, rx);
}

int ad9361_check_online(ad9361_device *dev)
{
    unsigned int i;
    u8 first_id = 0U;
    u8 id;
    int status;

    if (dev == NULL)
        return AD9361_ERR_ARGUMENT;
    dev->online = 0U;
    for (i = 0U; i < AD9361_ID_READ_COUNT; ++i) {
        status = ad9361_reg_read(dev, AD9361_REG_PRODUCT_ID, &id);
        if (status != AD9361_OK)
            return status;
        dev->product_id = id;
        if ((id & AD9361_PRODUCT_ID_MASK) != AD9361_PRODUCT_ID)
            return AD9361_ERR_PRODUCT_ID;
        if (i == 0U)
            first_id = id;
        else if (id != first_id)
            return AD9361_ERR_UNSTABLE_ID;
        usleep(100U);
    }
    status = ad9361_reg_read(dev, AD9361_REG_SPI_CONF, &dev->spi_conf);
    if (status != AD9361_OK)
        return status;
    if ((dev->spi_conf & AD9361_SPI_MODE_MASK) != 0U)
        return AD9361_ERR_SPI_CONF;
    dev->online = 1U;
    return AD9361_OK;
}

int ad9361_init(ad9361_device *dev)
{
    XSpiPs_Config *config;
    int status;

    if (dev == NULL)
        return AD9361_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    config = XSpiPs_LookupConfig(XPAR_PS7_SPI_0_DEVICE_ID);
    if (config == NULL)
        return AD9361_ERR_CONTROLLER;
    if (XSpiPs_CfgInitialize(&dev->spi, config, config->BaseAddress)
        != XST_SUCCESS)
        return AD9361_ERR_CONTROLLER;
    status = XSpiPs_SetOptions(&dev->spi, XSPIPS_MASTER_OPTION |
                              XSPIPS_CLK_PHASE_1_OPTION |
                              XSPIPS_FORCE_SSELECT_OPTION |
                              XSPIPS_MANUAL_START_OPTION);
    if (status != XST_SUCCESS)
        return AD9361_ERR_CONTROLLER;
    /* Match the RFMC6000 example: CPOL=0, CPHA=1, no SS decoder, SS0. */
    if (XSpiPs_SetClkPrescaler(&dev->spi, XSPIPS_CLK_PRESCALE_256)
        != XST_SUCCESS || XSpiPs_SetSlaveSelect(&dev->spi, 0U)
        != XST_SUCCESS)
        return AD9361_ERR_CONTROLLER;
    /* Single master, as in the RFMC6000 example. The generated bidirectional
     * SS IOBUF feeds the pad back to SSIN; disable multi-master arbitration
     * so our own active-low chip select cannot generate a mode fault.
     */
    XSpiPs_WriteReg(config->BaseAddress, XSPIPS_CR_OFFSET,
                   XSpiPs_ReadReg(config->BaseAddress, XSPIPS_CR_OFFSET)
                   & ~XSPIPS_CR_MODF_GEN_EN_MASK);
    dev->spi_clk_hz = config->InputClockHz / 256U;
    dev->spi_ready = 1U;
    XSpiPs_WriteReg(config->BaseAddress, XSPIPS_IDR_OFFSET, 0x7FU);
    XSpiPs_WriteReg(config->BaseAddress, XSPIPS_RXWR_OFFSET, 1U);
    spi_release(dev);
    usleep(10000U);

    status = gpio_initialize(dev);
    if (status != AD9361_OK)
        return status;
    status = ad9361_reset(dev);
    if (status != AD9361_OK)
        return status;

    /* Use GPIO hardware reset, never the unreliable SPI reset fallback.
     * Set four-wire/MSB-first operation, leaving reserved D4:D3 clear. */
    status = ad9361_reg_write(dev, AD9361_REG_SPI_CONF, 0U);
    if (status != AD9361_OK)
        return status;
    usleep(1000U);
    return ad9361_check_online(dev);
}

void ad9361_close(ad9361_device *dev)
{
    if (dev != NULL) {
        if (dev->spi_ready)
            spi_release(dev);
        if (dev->gpio_ready)
            XGpioPs_WritePin(&dev->gpio, AD9361_RESET_GPIO_PIN, 1U);
        dev->spi_ready = 0U;
        dev->gpio_ready = 0U;
        dev->online = 0U;
    }
}

const char *ad9361_status_string(int status)
{
    switch (status) {
    case AD9361_OK: return "OK";
    case AD9361_ERR_ARGUMENT: return "invalid argument";
    case AD9361_ERR_NOT_READY: return "SPI or RESETB GPIO not initialized";
    case AD9361_ERR_CONTROLLER: return "SPI controller configuration failed";
    case AD9361_ERR_TIMEOUT: return "SPI transfer timed out";
    case AD9361_ERR_SPI: return "SPI mode fault or RX overrun";
    case AD9361_ERR_PRODUCT_ID: return "AD9361 product ID not detected";
    case AD9361_ERR_SPI_CONF: return "SPI configuration readback mismatch";
    case AD9361_ERR_UNSTABLE_ID: return "unstable product ID reads";
    case AD9361_ERR_GPIO: return "RESETB GPIO initialization failed";
    case AD9361_ERR_RESET_ASSERT: return "RESETB did not read low during reset";
    case AD9361_ERR_RESET_RELEASE: return "RESETB did not read high after release";
    default: return "unknown error";
    }
}
