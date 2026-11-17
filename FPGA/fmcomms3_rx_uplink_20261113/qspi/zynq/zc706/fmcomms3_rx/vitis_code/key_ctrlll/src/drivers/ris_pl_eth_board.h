#ifndef RIS_PL_ETH_BOARD_H
#define RIS_PL_ETH_BOARD_H

/* Manufacturer ZC706 J18: GEM1/SGMII, Bank111 channel1, Si5324 CKOUT2. */
#define RIS_PL_ETH_PHY_ADDRESS 2U
#define RIS_PL_ETH_REFERENCE_HZ 125000000U

enum ris_pl_eth_board_result {
    RIS_PL_ETH_BOARD_OK = 0,
    RIS_PL_ETH_BOARD_ERR_CONFIG = -1,
    RIS_PL_ETH_BOARD_ERR_I2C_TIMEOUT = -2,
    RIS_PL_ETH_BOARD_ERR_I2C_TRANSFER = -3,
    RIS_PL_ETH_BOARD_ERR_MUX = -4,
    RIS_PL_ETH_BOARD_ERR_CLOCK_ID = -5,
    RIS_PL_ETH_BOARD_ERR_CLOCK_VERIFY = -6,
    RIS_PL_ETH_BOARD_ERR_CLOCK_LOCK = -7
};

/* Run once, after matching PS/PL hardware initialization and before GEM1.
 * Configures PS I2C0, MIO46 mux reset, EMIO55 PHY reset, EMIO56 clock reset.
 * All polls are bounded. On failure PHY reset stays asserted. Success means
 * Si5324 identity/configuration/lock were read back, not a measured line rate
 * or a verified Ethernet link. No PHY MDIO reset/negotiation is performed.
 */
int ris_pl_eth_board_init(void);

#endif
