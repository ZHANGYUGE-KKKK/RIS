/* RIS_DUAL_GEM_V1: project-local Vitis 2022.2 patch. */
/*
 * Copyright (C) 2010 - 2022 Xilinx, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * This file is part of the lwIP TCP/IP stack.
 *
 */

#include "netif/xemacpsif.h"
#include "netif/ris_dual_gem.h"
#include "lwipopts.h"

#if XPAR_GIGE_PCS_PMA_1000BASEX_CORE_PRESENT == 1 || \
	XPAR_GIGE_PCS_PMA_SGMII_CORE_PRESENT == 1
#define PCM_PMA_CORE_PRESENT
#else
#undef PCM_PMA_CORE_PRESENT
#endif

#undef PCM_PMA_CORE_PRESENT
extern XEmacPs_Config XEmacPs_ConfigTable[];
extern u32_t phymapemac0[32];
extern u32_t phymapemac1[32];

#if !NO_SYS
extern long xInsideISR;
#endif

XEmacPs_Config *xemacps_lookup_config(unsigned mac_base)
{
	XEmacPs_Config *cfgptr = NULL;
	s32_t i;

	for (i = 0; i < XPAR_XEMACPS_NUM_INSTANCES; i++) {
		if (XEmacPs_ConfigTable[i].BaseAddress == mac_base) {
			cfgptr = &XEmacPs_ConfigTable[i];
			break;
		}
	}

	return (cfgptr);
}

void init_emacps(xemacpsif_s *xemacps, struct netif *netif)
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

void setup_isr (struct xemac_s *xemac)
{
	xemacpsif_s   *xemacpsif;

	xemacpsif = (xemacpsif_s *)(xemac->state);
	/*
	 * Setup callbacks
	 */
	XEmacPs_SetHandler(&xemacpsif->emacps, XEMACPS_HANDLER_DMASEND,
				     (void *) emacps_send_handler,
				     (void *) xemac);

	XEmacPs_SetHandler(&xemacpsif->emacps, XEMACPS_HANDLER_DMARECV,
				    (void *) emacps_recv_handler,
				    (void *) xemac);

	XEmacPs_SetHandler(&xemacpsif->emacps, XEMACPS_HANDLER_ERROR,
				    (void *) emacps_error_handler,
				    (void *) xemac);
}

void start_emacps (xemacpsif_s *xemacps)
{
	/* start the temac */
	XEmacPs_Start(&xemacps->emacps);
}

void restart_emacps_transmitter (xemacpsif_s *xemacps) {
	u32_t Reg;
	Reg = XEmacPs_ReadReg(xemacps->emacps.Config.BaseAddress,
					XEMACPS_NWCTRL_OFFSET);
	Reg = Reg & (~XEMACPS_NWCTRL_TXEN_MASK);
	XEmacPs_WriteReg(xemacps->emacps.Config.BaseAddress,
										XEMACPS_NWCTRL_OFFSET, Reg);

	Reg = XEmacPs_ReadReg(xemacps->emacps.Config.BaseAddress,
						XEMACPS_NWCTRL_OFFSET);
	Reg = Reg | (XEMACPS_NWCTRL_TXEN_MASK);
	XEmacPs_WriteReg(xemacps->emacps.Config.BaseAddress,
										XEMACPS_NWCTRL_OFFSET, Reg);
}

void emacps_error_handler(void *arg,u8 Direction, u32 ErrorWord)
{
	struct xemac_s *xemac;
	xemacpsif_s   *xemacpsif;
	XEmacPs_BdRing *rxring;
	XEmacPs_BdRing *txring;
#if !NO_SYS
	xInsideISR++;
#endif

	xemac = (struct xemac_s *)(arg);
	xemacpsif = (xemacpsif_s *)(xemac->state);
	rxring = &XEmacPs_GetRxRing(&xemacpsif->emacps);
	txring = &XEmacPs_GetTxRing(&xemacpsif->emacps);

	if (ErrorWord != 0) {
		switch (Direction) {
			case XEMACPS_RECV:
			if (ErrorWord & XEMACPS_RXSR_HRESPNOK_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Receive DMA error\r\n"));
				HandleEmacPsError(xemac);
			}
			if (ErrorWord & XEMACPS_RXSR_RXOVR_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Receive over run\r\n"));
				emacps_recv_handler(arg);
				setup_rx_bds(xemacpsif, rxring);
			}
			if (ErrorWord & XEMACPS_RXSR_BUFFNA_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Receive buffer not available\r\n"));
				emacps_recv_handler(arg);
				setup_rx_bds(xemacpsif, rxring);
			}
			break;
			case XEMACPS_SEND:
			if (ErrorWord & XEMACPS_TXSR_HRESPNOK_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Transmit DMA error\r\n"));
				HandleEmacPsError(xemac);
			}
			if (ErrorWord & XEMACPS_TXSR_URUN_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Transmit under run\r\n"));
				HandleTxErrors(xemac);
			}
			if (ErrorWord & XEMACPS_TXSR_BUFEXH_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Transmit buffer exhausted\r\n"));
				HandleTxErrors(xemac);
			}
			if (ErrorWord & XEMACPS_TXSR_RXOVR_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Transmit retry excessed limits\r\n"));
				HandleTxErrors(xemac);
			}
			if (ErrorWord & XEMACPS_TXSR_FRAMERX_MASK) {
				LWIP_DEBUGF(NETIF_DEBUG, ("Transmit collision\r\n"));
				process_sent_bds(xemacpsif, txring);
			}
			break;
		}
	}
#if !NO_SYS
	xInsideISR--;
#endif
}
