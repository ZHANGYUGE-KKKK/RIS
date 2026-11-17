# Boot operating point: config915, 006=0x0f, seven FPGA IDELAY taps=4.
# AD9361 Rev G p9: LVDS clock-to-data and clock-to-FRAME 0.25..1.25 ns.
# UG671 register 006: data/FRAME delay is typically 0.3 ns/LSB.
# The delay-cell PVT envelope below (0.20..0.40 ns/tap) and +/-0.50 ns PCB
# clock/data skew are explicit engineering budgets, not measured or vendor-
# guaranteed board limits. Retain them as assumptions for manual PN/debug.
# Static timing covers boot taps=4; runtime IDELAY tuning requires PN checks.
set rx_source_min [expr {0.25 + 15*0.20 - 0.50}]
set rx_source_max [expr {1.25 + 15*0.40 + 0.50}]
set rx_inputs [get_ports {rx_frame_p rx_data_p[*]}]
set_input_delay -clock [get_clocks rfmc_rx] -min $rx_source_min $rx_inputs
set_input_delay -clock [get_clocks rfmc_rx] -max $rx_source_max $rx_inputs
set_input_delay -clock [get_clocks rfmc_rx] -clock_fall -add_delay -min $rx_source_min $rx_inputs
set_input_delay -clock [get_clocks rfmc_rx] -clock_fall -add_delay -max $rx_source_max $rx_inputs

# Mode-1 PS SPI0, unchanged 651 kHz nominal software divider. The PS7 owns
# the internal serial-clock timing; these external budgets describe the slow
# peripheral/IOBUF boundary, independently of the unrelated RX clock.
create_clock -name spi_external_budget -period 1536.000
set spi_ios [get_ports {SPI_9361_io0_io SPI_9361_io1_io SPI_9361_sck_io SPI_9361_ss_io GPIO_PS_tri_io[0]}]
set_input_delay -clock [get_clocks spi_external_budget] -min 0.000 $spi_ios
set_input_delay -clock [get_clocks spi_external_budget] -max 100.000 $spi_ios
set_output_delay -clock [get_clocks spi_external_budget] -min 0.000 $spi_ios
set_output_delay -clock [get_clocks spi_external_budget] -max 10.000 $spi_ios

# ZC706 input-clock insertion leaves about 0.2 ns negative hold at zero taps.
# Four reference-calibrated IDELAY taps provide ~0.31 ns initial input delay.
# AXI IDELAY registers/readback and runtime PN scan remain unchanged.
set_property IDELAY_VALUE 4 [get_cells -hier -filter {NAME =~ *ad9361_rx_axis_0* && REF_NAME == IDELAYE2}]
