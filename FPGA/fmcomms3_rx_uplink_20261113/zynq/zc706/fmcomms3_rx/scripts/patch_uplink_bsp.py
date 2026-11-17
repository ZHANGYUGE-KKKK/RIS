#!/usr/bin/env python3
"""Patch only this project's generated Vitis 2022.2 lwip211_v1_8 BSP.

GEM0 keeps the vendor Marvell RGMII initialization. GEM1 uses bounded MDIO,
RTL8211FS address 2 and MAC-side SGMII PCS address 8. Copper/SGMII negotiation
runs asynchronously: no cable cannot stall GEM0's service loop.

Usage: patch_uplink_bsp.py --bsp .../standalone_domain/bsp \
    --export .../standalone_domain --rebuild
Run after platform generate, before app build. Regeneration overwrites BSP
changes, so every build must reapply this script. No installation files change.
"""
import argparse
import hashlib
import shutil
import subprocess
from pathlib import Path

MARK = '/* RIS_DUAL_GEM_V1: project-local Vitis 2022.2 patch. */\n'
EXPECTED = {
    'xadapter.c': '1eb5fbba3427b9874c07378248b0667735595b2aa6735157852bab2c69529099',
    'xemacpsif_physpeed.c': '2e05d7ae1ebe0094dab10742cc29868a1bef7b91a3a888f030ef96f4da68e7ad',
    'xemacpsif.c': 'f32eaaa70d7be4bfbf2399b1dbbe8a1ed2b0a298c20fc10e8ee10efa4c1ebe3a',
    'xemacpsif_hw.c': '9f1587805dee1238b3504316743fbe0b6c36267e905449515c72db65871fe2e9',
}
HEADER = r'''/* RIS dual GEM adapter, scoped to this Zynq-7000 standalone RAW project. */
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
'''
HELPER = r'''/* Project-specific PHY handling; included in xemacpsif_physpeed.c.
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
'''
INIT = r'''void init_emacps(xemacpsif_s *xemacps, struct netif *netif)
{
    XEmacPs *mac = &xemacps->emacps;
    ris_gem_state *state = ris_gem_get(mac);
    u32_t i, speed = 0U;
    int found = 0;
    state->netif = netif;
    state->phy_addr = 0U;
    state->link_status = ETH_LINK_DOWN;
    state->configured = 0;
#ifdef ZYNQMP_USE_JUMBO
    XEmacPs_SetOptions(mac, XEMACPS_JUMBO_ENABLE_OPTION);
#endif
#ifdef LWIP_IGMP
    XEmacPs_SetOptions(mac, XEMACPS_MULTICAST_OPTION);
#endif
    if (XEmacPs_SetMacAddress(mac, (void *)netif->hwaddr, 1) != XST_SUCCESS) {
        netif_set_link_down(netif);
        return;
    }
    XEmacPs_SetMdioDivisor(mac, MDC_DIV_224);
    if (mac->Config.BaseAddress == RIS_GEM1_BASE) {
        /* No copper AN wait: link polling completes the asynchronous setup. */
        state->speed = 1000U;
        XEmacPs_SetOperatingSpeed(mac, state->speed);
        netif_set_link_down(netif);
        (void)ris_gem1_start(mac);
        ris_gem1_link_detect(netif, mac);
        return;
    }
    /* GEM0 retains the installed vendor RGMII / Marvell programming path. */
    detect_phy(mac);
    for (i = 31U; i > 0U; --i) {
        if (phymapemac0[i]) {
            speed = phy_setup_emacps(mac, i);
            state->phy_addr = i;
            found = 1;
        }
    }
    if (!found)
        speed = phy_setup_emacps(mac, 0U);
    if (speed != 10U && speed != 100U && speed != 1000U) {
        state->speed = 100U;
        netif_set_link_down(netif);
        xil_printf("GEM0 PHY setup failed\r\n");
        return;
    }
    state->speed = speed;
    state->configured = 1;
    state->link_status = ETH_LINK_UP;
    XEmacPs_SetOperatingSpeed(mac, speed);
    netif_set_link_up(netif);
    {
        volatile s32_t wait;
        for (wait = 0; wait < 20000; wait++);
    }
}

void init_emacps_on_error(xemacpsif_s *xemacps, struct netif *netif)
{
    XEmacPs *mac = &xemacps->emacps;
    ris_gem_state *state = ris_gem_get(mac);
    if (netif == NULL)
        return;
    (void)XEmacPs_SetMacAddress(mac, (void *)netif->hwaddr, 1);
    XEmacPs_SetMdioDivisor(mac, MDC_DIV_224);
    XEmacPs_SetOperatingSpeed(mac, state->speed ? state->speed : 100U);
    {
        volatile s32_t wait;
        for (wait = 0; wait < 20000; wait++);
    }
}

'''

def replace_once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError('Expected unique Vitis 2022.2 fragment: ' + old[:100])
    return text.replace(old, new, 1)


