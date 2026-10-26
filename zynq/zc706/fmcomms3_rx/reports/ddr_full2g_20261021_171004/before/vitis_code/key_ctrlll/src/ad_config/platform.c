/* RFMC6000 reference-driver hooks for this project's proven PS SPI0 driver.
 * No SPI1, AXI ADC registers, or extra EMIO pins are accessed here.
 */
#include "platform.h"
#include "ad_config_port.h"

#include <string.h>
#include "sleep.h"

static ad9361_device *radio_transport;

static int record_error(int error)
{
    if (ad_config_report.io_error == 0)
        ad_config_report.io_error = error;
    return error;
}

int ad_config_port_bind(ad9361_device *transport)
{
    radio_transport = NULL;
    if (transport == NULL || !transport->spi_ready || !transport->gpio_ready ||
        !transport->reset_done || !transport->online)
        return record_error(-ENODEV);
    radio_transport = transport;
    return 0;
}

int ad_config_port_error(void)
{
    return ad_config_report.io_error;
}

void ad_config_port_calibration(u32 reg, u32 mask, s32 value)
{
    ad_config_report.wait_reg = reg;
    ad_config_report.wait_mask = mask;
    ad_config_report.wait_value = value;
}

int spi_write_then_read(struct spi_device *spi,
                       const unsigned char *txbuf, unsigned n_tx,
                       unsigned char *rxbuf, unsigned n_rx)
{
    u8 tx[10] = {0};
    u8 rx[10] = {0};
    u32 instruction, count, bytes;
    int status;

    if (ad_config_report.io_error != 0)
        return ad_config_report.io_error;
    if (radio_transport == NULL || spi == NULL || spi->id_no != 0U)
        return record_error(-ENODEV);
    if (txbuf == NULL || n_tx < 2U || n_tx > sizeof(tx) ||
        n_rx > sizeof(tx) - n_tx || (n_rx != 0U && rxbuf == NULL))
        return record_error(-EINVAL);
    instruction = ((u32)txbuf[0] << 8) | txbuf[1];
    count = ((instruction >> 12) & 7U) + 1U;
    bytes = n_tx + n_rx;
    if (bytes != count + 2U ||
        ((instruction & 0x8000U) != 0U ?
         (n_rx != 0U || n_tx != count + 2U) : (n_tx != 2U || n_rx != count)))
        return record_error(-EINVAL);
    memcpy(tx, txbuf, n_tx);
    radio_transport->last_register = (u16)(instruction & 0x3FFU);
    ad_config_report.last_reg = radio_transport->last_register;
    status = ad9361_spi_transfer(radio_transport, tx, rx, bytes);
    if (status != AD9361_OK)
        return record_error(status == AD9361_ERR_TIMEOUT ? -ETIMEDOUT : -EIO);
    if (n_rx != 0U) {
        memcpy(rxbuf, rx + n_tx, n_rx);
        ad_config_report.spi_reads += n_rx;
        ad_config_report.last_value = rx[n_tx];
    } else {
        ad_config_report.spi_writes += n_tx - 2U;
        ad_config_report.last_value = tx[2];
    }
    return 0;
}

bool gpio_is_valid(int number)
{
    return radio_transport != NULL && number == (int)AD9361_RESET_GPIO_PIN;
}

void gpio_set_value(unsigned gpio, int value)
{
    u32 actual;

    if (!gpio_is_valid((int)gpio) || (value != 0 && value != 1)) {
        (void)record_error(-EINVAL);
        return;
    }
    /* Even an error must not leave the radio held in reset. */
    XGpioPs_WritePin(&radio_transport->gpio, gpio, (u32)value);
    usleep(2U);
    actual = XGpioPs_ReadPin(&radio_transport->gpio, gpio);
    radio_transport->online = 0U;
    if (value == 0)
        radio_transport->reset_low_readback = (u8)actual;
    else
        radio_transport->reset_high_readback = (u8)actual;
    if (actual != (u32)value)
        (void)record_error(-EIO);
}

void udelay(unsigned long usecs)
{
    usleep(usecs);
}

void mdelay(unsigned long msecs)
{
    while (msecs-- != 0U)
        usleep(1000U);
}

unsigned long msleep_interruptible(unsigned int msecs)
{
    mdelay(msecs);
    return 0U;
}
