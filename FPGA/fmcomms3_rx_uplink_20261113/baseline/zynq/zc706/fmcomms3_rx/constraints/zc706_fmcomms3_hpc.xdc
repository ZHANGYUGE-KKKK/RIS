# ZC706 Rev 2.0, XC7Z045-2FFG900; FMCOMMS3 on J37 FMC HPC.
# Sources: local ZC706_Rev2_0.pdf FPGA-bank/FMC sheets; FMCOMMS3 Rev A.
# FMC banks 11/13 are HR, supplied by VADJ_FPGA=2.5 V (board default).
# Keep VADJ=2.5 V for this bitstream. Native receive termination is enabled.

# G6: FMC_HPC_LA00_CC_P
set_property -dict {PACKAGE_PIN AF20 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_clk_p}]
# G7: FMC_HPC_LA00_CC_N
set_property -dict {PACKAGE_PIN AG20 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_clk_n}]
# D8: FMC_HPC_LA01_CC_P
set_property -dict {PACKAGE_PIN AG21 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_frame_p}]
# D9: FMC_HPC_LA01_CC_N
set_property -dict {PACKAGE_PIN AH21 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_frame_n}]
# H7: FMC_HPC_LA02_P
set_property -dict {PACKAGE_PIN AK17 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_p[0]}]
# H8: FMC_HPC_LA02_N
set_property -dict {PACKAGE_PIN AK18 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_n[0]}]
# G9: FMC_HPC_LA03_P
set_property -dict {PACKAGE_PIN AH19 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_p[1]}]
# G10: FMC_HPC_LA03_N
set_property -dict {PACKAGE_PIN AJ19 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_n[1]}]
# H10: FMC_HPC_LA04_P
set_property -dict {PACKAGE_PIN AJ20 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_p[2]}]
# H11: FMC_HPC_LA04_N
set_property -dict {PACKAGE_PIN AK20 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_n[2]}]
# D11: FMC_HPC_LA05_P
set_property -dict {PACKAGE_PIN AH23 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_p[3]}]
# D12: FMC_HPC_LA05_N
set_property -dict {PACKAGE_PIN AH24 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_n[3]}]
# C10: FMC_HPC_LA06_P
set_property -dict {PACKAGE_PIN AG22 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_p[4]}]
# C11: FMC_HPC_LA06_N
set_property -dict {PACKAGE_PIN AH22 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_n[4]}]
# H13: FMC_HPC_LA07_P
set_property -dict {PACKAGE_PIN AJ23 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_p[5]}]
# H14: FMC_HPC_LA07_N
set_property -dict {PACKAGE_PIN AJ24 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {rx_data_n[5]}]
# C26: FMC_HPC_LA27_P
set_property -dict {PACKAGE_PIN V28 IOSTANDARD LVCMOS25} [get_ports {SPI_9361_io0_io}]
# C27: FMC_HPC_LA27_N
set_property -dict {PACKAGE_PIN V29 IOSTANDARD LVCMOS25} [get_ports {SPI_9361_io1_io}]
# D27: FMC_HPC_LA26_N
set_property -dict {PACKAGE_PIN T28 IOSTANDARD LVCMOS25} [get_ports {SPI_9361_sck_io}]
# D26: FMC_HPC_LA26_P
set_property -dict {PACKAGE_PIN R28 IOSTANDARD LVCMOS25 PULLUP TRUE} [get_ports {SPI_9361_ss_io}]
# H31: FMC_HPC_LA28_P
set_property -dict {PACKAGE_PIN P30 IOSTANDARD LVCMOS25} [get_ports {GPIO_PS_tri_io[0]}]
# G18: FMC_HPC_LA16_P
set_property -dict {PACKAGE_PIN AA24 IOSTANDARD LVCMOS25} [get_ports {rf_enable}]
# G19: FMC_HPC_LA16_N
set_property -dict {PACKAGE_PIN AB24 IOSTANDARD LVCMOS25} [get_ports {rf_txnrx}]
# H22: FMC_HPC_LA19_P
set_property -dict {PACKAGE_PIN T24 IOSTANDARD LVCMOS25} [get_ports {rf_en_agc}]
# H23: FMC_HPC_LA19_N
set_property -dict {PACKAGE_PIN T25 IOSTANDARD LVCMOS25} [get_ports {rf_sync_in}]

create_clock -name rfmc_rx -period 16.276042 [get_ports rx_clk_p]
set_clock_uncertainty -setup 0.100 [get_clocks rfmc_rx]
set_clock_uncertainty -hold 0.050 [get_clocks rfmc_rx]
