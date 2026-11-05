/* The FIR tables come from RFMC6000's vitis_7035 example.
 * Board reference adapted for FMCOMMS3 Rev.A: onboard 40 MHz crystal/DCXO.
 * Keep board transport separate and check every configuration API result.
 */
#include "ad_config.h"
#include "ad_config_port.h"
#include "ad9361_api.h"
#include "radio_set.h" /* Definitions: include in this translation unit only. */

#include <string.h>
#include "xil_printf.h"
#include "xpseudo_asm.h"
#include "xtime_l.h"

#define AD_CONFIG_RX_LO_HZ 200000000ULL
#define AD_CONFIG_TX_LO_HZ 5997000000ULL
#define AD_CONFIG_GAIN_DB 5
#define AD_CONFIG_TX_ATTENUATION_MDB 0U

volatile ad_config_report_type ad_config_report;

static int check_step(const char *name, int status)
{
    if (status == 0)
        status = ad_config_port_error();
    if (status != 0)
        xil_printf("AD CONFIG step failed: %s, result=%d\r\n", name, status);
    return status;
}

static int snapshot(ad9361_device *transport)
{
    static const u16 registers[] = {
        REG_CH_1_OVERFLOW, REG_RX_CP_OVERRANGE_VCO_LOCK,
        REG_TX_CP_OVERRANGE_VCO_LOCK, REG_CALIBRATION_CTRL, REG_STATE,
        REG_PARALLEL_PORT_CONF_1, REG_PARALLEL_PORT_CONF_2, REG_PARALLEL_PORT_CONF_3,
        REG_CLOCK_ENABLE
    };
    volatile u32 *const fields[] = {
        &ad_config_report.bbpll_status, &ad_config_report.rxpll_status,
        &ad_config_report.txpll_status, &ad_config_report.calibration,
        &ad_config_report.ensm_state, &ad_config_report.port_conf[0],
        &ad_config_report.port_conf[1], &ad_config_report.port_conf[2],
        &ad_config_report.clock_enable
    };
    u32 index;
    u8 value, tx_enable, rx_enable, rx_delay, invert1, invert2;

    for (index = 0U; index < ARRAY_SIZE(registers); ++index) {
        *fields[index] = 0xFFFFFFFFU;
        if (ad9361_reg_read(transport, registers[index], &value) != AD9361_OK)
            return -EIO;
        *fields[index] = value;
    }
    xil_printf("AD CONFIG registers: 05E=%02x 247=%02x 287=%02x 016=%02x 017=%02x\r\n",
               (unsigned int)ad_config_report.bbpll_status,
               (unsigned int)ad_config_report.rxpll_status,
               (unsigned int)ad_config_report.txpll_status,
               (unsigned int)ad_config_report.calibration,
               (unsigned int)ad_config_report.ensm_state);
    xil_printf("AD CONFIG interface: 010=%02x 011=%02x 012=%02x\r\n",
               (unsigned int)ad_config_report.port_conf[0],
               (unsigned int)ad_config_report.port_conf[1],
               (unsigned int)ad_config_report.port_conf[2]);
    xil_printf("FMCOMMS3 clock: 009=%02x, XO_BYPASS=%d (expected 0 for onboard crystal)\r\n",
               (unsigned int)ad_config_report.clock_enable,
               (ad_config_report.clock_enable & XO_BYPASS) != 0U);
    if (ad9361_reg_read(transport, REG_TX_ENABLE_FILTER_CTRL, &tx_enable) != AD9361_OK ||
        ad9361_reg_read(transport, REG_RX_ENABLE_FILTER_CTRL, &rx_enable) != AD9361_OK ||
        ad9361_reg_read(transport, REG_RX_CLOCK_DATA_DELAY, &rx_delay) != AD9361_OK ||
        ad9361_reg_read(transport, REG_LVDS_INVERT_CTRL1, &invert1) != AD9361_OK ||
        ad9361_reg_read(transport, REG_LVDS_INVERT_CTRL2, &invert2) != AD9361_OK)
        return -EIO;
    xil_printf("AD CONFIG channels/delay: 002=%02x 003=%02x 006=%02x 03D=%02x 03E=%02x\r\n",
               (unsigned)tx_enable, (unsigned)rx_enable, (unsigned)rx_delay,
               (unsigned)invert1, (unsigned)invert2);
    if ((tx_enable & 0xC0U) != 0xC0U || (rx_enable & 0xC0U) != 0xC0U)
        return AD_CONFIG_ERR_READBACK;
    return 0;
}

