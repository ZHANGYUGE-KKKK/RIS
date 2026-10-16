# AD-FMCOMMS3-EBZ Rev.A on PZ7035-FH J26 FMC-HPC.
# Sources: ad-fmcomms3_reva.pdf sheets 2/3/4 and carrier schematic sheet 18.
# Map PHYSICAL FMC contacts, not the old RFMC6000 module's LA labels.
# Carrier FMC LA banks and VADJ default to 1.8 V.

# SPI0 EMIO, CPOL=0/CPHA=1, SS0; DI/DO directions relative to AD9361.
# DI C26 -> AF30; DO C27 -> AG30; CLK D27 -> AK30; ENB D26 -> AJ30.
set_property -dict {PACKAGE_PIN AF30 IOSTANDARD LVCMOS18} [get_ports SPI_9361_io0_io]
set_property -dict {PACKAGE_PIN AG30 IOSTANDARD LVCMOS18} [get_ports SPI_9361_io1_io]
set_property -dict {PACKAGE_PIN AK30 IOSTANDARD LVCMOS18} [get_ports SPI_9361_sck_io]
set_property -dict {PACKAGE_PIN AJ30 IOSTANDARD LVCMOS18 PULLUP true} [get_ports SPI_9361_ss_io]
# RESETB: H31 / LA28_P -> AC29; PS GPIO EMIO[0], XGpioPs pin 54.
# Module R103 already pulls RESETB to VDD_INTERFACE through 10 kOhm.
set_property -dict {PACKAGE_PIN AC29 IOSTANDARD LVCMOS18} [get_ports {GPIO_PS_tri_io[0]}]

# Register-controlled ENSM/MGC. External controls held low in board top.
# ENABLE G18; TXNRX G19; EN_AGC H22; SYNC_IN H23.
set_property -dict {PACKAGE_PIN P25 IOSTANDARD LVCMOS18} [get_ports rf_enable]
set_property -dict {PACKAGE_PIN P26 IOSTANDARD LVCMOS18} [get_ports rf_txnrx]
set_property -dict {PACKAGE_PIN T22 IOSTANDARD LVCMOS18} [get_ports rf_en_agc]
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS18} [get_ports rf_sync_in]

# DATA_CLK G6/G7; RX_FRAME D8/D9.
# LVDS_25 input-only operation with 1.8 V HR-bank VCCO requires DIFF_TERM=false
# (UG471). Do not enable the 2.5 V HR termination at 1.8 V. The FMCOMMS3
# schematic shows no external RX 100 Ohm termination: verify receive signal
# integrity / physical termination before claiming lossless IQ capture.
set_property -dict {PACKAGE_PIN R27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_clk_p]
set_property -dict {PACKAGE_PIN T27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_clk_n]
set_property -dict {PACKAGE_PIN R25 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_frame_p]
set_property -dict {PACKAGE_PIN R26 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_frame_n]
# RX_D0 H7/H8; D1 G9/G10; D2 H10/H11; D3 D11/D12;
# D4 C10/C11; D5 H13/H14. Preserve physical P/N polarity.
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[0]}]
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[0]}]
set_property -dict {PACKAGE_PIN N28 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[1]}]
set_property -dict {PACKAGE_PIN P28 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[1]}]
set_property -dict {PACKAGE_PIN T24 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[2]}]
set_property -dict {PACKAGE_PIN T25 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[2]}]
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[3]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[3]}]
set_property -dict {PACKAGE_PIN T30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[4]}]
set_property -dict {PACKAGE_PIN U30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[4]}]
set_property -dict {PACKAGE_PIN N29 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[5]}]
set_property -dict {PACKAGE_PIN P29 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[5]}]

# Fs=61.44 MSPS, dual RX LVDS DDR: DATA_CLK=4*Fs=245.76 MHz.
create_clock -name rfmc_rx -period 4.069 [get_ports rx_clk_p]
