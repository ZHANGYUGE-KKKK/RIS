# Resume the routed checkpoint after board-constraint fixes. No RTL change.
set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/reports/implementation
open_project $root/vivado/PZ_UART.xpr
open_checkpoint $out/routed.dcp
read_xdc $root/constraints/zc706_rx_timing.xdc
set_false_path -to [get_ports DDR3_0_reset_n]
puts "RX_BOOT_TAPS=[get_property IDELAY_VALUE [get_cells -hier -filter {NAME =~ *ad9361_rx_axis_0* && REF_NAME == IDELAYE2}]]"
phys_opt_design -hold_fix
route_design -directive Explore
write_checkpoint -force $out/routed.dcp
report_timing_summary -max_paths 20 -file $out/timing_route.rpt
report_cdc -details -file $out/cdc.rpt
report_drc -file $out/drc.rpt
report_bus_skew -file $out/bus_skew.rpt
report_route_status -file $out/route_status.rpt
report_io -file $out/io.rpt
check_timing -verbose -file $out/check_timing.rpt
write_xdc -force $out/effective_constraints.xdc
set fd [open $out/timing_route.rpt];set timing [read $fd];close $fd
if {![string match {*All user specified timing constraints are met.*} $timing]} {
    error "ZC706 timing still fails; inspect timing_route.rpt"
}
write_bitstream -force $root/export/zc706_top.bit
write_debug_probes -force $root/export/zc706_top.ltx
write_hw_platform -fixed -include_bit -force -file $root/export/zc706_top.xsa
exec python3 $root/scripts/finalize_zc706_export.py $root
set fd [open $out/status.txt w];puts $fd "PASS: routed BIT/LTX/XSA";close $fd
close_project
puts ZC706_BUILD_PASS
exit