def render(name, text):
    text = MARK + text
    if name in ('xemacpsif_physpeed.c', 'xemacpsif_hw.c'):
        text = replace_once(text, '#undef PCM_PMA_CORE_PRESENT\n#endif\n\n#ifdef PCM_PMA_CORE_PRESENT' if name.endswith('physpeed.c') else '#endif\n\nu32_t link_speed = 100;',
            '#undef PCM_PMA_CORE_PRESENT\n#endif\n\n/* PCS handling is per GEM, never a global build selection. */\n#undef PCM_PMA_CORE_PRESENT\n\n#ifdef PCM_PMA_CORE_PRESENT' if name.endswith('physpeed.c') else '#endif\n\n#undef PCM_PMA_CORE_PRESENT')
    text = replace_once(text, '#include "netif/xemacpsif.h"', '#include "netif/xemacpsif.h"\n#include "netif/ris_dual_gem.h"')
    if name == 'xemacpsif_physpeed.c':
        text = replace_once(text, '\tu32_t convphyaddr = 0;\n', '\tu32_t convphyaddr = 0;\n\n\tif (xemacpsp->Config.BaseAddress == RIS_GEM1_BASE)\n\t\treturn ris_gem1_link_speed(xemacpsp);\n')
        text = replace_once(text, '\t\t\tSLCR_GEM_SRCSEL_EMIO) {\n\t\t\t\treturn;', '\t\t\tSLCR_GEM_SRCSEL_EMIO) {\n\t\t\t\tXil_Out32(SLCR_LOCK_ADDR, SLCR_LOCK_KEY_VALUE);\n\t\t\t\treturn;')
        text += '\n#include "ris_dual_gem.inc"\n'
    elif name == 'xemacpsif_hw.c':
        start, end = text.index('void init_emacps('), text.index('void setup_isr (')
        text = text[:start] + INIT + text[end:]
        text = replace_once(text, 'extern u32_t phyaddrforemac;\nextern enum ethernet_link_status eth_link_status;\n', '')
    elif name == 'xemacpsif.c':
        text = replace_once(text, 'XEmacPs_Config *mac_config;\nstruct netif *NetIf;\n', '')
        text = replace_once(text, '\tUINTPTR mac_address = (UINTPTR)(netif->state);', '\tXEmacPs_Config *mac_config;\n\tUINTPTR mac_address = (UINTPTR)(netif->state);')
        text = replace_once(text, '\tNetIf = netif;\n\n', '')
        text = replace_once(text, '\tinit_emacps(xemacpsif, netif);', '\tinit_emacps(xemacpsif, netif);\n\tif (!ris_gem_get(&xemacpsif->emacps)->configured) {\n\t\tXEmacPs_Stop(&xemacpsif->emacps);\n\t\tnetif_set_link_down(netif);\n\t\treturn ERR_IF;\n\t}')
        text = replace_once(text, '\t\txemacpsif_resetrx_on_no_rxdata(NetIf);', '\t\txemacpsif_resetrx_on_no_rxdata((struct netif *)pvTimerGetTimerID(pxTimer));')
        text = replace_once(text, '10, pdTRUE, ( void * ) 1, vTimerCallback', '10, pdTRUE, (void *)netif, vTimerCallback')
        start, end = text.index('void HandleEmacPsError('), text.index('void HandleTxErrors(')
        func = text[start:end]
        func = replace_once(func, '\tu32 dmacrreg;', '\tu32 dmacrreg;\n\tXEmacPs_Config saved_config;\n\tstruct netif *own_netif;')
        func = replace_once(func, '\tfree_txrx_pbufs(xemacpsif);', '\tsaved_config = xemacpsif->emacps.Config;\n\town_netif = ris_gem_get(&xemacpsif->emacps)->netif;\n\tfree_txrx_pbufs(xemacpsif);')
        func = replace_once(func, 'mac_config,\n\t\t\t\t\t\tmac_config->BaseAddress', '&saved_config,\n\t\t\t\t\t\tsaved_config.BaseAddress')
        func = replace_once(func, 'init_emacps_on_error(xemacpsif, NetIf);', 'init_emacps_on_error(xemacpsif, own_netif);')
        text = text[:start] + func + text[end:]
        old = '\tsetup_isr(xemac);\n\tinit_dma(xemac);\n\tstart_emacps(xemacpsif);'
        if text.count(old) != 2:
            raise RuntimeError('Unexpected DMA setup call sites')
        failure = '\tif (init_dma(xemac) != XST_SUCCESS) {\n\t\tXEmacPs_Stop(&xemacpsif->emacps);\n\t\tris_gem_get(&xemacpsif->emacps)->configured = 0;\n\t\tris_gem_get(&xemacpsif->emacps)->link_status = ETH_LINK_DOWN;\n'
        text = text.replace(old, failure + '\t\tnetif_set_link_down(netif);\n\t\txil_printf("Ethernet DMA initialization failed\\r\\n");\n\t\treturn ERR_IF;\n\t}\n\tsetup_isr(xemac);\n\tstart_emacps(xemacpsif);', 1)
        text = text.replace(old, failure + '\t\tnetif_set_link_down(own_netif);\n\t\tSYS_ARCH_UNPROTECT(lev);\n\t\treturn;\n\t}\n\tsetup_isr(xemac);\n\tstart_emacps(xemacpsif);', 1)
    elif name == 'xadapter.c':
        start, end = text.index('void eth_link_detect('), text.index('\n#if !NO_SYS\nvoid link_detect_thread')
        func = text[start:end]
        func = replace_once(func, '\tXEmacPs *xemacp = &xemacs->emacps;', '\tXEmacPs *xemacp = &xemacs->emacps;\n\tris_gem_state *state = ris_gem_get(xemacp);\n\tif (xemacp->Config.BaseAddress == RIS_GEM1_BASE) {\n\t\tif (xemacp->IsReady == XIL_COMPONENT_IS_READY)\n\t\t\tris_gem1_link_detect(netif, xemacp);\n\t\treturn;\n\t}')
        func = func.replace('eth_link_status', 'state->link_status').replace('phyaddrforemac', 'state->phy_addr')
        func = replace_once(func, '\t\t\t\tXEmacPs_SetOperatingSpeed(xemacp, link_speed);', '\t\t\t\tif (link_speed != 10U && link_speed != 100U && link_speed != 1000U)\n\t\t\t\t\treturn;\n\t\t\t\tstate->speed = link_speed;\n\t\t\t\tXEmacPs_SetOperatingSpeed(xemacp, link_speed);')
        text = text[:start] + func + text[end:]
    return text


