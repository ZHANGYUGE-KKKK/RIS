set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/reports/implementation
set_param general.maxThreads 8
open_checkpoint $out/synth.dcp
implement_debug_core
write_debug_probes -force $root/export/zc706_top.ltx
puts [exec python3 $root/scripts/check_ad9361_rx_probes.py $root/export/zc706_top.ltx]
opt_design
place_design -directive Explore
phys_opt_design -directive Explore
route_design -directive Explore
write_checkpoint -force $out/routed.dcp
report_timing_summary -max_paths 20 -file $out/timing_route.rpt
report_cdc -details -file $out/cdc.rpt
report_drc -file $out/drc.rpt
report_bus_skew -file $out/bus_skew.rpt
report_route_status -file $out/route_status.rpt
report_utilization -hierarchical -file $out/utilization.rpt
report_io -file $out/io.rpt
report_clocks -file $out/clocks.rpt
report_clock_interaction -file $out/clock_interaction.rpt
check_timing -verbose -file $out/check_timing.rpt
write_xdc -force $out/effective_constraints.xdc
set fd [open $out/timing_route.rpt]; set timing [read $fd]; close $fd
if {![string match {*All user specified timing constraints are met.*} $timing]} {
    error "ZC706 timing failed; routed checkpoint retained for repair"
}
write_bitstream -force $root/export/zc706_top.bit
write_debug_probes -force $root/export/zc706_top.ltx
close_design
open_checkpoint $out/routed.dcp
write_hw_platform -fixed -include_bit -force -file $root/export/zc706_top.xsa
# Export regenerates bitstream metadata. Use the exact embedded BIT after
# verifying that the complete FPGA configuration payload is unchanged.
exec python3 $root/scripts/finalize_zc706_export.py $root
set fd [open $out/status.txt w]; puts $fd "PASS: routed BIT/LTX/XSA"; close $fd
close_design
puts ZC706_BUILD_PASS
exit
