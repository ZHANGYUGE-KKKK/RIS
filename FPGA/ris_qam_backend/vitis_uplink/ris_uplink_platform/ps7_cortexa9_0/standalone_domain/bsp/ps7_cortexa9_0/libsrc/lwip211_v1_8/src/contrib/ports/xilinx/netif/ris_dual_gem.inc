/* Project-specific PHY handling; included in xemacpsif_physpeed.c.
 * PG047, SGMII MAC mode: PCS reg 5 reports the external copper link,
 * bit 15 link, bit 12 duplex, bits 11:10 speed; reg 1 bit 5 AN complete.
 * https://docs.amd.com/r/16.2-English/pg047-gig-eth-pcs-pma/Register-5-SGMII-Auto-Negotiation-Link-Partner-Ability
 * The RTL8211FS MODE[2:0]=011 straps select its SGMII interface. We use
 * standard Clause 22 registers only, retaining the strapped interface mode.
 * Advertise 100BASE-TX/full and 1000BASE-T/full, matching this sender design.
 */
#include "sleep.h"
static ris_gem_state ris_gems[2];

ris_gem_state *ris_gem_get(XEmacPs *mac)
{
    return &ris_gems[mac->Config.BaseAddress == RIS_GEM1_BASE ? 1 : 0];
}

/* The installed XEmacPs_PhyRead/Write spin without a timeout. GEM1 must not
 * enter them, because a missing PL reference/PCS must not block the PS port.
 * MDC_DIV_224 gives ample time for a 64-bit Clause 22 frame in this 2 ms bound.
 */
static int ris_mdio_idle(XEmacPs *mac)
{
    unsigned n;
    for (n = 0; n < 2000U; ++n) {
        if (XEmacPs_ReadReg(mac->Config.BaseAddress, XEMACPS_NWSR_OFFSET) &
            XEMACPS_NWSR_MDIOIDLE_MASK)
            return 0;
        usleep(1U);
    }
    return -1;
}

static int ris_mdio(XEmacPs *mac, u32_t phy, u32_t reg, u16_t *data, int write)
{
    u32_t command;
    if (ris_mdio_idle(mac))
        return -1;
    command = XEMACPS_PHYMNTNC_OP_MASK |
        (write ? XEMACPS_PHYMNTNC_OP_W_MASK : XEMACPS_PHYMNTNC_OP_R_MASK) |
        (phy << XEMACPS_PHYMNTNC_PHAD_SHFT_MSK) |
        (reg << XEMACPS_PHYMNTNC_PREG_SHFT_MSK);
    if (write)
        command |= *data;
    XEmacPs_WriteReg(mac->Config.BaseAddress, XEMACPS_PHYMNTNC_OFFSET, command);
    if (ris_mdio_idle(mac))
        return -1;
    if (!write)
        *data = (u16_t)XEmacPs_ReadReg(mac->Config.BaseAddress,
                                     XEMACPS_PHYMNTNC_OFFSET);
    return 0;
}

static int ris_phy_read(XEmacPs *mac, u32_t phy, u32_t reg, u16_t *value)
{
    return ris_mdio(mac, phy, reg, value, 0);
}

static int ris_phy_write(XEmacPs *mac, u32_t phy, u32_t reg, u16_t value)
{
    return ris_mdio(mac, phy, reg, &value, 1);
}

