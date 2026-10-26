set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir $root/reports/migration
open_project $root/vivado/PZ_UART.xpr
set_param general.maxThreads 8
source $root/scripts/zc706_sources.tcl
add_files -norecurse $root/PZ_UART.srcs/sources_1/new/zc706_top.v
set bd [get_files */design_1.bd]
open_bd_design $bd
set_property part xc7z045ffg900-2 [current_project]
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]
set mig [get_bd_cells mig_7series_0]
set_property CONFIG.BOARD_MIG_PARAM Custom $mig
set_property CONFIG.RESET_BOARD_INTERFACE Custom $mig
set_property CONFIG.XML_INPUT_FILE $root/constraints/zc706_mig.prj $mig
upgrade_ip [get_ips -all]
source $root/constraints/zc706_ps_preset.tcl
set ps [get_bd_cells processing_system7_0]
# Preserve the existing logical interface and frequency contract. Only the
# board DDR/MIO routing comes from the official ZC706 preset.
set ps_settings [concat $zc706_ps_preset [list \
 CONFIG.PCW_UART0_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
 CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
 CONFIG.PCW_UART_PERIPHERAL_FREQMHZ {100} \
 CONFIG.PCW_SPI0_PERIPHERAL_ENABLE {1} \
 CONFIG.PCW_SPI0_SPI0_IO {EMIO} \
 CONFIG.PCW_SPI1_PERIPHERAL_ENABLE {1} \
 CONFIG.PCW_SPI1_SPI1_IO {EMIO} \
 CONFIG.PCW_SPI_PERIPHERAL_FREQMHZ {166.666666} \
 CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} \
 CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH {1} \
 CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
 CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
 CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_SD0_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_USB0_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_I2C_RESET_ENABLE {0} \
 CONFIG.PCW_I2C0_RESET_ENABLE {0} \
 CONFIG.PCW_USB0_RESET_ENABLE {0} \
]]
set_property -dict $ps_settings $ps
set mig [get_bd_cells mig_7series_0]
set_property CONFIG.BOARD_MIG_PARAM Custom $mig
set_property CONFIG.RESET_BOARD_INTERFACE Custom $mig
set_property CONFIG.XML_INPUT_FILE $root/constraints/zc706_mig.prj $mig
# Refresh the module reference without changing the receiver implementation.
source $root/scripts/configure_2g_ddr.tcl
source $root/scripts/configure_full_2g_address.tcl
update_module_reference [get_ips design_1_ad9361_rx_axis_0_0]
validate_bd_design
save_bd_design
set_property synth_checkpoint_mode None $bd
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
set_property top zc706_top [current_fileset]
foreach old {key_ctrl_55_jm1.xdc rfmc6000_iq_axis_io.xdc fmcomms3_io.xdc} {
    remove_files [get_files -quiet $old]
}
add_files -fileset constrs_1 -norecurse [list \
 $root/constraints/zc706_board.xdc \
 $root/constraints/zc706_fmcomms3_hpc.xdc \
 $root/constraints/zc706_ris_lpc.xdc \
 $root/constraints/zc706_rx_timing.xdc \
 $root/PZ_UART.srcs/constrs_1/new/ad9361_rx_cdc.xdc \
 $root/PZ_UART.srcs/constrs_1/new/ad9361_rx_ila.xdc]
set_property SCOPED_TO_REF {} [get_files ad9361_rx_cdc.xdc]
set_property PROCESSING_ORDER LATE [get_files ad9361_rx_ila.xdc]
foreach {file ref} {ad_rst_constr.xdc ad_rst up_xfer_cntrl_constr.xdc up_xfer_cntrl up_xfer_status_constr.xdc up_xfer_status up_clock_mon_constr.xdc up_clock_mon} {
    add_files -fileset constrs_1 -norecurse $root/PZ_UART.srcs/sources_1/adi_hdl/library/xilinx/common/$file
    set_property SCOPED_TO_REF $ref [get_files $file]
}
update_compile_order -fileset sources_1
report_ip_status -file $root/reports/migration/ip_status.rpt
write_bd_tcl -force $root/scripts/zc706_bd_export.tcl
set fd [open $root/reports/migration/prepare_status.txt w]
puts $fd "PASS: ZC706 board/PS/SODIMM/HPC/LPC adaptation and BD validation"
close $fd
close_project
puts ZC706_PREPARE_PASS
exit