int ad_config_init(ad_config_device *dev, ad9361_device *transport)
{
    struct ad9361_rf_phy *phy = NULL;
    XTime started, now;
    u32 value, channel;
    u64 frequency;
    s32 gain;
    u8 enabled;
    int status;

    if (dev == NULL || transport == NULL)
        return AD_CONFIG_ERR_NOT_READY;
    if (dev->attempted)
        return AD_CONFIG_ERR_RETRY;
    dev->attempted = 1U;
    dev->ready = 0U;
    dev->phy = NULL;
    memset((void *)&ad_config_report, 0, sizeof(ad_config_report));
    ad_config_report.magic = 0x41444346U; /* ADCF */
    ad_config_report.result = AD_CONFIG_ERR_NOT_READY;
    XTime_GetTime(&started);
    xil_printf("\r\nAD CONFIG: FMCOMMS3 Rev.A, onboard 40 MHz crystal/DCXO, BEGIN\r\n");
    xil_printf("REF=40000000 Hz; RX LO=200 MHz; TX LO=5997 MHz; Fs=%d Hz; BW=%d Hz\r\n",
               AD_CONFIG_SAMPLE_HZ, AD_CONFIG_BANDWIDTH_HZ);
    xil_printf("2R2T FDD LVDS DDR, repeated FRAME, MGC=5 dB; capture ARM=0\r\n");
    xil_printf("Reference: Y101 crystal, internal DCXO enabled; no CDCM6208\r\n");
    status = ad_config_port_bind(transport);
    if (status != 0)
        goto finished;
    default_init_param.gpio_resetb = AD9361_RESET_GPIO_PIN;
    default_init_param.gpio_sync = -1;
    default_init_param.gpio_cal_sw1 = -1;
    default_init_param.gpio_cal_sw2 = -1;
    default_init_param.reference_clk_rate = 40000000UL;
    default_init_param.xo_disable_use_ext_refclk_enable = 0;
    default_init_param.ensm_enable_pin_pulse_mode_enable = 0;
    default_init_param.ensm_enable_txnrx_control_enable = 0;
    /* Preserve the template's 40 MSPS / 2.4 GHz initial clock/calibration
     * sequence, then apply main.c's final parameters, as the example does.
     */
    ad_config_report.stage = 1U;
    xil_printf("AD CONFIG [1] reference initialization and calibrations\r\n");
    status = check_step("reference initialization", ad9361_noos_init(&phy, &default_init_param));
    if (status != 0)
        goto finished;
    dev->phy = phy;

#define AD_CONFIG_STEP(name, expression) \
    do { status = check_step((name), (expression)); if (status != 0) goto finished; } while (0)

    ad_config_report.stage = 2U;
    xil_printf("AD CONFIG [2] reference profile: RX/TX FIR 2x, 64 taps\r\n");
    AD_CONFIG_STEP("TX clock/data delay", ad9361_spi_write(phy->spi, REG_TX_CLOCK_DATA_DELAY, 0x40));
    AD_CONFIG_STEP("disable FIR", ad9361_set_trx_fir_en_dis(phy, 0));
    AD_CONFIG_STEP("TX FIR coefficients", ad9361_set_tx_fir_config(phy, tx_fir_config_2_64));
    AD_CONFIG_STEP("RX FIR coefficients", ad9361_set_rx_fir_config(phy, rx_fir_config_2_64));
    AD_CONFIG_STEP("sample rate", ad9361_set_tx_sampling_freq(phy, AD_CONFIG_SAMPLE_HZ));
    AD_CONFIG_STEP("enable reference FIR", ad9361_set_trx_fir_en_dis(phy, 1));
    {
        uint32_t rx_rates[6], tx_rates[6];
        u8 raw;
        AD_CONFIG_STEP("clock-chain readback", ad9361_get_trx_path_clks(phy, rx_rates, tx_rates));
        xil_printf("RX clock chain: %d %d %d %d %d %d Hz\r\n",
                   rx_rates[0], rx_rates[1], rx_rates[2], rx_rates[3], rx_rates[4], rx_rates[5]);
        xil_printf("TX clock chain: %d %d %d %d %d %d Hz\r\n",
                   tx_rates[0], tx_rates[1], tx_rates[2], tx_rates[3], tx_rates[4], tx_rates[5]);
        for (value = 0x041U; value <= 0x045U; ++value) {
            AD_CONFIG_STEP("BBPLL raw register", ad9361_reg_read(transport, (u16)value, &raw));
            xil_printf("CLOCK REG %03x=%02x\r\n", value, raw);
        }
        AD_CONFIG_STEP("BBPLL divider", ad9361_reg_read(transport, 0x00AU, &raw));
        xil_printf("CLOCK REG 00A=%02x\r\n", raw);
        AD_CONFIG_STEP("LVDS bias readback", ad9361_reg_read(transport, 0x03CU, &raw));
        xil_printf("CLOCK REG 03C=%02x\r\n", raw);
    }

    ad_config_report.stage = 3U;
    xil_printf("AD CONFIG [3] LO, bandwidth and gain\r\n");
    AD_CONFIG_STEP("TX LO", ad9361_set_tx_lo_freq(phy, AD_CONFIG_TX_LO_HZ));
    AD_CONFIG_STEP("RX LO", ad9361_set_rx_lo_freq(phy, AD_CONFIG_RX_LO_HZ));
    AD_CONFIG_STEP("RX bandwidth", ad9361_set_rx_rf_bandwidth(phy, AD_CONFIG_BANDWIDTH_HZ));
    AD_CONFIG_STEP("TX bandwidth", ad9361_set_tx_rf_bandwidth(phy, AD_CONFIG_BANDWIDTH_HZ));
    for (channel = 0U; channel < 2U; ++channel) {
        AD_CONFIG_STEP("manual gain mode", ad9361_set_rx_gain_control_mode(phy, (u8)channel, RF_GAIN_MGC));
        AD_CONFIG_STEP("RX gain", ad9361_set_rx_rf_gain(phy, (u8)channel, AD_CONFIG_GAIN_DB));
        AD_CONFIG_STEP("TX attenuation", ad9361_set_tx_attenuation(phy, (u8)channel, AD_CONFIG_TX_ATTENUATION_MDB));
    }

    ad_config_report.stage = 4U;
    xil_printf("AD CONFIG [4] parameter readback and PLL checks\r\n");
    AD_CONFIG_STEP("RX sample readback", ad9361_get_rx_sampling_freq(phy, &value));
    ad_config_report.rx_sample_hz = value;
    AD_CONFIG_STEP("TX sample readback", ad9361_get_tx_sampling_freq(phy, &value));
    ad_config_report.tx_sample_hz = value;
    AD_CONFIG_STEP("RX BW readback", ad9361_get_rx_rf_bandwidth(phy, &value));
    ad_config_report.rx_bandwidth_hz = value;
    AD_CONFIG_STEP("TX BW readback", ad9361_get_tx_rf_bandwidth(phy, &value));
    ad_config_report.tx_bandwidth_hz = value;
    AD_CONFIG_STEP("RX LO readback", ad9361_get_rx_lo_freq(phy, &frequency));
    ad_config_report.rx_lo_mhz = (u32)((frequency + 500000U) / 1000000U);
    if (frequency < AD_CONFIG_RX_LO_HZ - 100U || frequency > AD_CONFIG_RX_LO_HZ + 100U) {
        status = AD_CONFIG_ERR_READBACK;
        goto finished;
    }
    AD_CONFIG_STEP("TX LO readback", ad9361_get_tx_lo_freq(phy, &frequency));
    ad_config_report.tx_lo_mhz = (u32)((frequency + 500000U) / 1000000U);
    if (frequency < AD_CONFIG_TX_LO_HZ - 100U || frequency > AD_CONFIG_TX_LO_HZ + 100U) {
        status = AD_CONFIG_ERR_READBACK;
        goto finished;
    }
    for (channel = 0U; channel < 2U; ++channel) {
        AD_CONFIG_STEP("RX gain readback", ad9361_get_rx_rf_gain(phy, (u8)channel, &gain));
        ad_config_report.rx_gain_db[channel] = gain;
        AD_CONFIG_STEP("TX attenuation readback", ad9361_get_tx_attenuation(phy, (u8)channel, &value));
        ad_config_report.tx_attenuation_mdb[channel] = value;
    }
    AD_CONFIG_STEP("RX FIR enable readback", ad9361_get_rx_fir_en_dis(phy, &enabled));
    ad_config_report.rx_fir_enabled = enabled;
    AD_CONFIG_STEP("TX FIR enable readback", ad9361_get_tx_fir_en_dis(phy, &enabled));
    ad_config_report.tx_fir_enabled = enabled;
    AD_CONFIG_STEP("register snapshot", snapshot(transport));
    if ((ad_config_report.bbpll_status & BBPLL_LOCK) == 0U ||
        (ad_config_report.rxpll_status & VCO_LOCK) == 0U ||
        (ad_config_report.txpll_status & VCO_LOCK) == 0U ||
        ad_config_report.calibration != 0U ||
        (ad_config_report.clock_enable & XO_BYPASS) != 0U) {
        status = AD_CONFIG_ERR_PLL;
        goto finished;
    }
    if (ad_config_report.rx_sample_hz < AD_CONFIG_SAMPLE_HZ - 10U ||
        ad_config_report.rx_sample_hz > AD_CONFIG_SAMPLE_HZ + 10U ||
        ad_config_report.tx_sample_hz < AD_CONFIG_SAMPLE_HZ - 10U ||
        ad_config_report.tx_sample_hz > AD_CONFIG_SAMPLE_HZ + 10U ||
        ad_config_report.rx_bandwidth_hz != AD_CONFIG_BANDWIDTH_HZ ||
        ad_config_report.tx_bandwidth_hz != AD_CONFIG_BANDWIDTH_HZ ||
        ad_config_report.rx_gain_db[0] != AD_CONFIG_GAIN_DB ||
        ad_config_report.rx_gain_db[1] != AD_CONFIG_GAIN_DB ||
        ad_config_report.tx_attenuation_mdb[0] != AD_CONFIG_TX_ATTENUATION_MDB ||
        ad_config_report.tx_attenuation_mdb[1] != AD_CONFIG_TX_ATTENUATION_MDB ||
        ad_config_report.rx_fir_enabled != 1U || ad_config_report.tx_fir_enabled != 1U ||
        (ad_config_report.port_conf[0] & 0x08U) == 0U ||
        (ad_config_report.port_conf[2] & 0x10U) == 0U) {
        status = AD_CONFIG_ERR_READBACK;
        goto finished;
    }
    AD_CONFIG_STEP("chip ID after config", ad9361_check_online(transport));
    dev->ready = 1U;
    xil_printf("AD CONFIG readback: RX Fs=%d TX Fs=%d Hz, RX BW=%d TX BW=%d Hz\r\n",
               (unsigned int)ad_config_report.rx_sample_hz, (unsigned int)ad_config_report.tx_sample_hz,
               (unsigned int)ad_config_report.rx_bandwidth_hz, (unsigned int)ad_config_report.tx_bandwidth_hz);
    xil_printf("AD CONFIG readback: RX LO=%d TX LO=%d MHz; RX gains=%d/%d dB\r\n",
               (unsigned int)ad_config_report.rx_lo_mhz, (unsigned int)ad_config_report.tx_lo_mhz,
               (int)ad_config_report.rx_gain_db[0], (int)ad_config_report.rx_gain_db[1]);
#undef AD_CONFIG_STEP

finished:
    if (status != 0 && transport->spi_ready)
        (void)snapshot(transport);
    if (status != 0)
        xil_printf("AD CONFIG wait: reg=0x%03x mask=0x%02x value=%d; transport_error=%d\r\n",
                   (unsigned int)ad_config_report.wait_reg, (unsigned int)ad_config_report.wait_mask,
                   (int)ad_config_report.wait_value, (int)ad_config_report.io_error);
    XTime_GetTime(&now);
    ad_config_report.elapsed_ms = (u32)((now - started) / (COUNTS_PER_SECOND / 1000U));
    ad_config_report.result = status;
    dsb();
    ad_config_report.done = 1U;
    dsb();
    xil_printf("AD CONFIG %s: stage=%d result=%d (%s), SPI read/write bytes=%d/%d, elapsed=%d ms\r\n",
               status == 0 ? "PASS" : "FAILED", (int)ad_config_report.stage, status,
               ad_config_status_string(status), (unsigned int)ad_config_report.spi_reads,
               (unsigned int)ad_config_report.spi_writes, (unsigned int)ad_config_report.elapsed_ms);
    return status;
}