int ris_gem1_start(XEmacPs *mac)
{
    u16_t id1, id2, value;
    ris_gem_state *state = ris_gem_get(mac);
    state->configured = 0;
    state->phy_addr = RIS_COPPER_PHY_ADDR;
    if (ris_phy_read(mac, RIS_COPPER_PHY_ADDR, 2U, &id1) ||
        ris_phy_read(mac, RIS_COPPER_PHY_ADDR, 3U, &id2))
        goto failed;
    xil_printf("GEM1 copper PHY[2] ID %04x:%04x\r\n", id1, id2);
    if (id1 != 0x001cU || (id2 & 0xfff0U) != 0xc910U)
        goto failed;
    if (ris_phy_read(mac, RIS_SGMII_PCS_ADDR, 2U, &id1) ||
        ris_phy_read(mac, RIS_SGMII_PCS_ADDR, 3U, &id2))
        goto failed;
    xil_printf("GEM1 SGMII PCS[8] ID %04x:%04x\r\n", id1, id2);
    if (id1 != 0x0174U || (id2 & 0xfff0U) != 0x0c00U)
        goto failed;
    /* The board initializer already completed the external hardware reset.
     * Do not reset again or touch vendor-specific pages/delay registers. */
    if (ris_phy_read(mac, RIS_COPPER_PHY_ADDR, 0U, &value) ||
        (value & 0x8000U))
        goto failed;
    if (ris_phy_write(mac, RIS_COPPER_PHY_ADDR, 4U, 0x0101U) ||
        ris_phy_write(mac, RIS_COPPER_PHY_ADDR, 9U, 0x0200U) ||
        ris_phy_read(mac, RIS_COPPER_PHY_ADDR, 4U, &value) ||
        (value & 0x0fe0U) != 0x0100U)
        goto failed;
    if (ris_phy_read(mac, RIS_COPPER_PHY_ADDR, 9U, &value) ||
        (value & 0x0300U) != 0x0200U)
        goto failed;
    /* BMCR: 1000/full, AN enable+restart, loopback/powerdown/isolate clear.
     * PCS reg 4 is fixed by SGMII MAC mode; no 1000BASE-X advertisement. */
    if (ris_phy_write(mac, RIS_COPPER_PHY_ADDR, 0U, 0x1340U) ||
        ris_phy_write(mac, RIS_SGMII_PCS_ADDR, 0U, 0x1340U) ||
        ris_phy_read(mac, RIS_SGMII_PCS_ADDR, 0U, &value) ||
        (value & 0x9c00U) != 0x1000U)
        goto failed;
    state->configured = 1;
    xil_printf("GEM1 PHY/SGMII negotiation started (100/1000 full duplex)\r\n");
    return 0;
failed:
    xil_printf("GEM1 PHY/PCS initialization failed; PS Ethernet remains available\r\n");
    return -1;
}

u32_t ris_gem1_link_speed(XEmacPs *mac)
{
    u16_t copper, pcs, partner;
    if (!ris_gem_get(mac)->configured)
        return 0U;
    /* Double BMSR reads handle latch-low link status. No AN wait/restart. */
    if (ris_phy_read(mac, RIS_COPPER_PHY_ADDR, 1U, &copper) ||
        ris_phy_read(mac, RIS_COPPER_PHY_ADDR, 1U, &copper) ||
        copper == 0xffffU || (copper & 0x0024U) != 0x0024U)
        return 0U;
    if (ris_phy_read(mac, RIS_SGMII_PCS_ADDR, 1U, &pcs) ||
        ris_phy_read(mac, RIS_SGMII_PCS_ADDR, 1U, &pcs) ||
        pcs == 0xffffU || (pcs & 0x0024U) != 0x0024U ||
        ris_phy_read(mac, RIS_SGMII_PCS_ADDR, 5U, &partner))
        return 0U;
    /* Reject half duplex, down, and invalid/reserved speed reports. */
    if ((partner & 0xd000U) != 0xd000U)
        return 0U;
    switch (partner & 0x0c00U) {
    case 0x0800U: return 1000U;
    case 0x0400U: return 100U;
    default: return 0U;
    }
}

void ris_gem1_link_detect(struct netif *netif, XEmacPs *mac)
{
    ris_gem_state *state = ris_gem_get(mac);
    u32_t speed = ris_gem1_link_speed(mac);
    if (!speed) {
        if (state->link_status == ETH_LINK_UP)
            xil_printf("GEM1 Ethernet link down\r\n");
        state->link_status = ETH_LINK_DOWN;
        netif_set_link_down(netif);
        return;
    }
    if (state->link_status != ETH_LINK_UP || state->speed != speed) {
        XEmacPs_SetOperatingSpeed(mac, speed);
        state->speed = speed;
        state->link_status = ETH_LINK_UP;
        netif_set_link_up(netif);
        xil_printf("GEM1 Ethernet link up: %d Mbps full duplex\r\n", speed);
    }
}
