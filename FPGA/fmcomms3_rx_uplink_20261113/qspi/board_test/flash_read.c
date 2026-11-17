#include "xqspips.h"
#include "xil_cache.h"
#include <stdint.h>
#include <string.h>

#define BLOCK 4096U
#define SIZE (32U * 1024U * 1024U)

static XQspiPs qspi;
static uint8_t tx[4U + BLOCK], rx[4U + BLOCK];
static volatile uint32_t *const status = (volatile uint32_t *)0x00200000U;
static uint8_t *const output = (uint8_t *)0x01000000U;

static void fail(uint32_t code)
{
    status[0] = 0xe000U + code;
    for (;;) {}
}

int main(void)
{
    Xil_DCacheDisable();
    Xil_ICacheDisable();
    XQspiPs_Config *hardware = XQspiPs_LookupConfig(0);
    if (!hardware || hardware->ConnectionMode != 2U) fail(1);
    if (XQspiPs_CfgInitialize(&qspi, hardware, hardware->BaseAddress)) fail(2);
    XQspiPs_SetOptions(&qspi, XQSPIPS_MANUAL_START_OPTION |
        XQSPIPS_FORCE_SSELECT_OPTION | XQSPIPS_HOLD_B_DRIVE_OPTION);
    XQspiPs_SetClkPrescaler(&qspi, XQSPIPS_CLK_PRESCALE_16);
    XQspiPs_SetLqspiConfigReg(&qspi, 0x6000016bU);
    XQspiPs_SetSlaveSelect(&qspi);
    tx[0] = 0x9f;
    if (XQspiPs_PolledTransfer(&qspi, tx, rx, 4U)) fail(3);
    status[2] = (uint32_t)rx[1] | (uint32_t)rx[2] << 8 | (uint32_t)rx[3] << 16;
    if (status[2] != 0x1860efU) fail(4);
    status[0] = 100;
    tx[0] = 0x03;
    memset(tx + 4U, 0, BLOCK);
    for (uint32_t offset = 0; offset < SIZE; offset += BLOCK) {
        uint32_t address = offset / 2U;
        tx[1] = (uint8_t)(address >> 16);
        tx[2] = (uint8_t)(address >> 8);
        tx[3] = (uint8_t)address;
        if (XQspiPs_PolledTransfer(&qspi, tx, rx, sizeof(tx))) fail(5);
        memcpy(output + offset, rx + 4U, BLOCK);
        status[1] = offset + BLOCK;
    }
    status[0] = 0x600dU;
    for (;;) {}
}
