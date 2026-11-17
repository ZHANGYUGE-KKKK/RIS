/* RIS dual GEM adapter, scoped to this Zynq-7000 standalone RAW project. */
#ifndef RIS_DUAL_GEM_H
#define RIS_DUAL_GEM_H
#include "netif/xemacpsif.h"
#include "netif/xadapter.h"
#if NO_SYS != 1
#error "RIS dual GEM patch requires the standalone RAW (NO_SYS=1) BSP"
#endif
#if XPAR_XEMACPS_NUM_INSTANCES != 2
#error "RIS dual GEM patch requires both Zynq-7000 GEM instances"
#endif
#define RIS_GEM1_BASE 0xE000C000U
#define RIS_COPPER_PHY_ADDR 2U
#define RIS_SGMII_PCS_ADDR 8U
typedef struct {
    struct netif *netif;
    u32_t phy_addr;
    u32_t speed;
    enum ethernet_link_status link_status;
    int configured;
} ris_gem_state;
ris_gem_state *ris_gem_get(XEmacPs *mac);
int ris_gem1_start(XEmacPs *mac);
u32_t ris_gem1_link_speed(XEmacPs *mac);
void ris_gem1_link_detect(struct netif *netif, XEmacPs *mac);
#endif
