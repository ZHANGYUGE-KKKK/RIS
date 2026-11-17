/*
 * Si5324 frequency table adapted from AMD/Xilinx embeddedsw 2022.2,
 * lib/sw_apps/lwip_echo_server/src/si5324.c (ZC706 125 MHz).
 * Copyright (C) 2013 - 2019 Xilinx, Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include "ris_pl_eth_board.h"
#include "xparameters.h"
#include "xgpiops.h"
#include "xiicps.h"
#include "xiicps_hw.h"
#include "sleep.h"
#include "xil_printf.h"
#include "xtime_l.h"

#define CLOCK_ADDR 0x68U
#define MUX_ADDR 0x74U
#define MUX_CLOCK_CHANNEL 0x10U
#define GPIO_MUX_RESET 46U
#define GPIO_PHY_RESET 55U
#define GPIO_CLOCK_RESET 56U
#define I2C_POLL_US 10U
#define I2C_POLL_COUNT 20000U
#define CLOCK_POLL_US 10000U
#define CLOCK_POLL_COUNT 1500U
#define CLOCK_SETTLE_POLLS 500U
#define CLOCK_STABLE_POLLS 100U
#define BOARD_INIT_TIMEOUT_SECONDS 20U
#define I2C_ERRORS (XIICPS_IXR_ARB_LOST_MASK | XIICPS_IXR_RX_UNF_MASK | \
                    XIICPS_IXR_TX_OVR_MASK | XIICPS_IXR_RX_OVR_MASK | \
                    XIICPS_IXR_TO_MASK | XIICPS_IXR_NACK_MASK)

/* Manufacturer schematic: PDF pp.7,8,36,43,46 (sheet49) in
 * 1_四川真为电子_ZC706_SCH.pdf. CKOUT2 uses W8/W7; upstream AMD's
 * reg10=0x08 disables that output, so this table explicitly uses 0x00.
 * Both outputs retain AMD's LVPECL format (reg6=0x2d) and are AC-coupled
 * into GTX reference inputs. FREE_RUN routes XA/XB through N32.
 * Dividers: N1_HS=7, NC1_LS=NC2_LS=6, N2_HS=10, N2_LS=140000,
 * N31=N32=30476. For the schematic's nominal 114285000 Hz crystal:
 * VCO = 114285000 * 10 * 140000 / 30476 = 5250000000 Hz;
 * CKOUT2 = VCO / (7 * 6) = 125000000 Hz. Crystal tolerance remains.
 * Register meanings/status: Skyworks Si5324 Rev1.1, pp.26-57:
 * https://www.skyworksinc.com/-/media/SkyWorks/SL/documents/public/data-sheets/Si5324.pdf
 */
static const struct { u8 reg; u8 value; } clock_table[] = {
    {0,0x54}, {1,0xe4}, {2,0x12}, {3,0x15}, {4,0x92}, {5,0xed},
    {6,0x2d}, {7,0x2a}, {8,0x00}, {9,0xc0}, {10,0x00}, {11,0x40},
    {19,0x29}, {20,0x3e}, {21,0xff}, {22,0xdf}, {23,0x1f},
    {24,0x3f}, {25,0x60}, {31,0x00}, {32,0x00}, {33,0x05},
    {34,0x00}, {35,0x00}, {36,0x05}, {40,0xc2}, {41,0x22},
    {42,0xdf}, {43,0x00}, {44,0x77}, {45,0x0b}, {46,0x00},
    {47,0x77}, {48,0x0b}, {55,0x00}, {131,0x1f}, {132,0x02},
    {137,0x01}, {138,0x0f}, {139,0xff}, {142,0x00}, {143,0x00}
};

static XIicPs iic;
static XGpioPs gpio;
static u32 iic_control;
static XTime init_started;

static int init_expired(void)
{
    XTime now;
    XTime_GetTime(&now);
    return now-init_started >= (XTime)BOARD_INIT_TIMEOUT_SECONDS*COUNTS_PER_SECOND;
}

static void iic_abort(void)
{
    UINTPTR base=iic.Config.BaseAddress;
    XIicPs_WriteReg(base,XIICPS_CR_OFFSET,iic_control|XIICPS_CR_CLR_FIFO_MASK);
    XIicPs_WriteReg(base,XIICPS_TRANS_SIZE_OFFSET,0U);
    XIicPs_WriteReg(base,XIICPS_ISR_OFFSET,XIICPS_IXR_ALL_INTR_MASK);
}