def inside(path, root):
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bsp', required=True, type=Path)
    parser.add_argument('--export', type=Path)
    parser.add_argument('--rebuild', action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    bsp = args.bsp.resolve()
    if not inside(bsp, project) or bsp.name != 'bsp' or bsp.parent.name != 'standalone_domain':
        raise SystemExit('Refusing non-project / non-standalone generated BSP: ' + str(bsp))
    export = args.export.resolve() if args.export else None
    if export and (not inside(export, project) or export.name != 'standalone_domain'):
        raise SystemExit('Refusing non-project export: ' + str(export))
    if export and not args.rebuild:
        raise SystemExit('--export requires --rebuild; never export stale libraries')
    src = bsp / 'ps7_cortexa9_0/libsrc/lwip211_v1_8/src'
    port = src / 'contrib/ports/xilinx'
    netif = port / 'netif'
    inc = port / 'include/netif'
    plans = []
    # Validate all version fingerprints before the first write.
    for name, digest in EXPECTED.items():
        path = netif / name
        current = path.read_bytes()
        backup = path.with_suffix('.c.ris-original')
        original = backup.read_bytes() if current.startswith(MARK.encode()) else current
        if hashlib.sha256(original).hexdigest() != digest:
            raise SystemExit('Unsupported/modified vendor source (expected Vitis 2022.2 lwip211_v1_8): ' + str(path))
        updated = render(name, original.decode()).encode()
        stamp = path.with_suffix('.c.ris-sha256')
        if current.startswith(MARK.encode()) and current != updated and stamp.exists():
            if hashlib.sha256(current).hexdigest() != stamp.read_text().strip():
                raise SystemExit('Patched source changed outside this script; regenerate platform first: ' + str(path))
        plans.append((path, backup, original, updated))
    for path, backup, original, updated in plans:
        if not backup.exists():
            backup.write_bytes(original)
        if path.read_bytes() != updated:
            path.write_bytes(updated)
        path.with_suffix('.c.ris-sha256').write_text(hashlib.sha256(updated).hexdigest() + '\n')
    for path, content in [(inc / 'ris_dual_gem.h', HEADER), (netif / 'ris_dual_gem.inc', HELPER)]:
        if not path.exists() or path.read_text() != content:
            path.write_text(content)
    print('Applied/verified project dual-GEM patch for Vitis 2022.2 lwip211_v1_8', flush=True)
    if args.rebuild:
        if shutil.which('arm-none-eabi-gcc') is None:
            raise SystemExit('Source Vitis 2022.2 settings64.sh before --rebuild')
        # The vendor makefile does not track local .inc includes.
        for name in EXPECTED:
            (src / (Path(name).stem + '.o')).unlink(missing_ok=True)
        subprocess.run(['make', '-C', str(bsp), '-s'], check=True)
        if export:
            for name in ('liblwip4.a', 'libxil.a'):
                dest = export / 'bsplib/lib' / name
                if not dest.parent.is_dir():
                    raise SystemExit('Missing generated export directory: ' + str(dest.parent))
                shutil.copy2(bsp / 'ps7_cortexa9_0/lib' / name, dest)
            dest = export / 'bspinclude/include/netif/ris_dual_gem.h'
            shutil.copy2(inc / 'ris_dual_gem.h', dest)
            print('Rebuilt and synchronized liblwip4.a, libxil.a and header to ' + str(export), flush=True)

if __name__ == '__main__':
    main()
