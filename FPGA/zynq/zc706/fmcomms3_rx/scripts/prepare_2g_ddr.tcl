set root [file normalize [file join [file dirname [info script]] ..]]
set f [open $root/reports/mig2g_active.txt];set report [string trim [read $f]];close $f
open_project $root/vivado/PZ_UART.xpr
set_param general.maxThreads 8
set bd [get_files */design_1.bd]
open_bd_design $bd
source $root/scripts/configure_2g_ddr.tcl
validate_bd_design
save_bd_design
set_property synth_checkpoint_mode None $bd
generate_target all $bd
add_files -norecurse [make_wrapper -files $bd -top]
set_property top zc706_top [current_fileset]
update_compile_order -fileset sources_1
write_bd_tcl -force $root/scripts/zc706_bd_export.tcl
report_ip_status -file $report/ip_status.rpt
set f [open $report/mig2g_connections.txt w]
foreach pin {ad9361_rx_axis_0/ref_clk200 mig_7series_0/sys_clk_i mig_7series_0/clk_ref_i mig_7series_0/ui_clk} {
    puts $f "$pin -> [get_bd_nets -of_objects [get_bd_pins $pin]]"
}
foreach s [get_bd_addr_spaces] {puts $f "$s -> [get_bd_addr_segs -of_objects $s]"}
close $f
close_project
puts RX_DDR2G_PREPARED
exit
