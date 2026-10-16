/* RFMC6000 7035 spi_ctrl.c table, TI SCAS931G sections 8.4.5.2/8.5/9.2.2.9.
 * CDCM framing differs from AD9361: READ=1, 11-bit address, 16-bit data.
 * Each command/data pair stays in one continuous 32-clock CS assertion.
 */
#include "cdcm6208.h"

#include <string.h>
#include "sleep.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xpseudo_asm.h"
#include "xspips_hw.h"
#include "xstatus.h"
#include "xtime_l.h"

#define CDCM6208_TRANSFER_US 20000U
#define CDCM6208_POLL_LIMIT  1000000U
#define CDCM6208_LOCK_MS     5000U
#define CDCM6208_LOCK_READS  8U
#define CDCM6208_CONTROL    0x10F0U

/* R4: manual primary (0x206C) instead of the example's pin-qualified
 * selection (0x306C). This removes dependence on the absent REF_SELECT2.
 * R21 is read-only and is deliberately omitted from the write table.
 */
static const u16 cdcm6208_profile[21] = {
    0x01B1U, 0x0000U, 0x003BU, CDCM6208_CONTROL, 0x206CU,
    0x01B8U, 0x000EU, 0x0000U, 0x0014U, 0x2000U,
    0x0000U, 0x0000U, 0x2052U, 0x0000U, 0x0000U,
    0x0000U, 0x0000U, 0x0000U, 0x0000U, 0x0000U, 0x0000U
};

volatile cdcm6208_report_type cdcm6208_report;

static void spi_release(cdcm6208_device *dev)
{
    u32 base = dev->spi.Config.BaseAddress;
    u32 control = XSpiPs_ReadReg(base, XSPIPS_CR_OFFSET);
    XSpiPs_WriteReg(base, XSPIPS_CR_OFFSET,
                   (control & ~XSPIPS_CR_MANSTRT_MASK) | XSPIPS_CR_SSCTRL_MASK);
    XSpiPs_Disable(&dev->spi);
}

static int spi_transfer(cdcm6208_device *dev, const u8 tx[4], u8 rx[4])
{
    XTime start, now;
    const XTime timeout = (XTime)COUNTS_PER_SECOND * CDCM6208_TRANSFER_US / 1000000U;
    u32 base, control, status, polls = 0U, count = 0U, i;
    int result = CDCM6208_OK;

    if (!dev->spi_ready)
        return CDCM6208_ERR_NOT_READY;
    base = dev->spi.Config.BaseAddress;
    spi_release(dev);
    for (i = 0U; i < XSPIPS_FIFO_DEPTH; ++i) {
        if (!(XSpiPs_ReadReg(base, XSPIPS_SR_OFFSET) & XSPIPS_IXR_RXNEMPTY_MASK))
            break;
        (void)XSpiPs_ReadReg(base, XSPIPS_RXD_OFFSET);
    }
    XSpiPs_WriteReg(base, XSPIPS_SR_OFFSET, XSPIPS_IXR_WR_TO_CLR_MASK);
    XSpiPs_Enable(&dev->spi);
    control = XSpiPs_ReadReg(base, XSPIPS_CR_OFFSET);
    control &= ~(XSPIPS_CR_SSCTRL_MASK | XSPIPS_CR_MANSTRT_MASK);
    control |= dev->spi.SlaveSelect;
    XSpiPs_WriteReg(base, XSPIPS_CR_OFFSET, control);
    usleep(2U);
    for (i = 0U; i < 4U; ++i)
        XSpiPs_WriteReg(base, XSPIPS_TXD_OFFSET, tx[i]);
    XTime_GetTime(&start);
    XSpiPs_WriteReg(base, XSPIPS_CR_OFFSET, control | XSPIPS_CR_MANSTRT_MASK);
    while (count < 4U) {
        status = XSpiPs_ReadReg(base, XSPIPS_SR_OFFSET);
        dev->last_spi_status = status;
        cdcm6208_report.last_spi_status = status;
        if (status & (XSPIPS_IXR_MODF_MASK | XSPIPS_IXR_RXOVR_MASK)) {
            result = CDCM6208_ERR_SPI;
            break;
        }
        if (status & XSPIPS_IXR_RXNEMPTY_MASK)
            rx[count++] = (u8)XSpiPs_ReadReg(base, XSPIPS_RXD_OFFSET);
        if (count == 4U)
            break;
        XTime_GetTime(&now);
        if (now - start >= timeout || ++polls >= CDCM6208_POLL_LIMIT) {
            result = CDCM6208_ERR_TIMEOUT;
            break;
        }
    }
    if (result == CDCM6208_OK)
        usleep(2U);
    spi_release(dev);
    usleep(2U);
    if (result != CDCM6208_OK) {
        dev->spi_ready = 0U;
        dev->ready = 0U;
    }
    return result;
}