static int iic_idle(void)
{
    u32 n;
    for (n=0; n<I2C_POLL_COUNT; ++n) {
        if (init_expired()) break;
        if (!(XIicPs_ReadReg(iic.Config.BaseAddress,XIICPS_SR_OFFSET)&XIICPS_SR_BA_MASK))
            return 0;
        usleep(I2C_POLL_US);
    }
    iic_abort();
    return RIS_PL_ETH_BOARD_ERR_I2C_TIMEOUT;
}

/* These boot-time transfers are only one/two bytes. A local bounded polling
 * loop is intentional: Vitis2022.2 XIicPs_MasterRecvPolled has an unbounded
 * receive loop for a slave that neither supplies data nor raises an error.
 * Preserve clock divisors, do not use HOLD/repeated-start, and require both
 * transfer completion and bus release. Si5324 supports STOP-separated reads.
 */
static int iic_transfer(u8 slave,u8 *bytes,unsigned count,int receive)
{
    UINTPTR base=iic.Config.BaseAddress;
    unsigned n,received=0;
    u32 status;
    int result=iic_idle();
    if (result) return result;
    if (count==0U || count>2U) return RIS_PL_ETH_BOARD_ERR_CONFIG;
    XIicPs_WriteReg(base,XIICPS_CR_OFFSET,iic_control|
        XIICPS_CR_CLR_FIFO_MASK|(receive ? XIICPS_CR_RD_WR_MASK : 0U));
    XIicPs_WriteReg(base,XIICPS_ISR_OFFSET,XIICPS_IXR_ALL_INTR_MASK);
    if (receive) XIicPs_WriteReg(base,XIICPS_TRANS_SIZE_OFFSET,count);
    else for (n=0; n<count; ++n) XIicPs_WriteReg(base,XIICPS_DATA_OFFSET,bytes[n]);
    XIicPs_WriteReg(base,XIICPS_ADDR_OFFSET,slave);
    for (n=0; n<I2C_POLL_COUNT; ++n) {
        if (init_expired()) break;
        status=XIicPs_ReadReg(base,XIICPS_ISR_OFFSET);
        if (status&I2C_ERRORS) {
            iic_abort();
            return RIS_PL_ETH_BOARD_ERR_I2C_TRANSFER;
        }
        if (receive && received<count &&
            (XIicPs_ReadReg(base,XIICPS_SR_OFFSET)&XIICPS_SR_RXDV_MASK))
            bytes[received++]=(u8)XIicPs_ReadReg(base,XIICPS_DATA_OFFSET);
        if ((status&XIICPS_IXR_COMP_MASK) && (!receive || received==count))
            return iic_idle();
        usleep(I2C_POLL_US);
    }
    iic_abort();
    return RIS_PL_ETH_BOARD_ERR_I2C_TIMEOUT;
}

static int clock_write(u8 reg,u8 value)
{
    u8 data[2]={reg,value};
    return iic_transfer(CLOCK_ADDR,data,2,0);
}

static int clock_read(u8 reg,u8 *value)
{
    int result=iic_transfer(CLOCK_ADDR,&reg,1,0);
    return result ? result : iic_transfer(CLOCK_ADDR,value,1,1);
}

static void reset_output(u32 pin)
{
    /* Load low before enabling the output to avoid a reset-release glitch. */
    XGpioPs_WritePin(&gpio,pin,0U);
    XGpioPs_SetDirectionPin(&gpio,pin,1U);
    XGpioPs_SetOutputEnablePin(&gpio,pin,1U);
}

