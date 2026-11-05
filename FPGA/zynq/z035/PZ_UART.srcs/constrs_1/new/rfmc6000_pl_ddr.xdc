# PZ7035-FH, xc7z035ffg900-2 + RFMC6000.
# User confirmed FMC VADJ and BANK12/13 VCCO are both 1.8 V.
# PL DDR pins/standards are supplied by the generated MIG constraints.

# Board differential oscillator: 200 MHz, BANK34 (DDR supply).
set_property -dict {PACKAGE_PIN H9 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN G9 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_n]
create_clock -name board_clk200 -period 5.000 [get_ports sys_clk_p]

# AD9361 configuration SPI. Directions are relative to the carrier FPGA.
# MOSI -> FMC C22 / LA18_P_CC; SCLK -> C23 / LA18_N_CC.
set_property -dict {PACKAGE_PIN U25 IOSTANDARD LVCMOS18} [get_ports rf_spi_mosi]
set_property -dict {PACKAGE_PIN V26 IOSTANDARD LVCMOS18} [get_ports rf_spi_sclk]
# CS_N -> H22 / LA19_P; MISO <- G21 / LA20_P.
set_property -dict {PACKAGE_PIN T22 IOSTANDARD LVCMOS18 PULLUP true} [get_ports rf_spi_csn]
set_property -dict {PACKAGE_PIN N26 IOSTANDARD LVCMOS18} [get_ports rf_spi_miso]

# PS GPIO EMIO[0:2]: RESETB (D23), ENABLE (H23), TXNRX (D21).
set_property -dict {PACKAGE_PIN T29 IOSTANDARD LVCMOS18} [get_ports {RF_CTRL_tri_io[0]}]
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS18} [get_ports {RF_CTRL_tri_io[1]}]
set_property -dict {PACKAGE_PIN U27 IOSTANDARD LVCMOS18} [get_ports {RF_CTRL_tri_io[2]}]

# Receive-only LVDS_25 input buffers can be used with 1.8 V HR VCCO.
# Internal DIFF_TERM requires 2.5 V and is therefore disabled here.
# The physical receive pairs must have suitable external differential
# termination; its presence/value still needs board-level verification.
set_property -dict {PACKAGE_PIN AB27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_clk_p}]
set_property -dict {PACKAGE_PIN AC27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_clk_n}]
set_property -dict {PACKAGE_PIN T30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_frame_in_p}]
set_property -dict {PACKAGE_PIN U30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_frame_in_n}]
set_property -dict {PACKAGE_PIN W29 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_p[0]}]
set_property -dict {PACKAGE_PIN W30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_n[0]}]
set_property -dict {PACKAGE_PIN U24 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_p[1]}]
set_property -dict {PACKAGE_PIN V24 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_n[1]}]
set_property -dict {PACKAGE_PIN T24 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_p[2]}]
set_property -dict {PACKAGE_PIN T25 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_n[2]}]
set_property -dict {PACKAGE_PIN N28 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_p[3]}]
set_property -dict {PACKAGE_PIN P28 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_n[3]}]
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_p[4]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_n[4]}]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_p[5]}]
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_in_n[5]}]
# Conservative maximum 2RX data-interface clock (4 * 61.44 MHz).
# Input-delay min/max must be finalized from the selected AD9361 interface
# timing and board skew; this file does not claim RX timing sign-off.
create_clock -name rf_rx_clk -period 4.069 [get_ports rx_clk_p]

# Custom two-stage synchronizers. AXI/FIFO IP own their internal CDC constraints.
set_false_path -to [get_pins -quiet -hier -filter {
    NAME =~ */ctrl_meta_reg*/D || NAME =~ */count_meta_reg*/D ||
    NAME =~ */rx_meta_reg*/D || NAME =~ */mode_meta_reg/D
    || NAME =~ */status_meta_reg*/D
}]