int cdcm6208_reg_read(cdcm6208_device *dev, u16 reg, u16 *value)
{
    u8 tx[4], rx[4];
    u16 command;
    int status;
    if (dev == NULL || value == NULL || reg > 0x7FFU)
        return CDCM6208_ERR_ARGUMENT;
    dev->last_register = reg;
    cdcm6208_report.last_register = reg;
    command = 0x8000U | reg;
    tx[0] = (u8)(command >> 8); tx[1] = (u8)command;
    tx[2] = 0U; tx[3] = 0U;
    status = spi_transfer(dev, tx, rx);
    if (status == CDCM6208_OK)
        *value = ((u16)rx[2] << 8) | rx[3];
    return status;
}

int cdcm6208_reg_write(cdcm6208_device *dev, u16 reg, u16 value)
{
    u8 tx[4], rx[4];
    if (dev == NULL || reg > 20U)
        return CDCM6208_ERR_ARGUMENT;
    dev->ready = 0U;
    dev->last_register = reg;
    cdcm6208_report.last_register = reg;
    tx[0] = (u8)(reg >> 8); tx[1] = (u8)reg;
    tx[2] = (u8)(value >> 8); tx[3] = (u8)value;
    return spi_transfer(dev, tx, rx);
}

int cdcm6208_check_lock(cdcm6208_device *dev)
{
    u16 value;
    int status;
    if (dev == NULL)
        return CDCM6208_ERR_ARGUMENT;
    status = cdcm6208_reg_read(dev, CDCM6208_REG_STATUS, &value);
    if (status != CDCM6208_OK)
        return status;
    dev->clock_status = value;
    cdcm6208_report.clock_status = value;
    if ((value & CDCM6208_STATUS_MASK) != 0U) {
        dev->ready = 0U;
        return CDCM6208_ERR_LOCK;
    }
    return CDCM6208_OK;
}

static int wait_lock(cdcm6208_device *dev)
{
    XTime start, now;
    u32 polls, stable = 0U;
    int status;
    XTime_GetTime(&start);
    for (polls = 0U; polls < CDCM6208_LOCK_MS; ++polls) {
        status = cdcm6208_check_lock(dev);
        ++cdcm6208_report.lock_polls;
        if (status != CDCM6208_OK && status != CDCM6208_ERR_LOCK)
            return status;
        stable = status == CDCM6208_OK ? stable + 1U : 0U;
        if (stable == CDCM6208_LOCK_READS)
            return CDCM6208_OK;
        XTime_GetTime(&now);
        if (now - start >= (XTime)COUNTS_PER_SECOND * CDCM6208_LOCK_MS / 1000U)
            break;
        usleep(1000U);
    }
    return CDCM6208_ERR_LOCK;
}

