set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/reports/uplink
file mkdir $out
set_param general.maxThreads 6
open_project $root/vivado/PZ_UART.xpr
set bd [get_files design_1.bd]
open_bd_design $bd
set locked [get_ips -all -filter {IS_LOCKED == 1}]
if {[llength $locked]} {upgrade_ip $locked -log $out/upgrade_ips.log}
report_ip_status -file $out/ip_status.rpt
source $root/scripts/configure_rx_pl_eth.tcl
set ps [get_bd_cells processing_system7_0]
set_property -dict [list \
    CONFIG.PCW_QSPI_PERIPHERAL_ENABLE 1 \
    CONFIG.PCW_QSPI_QSPI_IO {MIO 1 .. 6} \
    CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE 1 CONFIG.PCW_QSPI_GRP_FBCLK_IO {MIO 8} \
    CONFIG.PCW_QSPI_GRP_IO1_ENABLE 1 CONFIG.PCW_QSPI_GRP_IO1_IO {MIO 0 9 .. 13} \
    CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE 0 CONFIG.PCW_QSPI_GRP_SS1_ENABLE 0 \
    CONFIG.PCW_DUAL_PARALLEL_QSPI_DATA_MODE x8 \
    CONFIG.PCW_QSPI_PERIPHERAL_CLKSRC {IO PLL} CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ 200] $ps
validate_bd_design -force
if {[get_property CONFIG.PCW_EN_QSPI $ps] != 1} {error "QSPI did not enable"}
save_bd_design
puts RECEIVER_QSPI_DUAL_PARALLEL_CONFIGURED
set_property synth_checkpoint_mode None $bd
generate_target all $bd
make_wrapper -files $bd -top
set xdc $root/constraints/zc706_pl_eth.xdc
if {![llength [get_files -quiet $xdc]]} {add_files -fileset constrs_1 $xdc}
set_property top zc706_top [get_filesets sources_1]
update_compile_order -fileset sources_1
write_bd_tcl -force $out/design_1.tcl
synth_design -top zc706_top -part xc7z045ffg900-2
source $root/scripts/mig_2g_delay_groups.tcl
write_checkpoint -force $out/rx_uplink_synth.dcp
report_timing_summary -max_paths 10 -file $out/timing_synth.rpt
report_utilization -file $out/utilization_synth.rpt
report_io -file $out/io_synth.rpt
puts RECEIVER_UPLINK_SYNTH_OK
write_hw_platform -fixed -force -file $out/rx_uplink_hw.xsa
puts RECEIVER_UPLINK_XSA_OK
