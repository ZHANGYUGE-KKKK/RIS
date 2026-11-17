set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/reports/uplink
set_param general.maxThreads 8
open_checkpoint $out/rx_uplink_synth.dcp
implement_debug_core
opt_design
place_design -directive Explore
phys_opt_design -directive Explore
route_design -directive Explore
write_checkpoint -force $out/rx_uplink_routed.dcp
report_timing_summary -max_paths 20 -file $out/timing_route.rpt
report_drc -file $out/drc.rpt
report_bus_skew -file $out/bus_skew.rpt
report_route_status -file $out/route_status.rpt
report_io -file $out/io_route.rpt
set fd [open $out/timing_route.rpt]
set timing [read $fd]
close $fd
if {![string match {*All user specified timing constraints are met.*} $timing]} {
    error "Receiver timing failed; routed checkpoint retained"
}
write_bitstream -force $out/zc706_rx_uplink.bit
write_debug_probes -force $out/zc706_rx_uplink.ltx
puts [exec python3 $root/scripts/check_ad9361_rx_probes.py $out/zc706_rx_uplink.ltx]
write_hw_platform -fixed -include_bit -force -file $out/zc706_rx_uplink.xsa
puts RECEIVER_UPLINK_ROUTE_OK
