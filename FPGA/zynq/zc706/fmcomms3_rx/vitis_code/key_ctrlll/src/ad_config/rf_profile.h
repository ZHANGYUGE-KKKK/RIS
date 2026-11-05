#ifndef RX_RF_PROFILE_H
#define RX_RF_PROFILE_H

/* Compile-time GUI profile. Change this default to RX_RF_PROFILE_915 to
 * restore the existing 915 MHz application, then rebuild the application. */
#define RX_RF_PROFILE_915 915
#define RX_RF_PROFILE_2P4 2400
#ifndef RX_RF_PROFILE
#define RX_RF_PROFILE RX_RF_PROFILE_2P4
#endif

#if RX_RF_PROFILE == RX_RF_PROFILE_2P4
#define RX_RF_PROFILE_NAME "CONFIG2P4"
#define RX_RF_LO_HZ 2400000000U
#define RX_RF_LO_MHZ 2400U
#define RX_RF_TX_BIST 0x00U
#define RX_RF_TX_BIST_MASK 0x00U
#define RX_RF_TX_DESCRIPTION "TX BIST OFF (external RX)"
#define RX_RF_START_POWER_DBM (-80)
#elif RX_RF_PROFILE == RX_RF_PROFILE_915
#define RX_RF_PROFILE_NAME "CONFIG915"
#define RX_RF_LO_HZ 915000000U
#define RX_RF_LO_MHZ 915U
#define RX_RF_TX_BIST 0x53U
#define RX_RF_TX_BIST_MASK 0x30U
#define RX_RF_TX_DESCRIPTION "TX1 BIST~960 kHz"
#define RX_RF_START_POWER_DBM (-40)
#else
#error Unsupported RX_RF_PROFILE: choose RX_RF_PROFILE_915 or RX_RF_PROFILE_2P4
#endif

#define RX_RF_SOURCE1_MHZ (RX_RF_LO_MHZ + 1U)
#define RX_RF_SOURCE2_MHZ (RX_RF_LO_MHZ + 2U)

#endif
