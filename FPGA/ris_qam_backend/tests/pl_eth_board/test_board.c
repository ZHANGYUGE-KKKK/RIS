#include "test_common.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>
#include "../../software/network/ris_pl_eth_board.c"

enum fault { NONE,CONFIG,STUCK_BUS,NACK,TX_STALL,RX_STALL,MUX_BAD,ID_BAD,
             VERIFY_BAD,NO_XTAL,NO_LOCK,CAL_STUCK,INTERMITTENT_LOCK,SLOW_CONFIG,SLOW_LOCK };
static enum fault fault;
static XIicPs_Config ic={0x1000U,100000000U};
static XGpioPs_Config gc={0x2000U};
static u32 regs[32],clock_regs[256],pin[128],direction[128],output_enable[128];
static u8 tx[4],rx,mux,clock_index;
static unsigned ntx,rx_valid,phy_released,poll_reads;
static unsigned long long elapsed,ready_at;
static unsigned calibration_started;
void XTime_GetTime(XTime *now) {*now=elapsed;}

XIicPs_Config *XIicPs_LookupConfig(u32 id) {(void)id; return &ic;}
int XIicPs_CfgInitialize(XIicPs *i,XIicPs_Config *c,UINTPTR b)
{assert(b==c->BaseAddress);i->Config=*c;return 0;}
int XIicPs_SetSClk(XIicPs *i,u32 h) {(void)i;assert(h==100000U);regs[0]=0x3b00U;return 0;}
XGpioPs_Config *XGpioPs_LookupConfig(u32 id) {(void)id;return fault==CONFIG?NULL:&gc;}
int XGpioPs_CfgInitialize(XGpioPs *g,XGpioPs_Config *c,UINTPTR b)
{(void)c;(void)b;g->initialized=1;return 0;}
void XGpioPs_WritePin(XGpioPs *g,u32 n,u32 v)
{
    assert(g->initialized && n<128);pin[n]=v;
    if (n==54 && v) {
        assert(fault==NONE && elapsed>=5000000ULL && clock_regs[10]==0);
        phy_released=1;
    }
}
void XGpioPs_SetDirectionPin(XGpioPs *g,u32 n,u32 v)
{(void)g;assert(pin[n]==0);direction[n]=v;}
void XGpioPs_SetOutputEnablePin(XGpioPs *g,u32 n,u32 v)
{(void)g;assert(direction[n]==1 && pin[n]==0);output_enable[n]=v;}
void usleep(unsigned n) {elapsed+=n;assert(elapsed<=20110000ULL);}
int xil_printf(const char *fmt,...) {(void)fmt;return 0;}
u32 mock_read(UINTPTR b,u32 o)
{
    assert(b==ic.BaseAddress);
    if (o==XIICPS_SR_OFFSET)
        return (fault==STUCK_BUS ? XIICPS_SR_BA_MASK : 0U)|
            (rx_valid && elapsed>=ready_at ? XIICPS_SR_RXDV_MASK : 0U);
    if (o==XIICPS_DATA_OFFSET) {assert(rx_valid);rx_valid=0;return rx;}
    if (o==XIICPS_ISR_OFFSET && elapsed<ready_at) return 0;
    return regs[o/4];
}
void mock_write(UINTPTR b,u32 o,u32 v)
{
    unsigned receive;
    assert(b==ic.BaseAddress);
    if (o==XIICPS_ISR_OFFSET) {regs[o/4]&=~v;return;}
    regs[o/4]=v;
    if (o==XIICPS_CR_OFFSET && (v&XIICPS_CR_CLR_FIFO_MASK)) {ntx=0;rx_valid=0;}
    if (o==XIICPS_DATA_OFFSET) {assert(ntx<4);tx[ntx++]=(u8)v;}
    if (o!=XIICPS_ADDR_OFFSET) return;
    assert(pin[46] && pin[55] && !pin[54]);
    ready_at=elapsed+((fault==SLOW_CONFIG || (fault==SLOW_LOCK && calibration_started)) ? 190000ULL : 0ULL);
    assert((regs[0]&0xff00U)==0x3b00U);
    receive=regs[0]&XIICPS_CR_RD_WR_MASK;
    if (fault==NACK) {regs[XIICPS_ISR_OFFSET/4]=XIICPS_IXR_NACK_MASK;return;}
    if (fault==TX_STALL && !receive) return;
    if (fault==RX_STALL && receive) return;
    assert(v==0x74U || v==0x68U);
    if (!receive) {
        if (v==0x74U) {assert(ntx==1);mux=tx[0];}
        else {
            assert(mux==0x10U && (ntx==1 || ntx==2));
            clock_index=tx[0];
            if (ntx==2) {
                clock_regs[clock_index]=tx[1];
                if (clock_index==136) calibration_started=1;
                if (clock_index==136 && fault!=CAL_STUCK) clock_regs[136]=0;
            }
        }
    } else {
        assert(regs[XIICPS_TRANS_SIZE_OFFSET/4]==1);
        if (v==0x74U) rx=fault==MUX_BAD?0:mux;
        else {
            rx=(u8)clock_regs[clock_index];
            if (clock_index==134 && fault==ID_BAD) rx=0xff;
            if (clock_index==25 && fault==VERIFY_BAD) rx^=0x20;
            if (clock_index==129 && fault==NO_XTAL) rx=1;
            if (clock_index==130) {
                ++poll_reads;
                if (fault==NO_LOCK || (fault==INTERMITTENT_LOCK && poll_reads%50==0))rx=1;
            }
        }
        rx_valid=1;
    }
    regs[XIICPS_ISR_OFFSET/4]=XIICPS_IXR_COMP_MASK;
}
static void check_clock(enum fault f,int expected,u8 clock_id_lsb)
{
    int r;
    memset(regs,0,sizeof(regs));memset(clock_regs,0,sizeof(clock_regs));
    memset(pin,0,sizeof(pin));memset(direction,0,sizeof(direction));
    memset(output_enable,0,sizeof(output_enable));
    clock_regs[134]=1;clock_regs[135]=clock_id_lsb;
    pin[47]=1; /* Existing GEM0 PHY reset stays released. */
    fault=f;ntx=rx_valid=phy_released=poll_reads=calibration_started=0;elapsed=ready_at=0;
    r=ris_pl_eth_board_init();
    assert(r==expected);
    assert(pin[47]==1);
    if(f==SLOW_CONFIG || f==SLOW_LOCK) assert(elapsed==20000000ULL);
    assert(phy_released==(expected==0));
    if (expected!=0) assert(pin[54]==0);
    printf("fault=%d result=%d elapsed_us=%llu PHY_release=%u PASS\n",f,r,elapsed,phy_released);
}
static void check(enum fault f,int expected)
{
    check_clock(f,expected,0x82U);
}
int main(void)
{
    check_clock(NONE,0,0xa2U);
    check_clock(NONE,-5,0xb2U);
    check(NONE,0);check(CONFIG,-1);check(STUCK_BUS,-2);check(NACK,-3);
    check(TX_STALL,-2);check(RX_STALL,-2);check(MUX_BAD,-4);check(ID_BAD,-5);
    check(VERIFY_BAD,-6);check(NO_XTAL,-7);check(NO_LOCK,-7);check(CAL_STUCK,-7);
    check(INTERMITTENT_LOCK,-7);
    check(SLOW_CONFIG,-2);check(SLOW_LOCK,-2);
    puts("RIS_PL_ETH_BOARD_TEST_PASS: 17 scenarios, GPIO order, GEM0 preserved, 20-second wall-clock deadline");
    return 0;
}