int ad_config_rx_bist_tone(ad_config_device *dev, u8 enabled)
{
    struct ad9361_rf_phy *phy;
    int status, value;

    if (dev == NULL || !dev->ready || dev->phy == NULL || enabled > 1U)
        return AD_CONFIG_ERR_NOT_READY;
    phy = (struct ad9361_rf_phy *)dev->phy;
    status = check_step("RX BIST tone", ad9361_bist_tone(phy,
                enabled ? BIST_INJ_RX : BIST_DISABLE,
                AD_CONFIG_BIST_TONE_HZ, 6U, 0U));
    if (status != 0)
        return status;
    value = ad9361_spi_read(phy->spi, REG_BIST_CONFIG);
    if (value < 0 || ((value & BIST_ENABLE) != 0) != (enabled != 0U) ||
        (enabled && value != 0x5B))
        return AD_CONFIG_ERR_READBACK;
    xil_printf("RX BIST tone %s: Fs/%d=%d Hz, -6 dBFS, reg3F4=%02x\r\n",
               enabled ? "ON" : "OFF", AD_CONFIG_BIST_PERIOD,
               AD_CONFIG_BIST_TONE_HZ, value);
    return 0;
}

const char *ad_config_status_string(int status)
{
    switch (status) {
    case 0: return "OK";
    case -EIO: return "SPI/reset I/O failed";
    case -ENOMEM: return "reference driver allocation failed";
    case -ENODEV: return "AD9361 not ready/detected";
    case -EINVAL: return "invalid reference parameter";
    case -ETIMEDOUT: return "PLL/calibration/SPI timeout";
    case AD_CONFIG_ERR_NOT_READY: return "SPI/reset precondition failed";
    case AD_CONFIG_ERR_RETRY: return "restart PS/program before retry";
    case AD_CONFIG_ERR_READBACK: return "configured parameter readback mismatch";
    case AD_CONFIG_ERR_PLL: return "PLL not locked or calibration incomplete";
    default: return "reference driver error";
    }
}
