#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
typedef uint32_t u32_t;
typedef uint16_t u16_t;
typedef struct { uintptr_t BaseAddress; } XEmacPs_Config;
typedef struct { XEmacPs_Config Config; } XEmacPs;
struct netif { unsigned link; };
enum ethernet_link_status { ETH_LINK_UNDEFINED, ETH_LINK_UP, ETH_LINK_DOWN, ETH_LINK_NEGOTIATING };
typedef struct { struct netif *netif; u32_t phy_addr, speed; enum ethernet_link_status link_status; int configured; } ris_gem_state;
#define RIS_GEM1_BASE 0xE000C000U
#define RIS_COPPER_PHY_ADDR 2U
#define RIS_SGMII_PCS_ADDR 8U
#define XEMACPS_NWSR_OFFSET 8U
#define XEMACPS_NWSR_MDIOIDLE_MASK 4U
#define XEMACPS_PHYMNTNC_OFFSET 52U
#define XEMACPS_PHYMNTNC_OP_MASK 0x40020000U
#define XEMACPS_PHYMNTNC_OP_W_MASK 0x10000000U
#define XEMACPS_PHYMNTNC_OP_R_MASK 0x20000000U
#define XEMACPS_PHYMNTNC_PHAD_SHFT_MSK 23U
#define XEMACPS_PHYMNTNC_PREG_SHFT_MSK 18U
#define xil_printf(...) ((void)0)
static uint16_t registers[32][32];
static uint32_t maintenance;
static unsigned writes, reads, time_us, speed_calls, last_speed, commands;
static int idle_fault, post_fault, ignore_advertisement, corrupt_pcs_control;
static void usleep_dummy(unsigned n) { time_us += n; }
void usleep(unsigned n) { usleep_dummy(n); }
static uint32_t XEmacPs_ReadReg(uintptr_t base, unsigned offset)
{
    assert(base == RIS_GEM1_BASE);
    if(offset == XEMACPS_NWSR_OFFSET)
        return (idle_fault || (post_fault && commands)) ? 0U : XEMACPS_NWSR_MDIOIDLE_MASK;
    assert(offset == XEMACPS_PHYMNTNC_OFFSET);
    return maintenance;
}
static void XEmacPs_WriteReg(uintptr_t base, unsigned offset, uint32_t value)
{
    unsigned phy=(value>>23)&31U, reg=(value>>18)&31U;
    assert(base == RIS_GEM1_BASE && offset == XEMACPS_PHYMNTNC_OFFSET);
    commands++;
    if(value & XEMACPS_PHYMNTNC_OP_W_MASK) {
        writes++;
        if(!(ignore_advertisement && phy==2U && reg==4U))
            registers[phy][reg]=(uint16_t)value;
        if(corrupt_pcs_control && phy==8U && reg==0U)
            registers[phy][reg]=0x8000U;
    } else {
        reads++;
        maintenance=registers[phy][reg];
    }
}
static void XEmacPs_SetOperatingSpeed(XEmacPs *mac, u32_t speed)
{ assert(mac->Config.BaseAddress==RIS_GEM1_BASE); speed_calls++; last_speed=speed; }
static void netif_set_link_down(struct netif *n) { n->link=0U; }
static void netif_set_link_up(struct netif *n) { n->link=1U; }
#include "ris_dual_gem.inc"
static XEmacPs mac1={{RIS_GEM1_BASE}}, mac0={{0xE000B000U}};
static void reset(void)
{
    memset(registers,0,sizeof registers);
    memset(ris_gems,0,sizeof ris_gems);
    registers[2][2]=0x001cU; registers[2][3]=0xc916U;
    registers[8][2]=0x0174U; registers[8][3]=0x0c00U;
    writes=reads=time_us=speed_calls=last_speed=commands=0U;
    idle_fault=post_fault=ignore_advertisement=corrupt_pcs_control=0;
}
static void set_link(uint16_t partner)
{ registers[2][1]=0x24U; registers[8][1]=0x24U; registers[8][5]=partner; }
static void assert_failure(void)
{ assert(ris_gem1_start(&mac1)==-1); assert(!ris_gem_get(&mac1)->configured); assert(time_us<=2000U); }
int main(void)
{
    struct netif net={0U};
    reset(); assert(ris_gem1_start(&mac1)==0); assert(ris_gem_get(&mac1)->configured);
    assert(writes==4U && time_us==0U); assert(ris_gem1_link_speed(&mac1)==0U);
    ris_gem_get(&mac0)->speed=100U; ris_gem_get(&mac0)->link_status=ETH_LINK_UP;
    set_link(0xd801U); ris_gem1_link_detect(&net,&mac1);
    assert(net.link && last_speed==1000U && speed_calls==1U);
    ris_gem1_link_detect(&net,&mac1); assert(speed_calls==1U);
    set_link(0xd401U); ris_gem1_link_detect(&net,&mac1);
    assert(net.link && last_speed==100U && speed_calls==2U);
    registers[2][1]=0U; ris_gem1_link_detect(&net,&mac1); assert(!net.link);
    set_link(0xd801U); ris_gem1_link_detect(&net,&mac1); assert(net.link && speed_calls==3U);
    assert(ris_gem_get(&mac0)->speed==100U && ris_gem_get(&mac0)->link_status==ETH_LINK_UP);
    set_link(0xc801U); assert(!ris_gem1_link_speed(&mac1)); /* half duplex */
    set_link(0x5801U); assert(!ris_gem1_link_speed(&mac1)); /* copper link down */
    set_link(0x9801U); assert(!ris_gem1_link_speed(&mac1)); /* no ACK */
    set_link(0xdc01U); assert(!ris_gem1_link_speed(&mac1)); /* reserved speed */
    set_link(0xd001U); assert(!ris_gem1_link_speed(&mac1)); /* not advertised 10M */
    set_link(0xd801U); registers[8][1]=4U; assert(!ris_gem1_link_speed(&mac1));
    set_link(0xd801U); registers[2][1]=4U; assert(!ris_gem1_link_speed(&mac1));
    set_link(0xd801U); registers[8][1]=0xffffU; assert(!ris_gem1_link_speed(&mac1));
    set_link(0xd801U); idle_fault=1; assert(!ris_gem1_link_speed(&mac1)); assert(time_us==2000U);
    reset(); registers[2][2]=0xffffU; assert_failure(); assert(!writes);
    reset(); registers[2][3]=0xc915U; assert(ris_gem1_start(&mac1)==0); /* revision mask */
    reset(); registers[2][3]=0xc810U; assert_failure(); assert(!writes);
    reset(); registers[8][2]=0xffffU; assert_failure(); assert(!writes);
    reset(); registers[8][3]=0x0d00U; assert_failure(); assert(!writes);
    reset(); registers[2][0]=0x8000U; assert_failure(); assert(!writes);
    reset(); ignore_advertisement=1; assert_failure();
    reset(); corrupt_pcs_control=1; assert_failure();
    reset(); idle_fault=1; assert_failure(); assert(!commands);
    reset(); post_fault=1; assert_failure(); assert(commands==1U);
    puts("PASS: PHY2/PCS8 IDs, configuration faults, bounded MDIO, no-cable startup, 100/1000 transitions, duplex/AN/status rejection, dual-GEM isolation");
    return 0;
}