int ris_pl_eth_board_init(void)
{
#if !defined(XPAR_XIICPS_0_DEVICE_ID) || !defined(XPAR_XGPIOPS_0_DEVICE_ID)
    return RIS_PL_ETH_BOARD_ERR_CONFIG;
#else
    XIicPs_Config *ic;
    XGpioPs_Config *gc;
    unsigned n,stable=0;
    u8 value,id_msb,id_lsb,los,pll,calibration;
    unsigned clock_part;
    int result;
    XTime_GetTime(&init_started);
    gc=XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID);
    if (!gc || XGpioPs_CfgInitialize(&gpio,gc,gc->BaseAddr)!=XST_SUCCESS)
        return RIS_PL_ETH_BOARD_ERR_CONFIG;
    reset_output(GPIO_PHY_RESET);
    reset_output(GPIO_CLOCK_RESET);
    reset_output(GPIO_MUX_RESET);
    usleep(10000);
    XGpioPs_WritePin(&gpio,GPIO_MUX_RESET,1U);
    XGpioPs_WritePin(&gpio,GPIO_CLOCK_RESET,1U);
    usleep(20000); /* Si5324 requires >=10 ms after reset before I2C access. */

    ic=XIicPs_LookupConfig(XPAR_XIICPS_0_DEVICE_ID);
    if (!ic || XIicPs_CfgInitialize(&iic,ic,ic->BaseAddress)!=XST_SUCCESS ||
        XIicPs_SetSClk(&iic,100000U)!=XST_SUCCESS)
        return RIS_PL_ETH_BOARD_ERR_CONFIG;
    iic_control=(XIicPs_ReadReg(ic->BaseAddress,XIICPS_CR_OFFSET)&
        (XIICPS_CR_DIV_A_MASK|XIICPS_CR_DIV_B_MASK))|
        XIICPS_CR_ACKEN_MASK|XIICPS_CR_NEA_MASK|XIICPS_CR_MS_MASK;
    XIicPs_DisableAllInterrupts(ic->BaseAddress);
    iic_abort();
    value=MUX_CLOCK_CHANNEL;
    result=iic_transfer(MUX_ADDR,&value,1,0);
    if (result) return result;
    result=iic_transfer(MUX_ADDR,&value,1,1);
    if (result) return result;
    if (value!=MUX_CLOCK_CHANNEL) return RIS_PL_ETH_BOARD_ERR_MUX;

    result=clock_read(134,&id_msb);
    if (result) return result;
    result=clock_read(135,&id_lsb);
    if (result) return result;
    /* PARTNUM_RO is 0x018 for Si5324 and 0x01a for Si5326; the low
     * nibble is the silicon revision. Both use the register fields below. */
    clock_part=((unsigned)id_msb<<4)|(id_lsb>>4);
    if (clock_part!=0x018U && clock_part!=0x01aU) {
        xil_printf("PL ETH unknown clock ID %02x:%02x\r\n",id_msb,id_lsb);
        return RIS_PL_ETH_BOARD_ERR_CLOCK_ID;
    }
    xil_printf("PL ETH %s revision %u\r\n",
        clock_part==0x018U ? "Si5324" : "Si5326",id_lsb&0xfU);
    for (n=0; n<sizeof(clock_table)/sizeof(clock_table[0]); ++n) {
        result=clock_write(clock_table[n].reg,clock_table[n].value);
        if (result) return result;
    }
    for (n=0; n<sizeof(clock_table)/sizeof(clock_table[0]); ++n) {
        /* Sticky event flags can change asynchronously; never compare them
         * to programmed values. All static configuration is read back. */
        if (clock_table[n].reg==131U || clock_table[n].reg==132U) continue;
        result=clock_read(clock_table[n].reg,&value);
        if (result) return result;
        if (value!=clock_table[n].value) {
            xil_printf("PL ETH clock verify reg=%u got=%02x expected=%02x\r\n",
                clock_table[n].reg,value,clock_table[n].value);
            return RIS_PL_ETH_BOARD_ERR_CLOCK_VERIFY;
        }
    }
    result=clock_write(136,0x40U); /* ICAL, after all divider programming. */
    if (result) return result;
    for (n=0; n<CLOCK_POLL_COUNT; ++n) {
        if (init_expired()) return RIS_PL_ETH_BOARD_ERR_CLOCK_LOCK;
        usleep(CLOCK_POLL_US);
        result=clock_read(129,&los);
        if (result) return result;
        result=clock_read(130,&pll);
        if (result) return result;
        result=clock_read(136,&calibration);
        if (result) return result;
        /* In free-run only XA/XB is required; CKIN1 is deliberately unused.
         * LOW LOL alone can precede settling: allow at least 5 seconds and
         * demand a consecutive second of good status. The hard bound
         * is 1500 polls and a 20-second wall-clock deadline also bounds slow
         * but successful I2C transfers, including configuration/readback. */
        if (!(los&0x01U) && !(pll&0x01U) && !(calibration&0x40U)) ++stable;
        else stable=0;
        if (n+1U>=CLOCK_SETTLE_POLLS && stable>=CLOCK_STABLE_POLLS) {
            XGpioPs_WritePin(&gpio,GPIO_PHY_RESET,1U);
            usleep(100000);
            xil_printf("PL ETH CKOUT2 configured 125MHz, lock verified\r\n");
            return RIS_PL_ETH_BOARD_OK;
        }
    }
    xil_printf("PL ETH clock not ready LOS=%02x PLL=%02x ICAL=%02x\r\n",
        los,pll,calibration);
    return RIS_PL_ETH_BOARD_ERR_CLOCK_LOCK;
#endif
}
