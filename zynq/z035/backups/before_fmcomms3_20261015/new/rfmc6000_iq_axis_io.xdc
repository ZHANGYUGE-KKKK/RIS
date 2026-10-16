# RFMC6000 RX pin template for PZ7035-FH, xc7z035ffg900.
# Add to the project ONLY after these 16 physical ports exist at the top.
# Rename ports below if BD Make External adds a suffix. This file is NOT
# scoped to the RTL reference; package-pin constraints apply to top ports.
# BANK12/13 VCCO=1.8 V; receiver LVDS_25, external differential termination.
set_property -dict {PACKAGE_PIN AB27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_clk_p]
set_property -dict {PACKAGE_PIN AC27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_clk_n]
set_property -dict {PACKAGE_PIN T30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_frame_p]
set_property -dict {PACKAGE_PIN U30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_frame_n]
set_property -dict {PACKAGE_PIN W29 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[0]}]
set_property -dict {PACKAGE_PIN W30 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[0]}]
set_property -dict {PACKAGE_PIN U24 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[1]}]
set_property -dict {PACKAGE_PIN V24 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[1]}]
set_property -dict {PACKAGE_PIN T24 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[2]}]
set_property -dict {PACKAGE_PIN T25 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[2]}]
set_property -dict {PACKAGE_PIN N28 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[3]}]
set_property -dict {PACKAGE_PIN P28 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[3]}]
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[4]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[4]}]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_p[5]}]
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports {rx_data_n[5]}]
# Maximum dual-RX rate: Fs=61.44 MSPS, DATA_CLK=4*Fs=245.76 MHz.
# Change this period if the configured sample rate differs; use only one
# create_clock on this port. Board-specific DDR set_input_delay values must
# be added from AD9361 output timing, actual interface delay and PCB skew.
create_clock -name rfmc_rx -period 4.069 [get_ports rx_clk_p]