int cdcm6208_init(cdcm6208_device *dev)
{
    XSpiPs_Config *config;
    XTime start, now;
    u16 value, first = 0U;
    u32 reg, i;
    int status = CDCM6208_ERR_CONTROLLER;

    if (dev == NULL)
        return CDCM6208_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    memset((void *)&cdcm6208_report, 0, sizeof(cdcm6208_report));
    cdcm6208_report.magic = 0x4344434DU; /* CDCM */
    cdcm6208_report.result = CDCM6208_ERR_NOT_READY;
    XTime_GetTime(&start);
    cdcm6208_report.stage = 1U;
    config = XSpiPs_LookupConfig(XPAR_PS7_SPI_1_DEVICE_ID);
    if (config == NULL || config->BaseAddress != XPAR_PS7_SPI_1_BASEADDR)
        goto finished;
    if (XSpiPs_CfgInitialize(&dev->spi, config, config->BaseAddress) != XST_SUCCESS ||
        XSpiPs_SetOptions(&dev->spi, XSPIPS_MASTER_OPTION |
                          XSPIPS_FORCE_SSELECT_OPTION | XSPIPS_MANUAL_START_OPTION) != XST_SUCCESS ||
        XSpiPs_SetClkPrescaler(&dev->spi, XSPIPS_CLK_PRESCALE_256) != XST_SUCCESS ||
        XSpiPs_SetSlaveSelect(&dev->spi, 0U) != XST_SUCCESS)
        goto finished;
    /* Single master: the SS IOBUF returns our own chip-select level. */
    XSpiPs_WriteReg(config->BaseAddress, XSPIPS_CR_OFFSET,
                   XSpiPs_ReadReg(config->BaseAddress, XSPIPS_CR_OFFSET) & ~XSPIPS_CR_MODF_GEN_EN_MASK);
    XSpiPs_WriteReg(config->BaseAddress, XSPIPS_IDR_OFFSET, 0x7FU);
    XSpiPs_WriteReg(config->BaseAddress, XSPIPS_RXWR_OFFSET, 1U);
    dev->spi_ready = 1U;
    dev->spi_clk_hz = config->InputClockHz / 256U;
    cdcm6208_report.spi_clk_hz = dev->spi_clk_hz;
    spi_release(dev);
    xil_printf("\r\nCDCM6208: SPI1 EMIO @0x%08x, SS0 mode 0, %d Hz\r\n",
               (unsigned int)config->BaseAddress, (unsigned int)dev->spi_clk_hz);
    xil_printf("CDCM6208: primary 10 MHz TCXO -> Y1 40 MHz; register SYNCN\r\n");
    cdcm6208_report.stage = 2U;
    for (i = 0U; i < 8U; ++i) {
        status = cdcm6208_reg_read(dev, CDCM6208_REG_ID, &value);
        if (status != CDCM6208_OK)
            goto finished;
        dev->identity = value;
        cdcm6208_report.identity = value;
        /* This divider table is for CDCM6208V1 production silicon. */
        if ((value & 0x3FU) != 0x02U || (i != 0U && value != first)) {
            status = CDCM6208_ERR_ID;
            goto finished;
        }
        first = value;
    }
    xil_printf("CDCM6208 ONLINE: R40=0x%04x, 8 stable V1 identity reads\r\n", (unsigned int)value);
    cdcm6208_report.stage = 3U;
    status = cdcm6208_reg_write(dev, 3U, 0x10B0U); /* reset asserted */
    if (status != CDCM6208_OK)
        goto finished;
    usleep(1000U);
    for (reg = 0U; reg < 21U; ++reg) {
        value = reg == 3U ? 0x10B0U : cdcm6208_profile[reg];
        status = cdcm6208_reg_write(dev, (u16)reg, value);
        if (status != CDCM6208_OK)
            goto finished;
        ++cdcm6208_report.written_registers;
    }
    status = cdcm6208_reg_write(dev, 3U, CDCM6208_CONTROL); /* calibrate/release */
    if (status != CDCM6208_OK)
        goto finished;
    cdcm6208_report.stage = 4U;
    for (reg = 0U; reg < 21U; ++reg) {
        status = cdcm6208_reg_read(dev, (u16)reg, &value);
        if (status != CDCM6208_OK)
            goto finished;
        cdcm6208_report.registers[reg] = value;
        cdcm6208_report.expected = cdcm6208_profile[reg];
        cdcm6208_report.actual = value;
        if (value != cdcm6208_profile[reg]) {
            status = CDCM6208_ERR_READBACK;
            goto finished;
        }
        ++cdcm6208_report.checked_registers;
    }
    xil_printf("CDCM6208: 21 configuration registers read back correctly\r\n");
    cdcm6208_report.stage = 5U;
    status = wait_lock(dev);
    if (status != CDCM6208_OK)
        goto finished;
    cdcm6208_report.stage = 6U;
    usleep(10000U);
    status = cdcm6208_reg_write(dev, 3U, CDCM6208_CONTROL & ~0x0020U);
    if (status != CDCM6208_OK)
        goto finished;
    usleep(10000U);
    status = cdcm6208_reg_write(dev, 3U, CDCM6208_CONTROL);
    if (status != CDCM6208_OK)
        goto finished;
    usleep(500000U);
    status = cdcm6208_reg_read(dev, 3U, &value);
    if (status == CDCM6208_OK && value != CDCM6208_CONTROL)
        status = CDCM6208_ERR_READBACK;
    if (status != CDCM6208_OK)
        goto finished;
    cdcm6208_report.sync_done = 1U;
    cdcm6208_report.stage = 7U;
    status = wait_lock(dev);
    if (status == CDCM6208_OK)
        dev->ready = 1U;
finished:
    XTime_GetTime(&now);
    cdcm6208_report.elapsed_ms = (u32)((now - start) / (COUNTS_PER_SECOND / 1000U));
    cdcm6208_report.result = status;
    dsb(); cdcm6208_report.done = 1U; dsb();
    xil_printf("CDCM6208 %s: stage=%d R21=0x%04x ID=0x%04x result=%d (%s), %d ms\r\n",
               status == CDCM6208_OK ? "PASS" : "FAILED", (unsigned int)cdcm6208_report.stage,
               (unsigned int)dev->clock_status, (unsigned int)dev->identity,
               status, cdcm6208_status_string(status), (unsigned int)cdcm6208_report.elapsed_ms);
    if (status != CDCM6208_OK)
        xil_printf("CDCM6208 diagnostic: reg=%d expected=0x%04x actual=0x%04x SPI=0x%08x\r\n",
                   (unsigned int)dev->last_register, (unsigned int)cdcm6208_report.expected,
                   (unsigned int)cdcm6208_report.actual, (unsigned int)dev->last_spi_status);
    return status;
}

void cdcm6208_close(cdcm6208_device *dev)
{
    if (dev != NULL) {
        if (dev->spi_ready)
            spi_release(dev);
        dev->spi_ready = 0U;
        dev->ready = 0U;
    }
}

const char *cdcm6208_status_string(int status)
{
    switch (status) {
    case CDCM6208_OK: return "OK";
    case CDCM6208_ERR_ARGUMENT: return "invalid register/argument";
    case CDCM6208_ERR_NOT_READY: return "SPI1 not initialized";
    case CDCM6208_ERR_CONTROLLER: return "SPI1 configuration failed";
    case CDCM6208_ERR_TIMEOUT: return "SPI1 transfer timed out";
    case CDCM6208_ERR_SPI: return "SPI1 mode fault or RX overrun";
    case CDCM6208_ERR_ID: return "stable CDCM6208V1 production ID not detected";
    case CDCM6208_ERR_READBACK: return "configuration register readback mismatch";
    case CDCM6208_ERR_LOCK: return "PLL unlocked, reference missing or secondary selected";
    default: return "unknown error";
    }
}
