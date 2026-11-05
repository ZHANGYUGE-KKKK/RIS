# Isolated high-speed implementation; retains the accepted bring-up package.
set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/build/fast_toggle
set report $root/reports/fast_toggle
file mkdir $out $report $root/export_network_fast
set_param general.maxThreads 4
open_project $root/vivado_fast/ris_ctrl_unit.xpr
synth_design -top ris_ctrl_unit_top -part xc7z045ffg900-2 -directive RuntimeOptimized
write_checkpoint -force $out/synth.dcp
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force $out/routed.dcp
report_timing_summary -max_paths 20 -file $report/timing.rpt
report_drc -file $report/drc.rpt
report_route_status -file $report/route_status.rpt
report_utilization -file $report/utilization.rpt
report_clocks -file $report/clocks.rpt
set fast_clock [get_clocks -of_objects [get_pins -hier -filter {REF_PIN_NAME == CLKOUT0 && NAME =~ *u_mmcm*}]]
if {[llength $fast_clock]!=1 || abs([get_property PERIOD $fast_clock]-10.0/3.0)>0.001} {error "Expected one 300 MHz fast-toggle clock"}
report_cdc -file $report/cdc.rpt
set f [open $report/timing.rpt]; set timing [read $f]; close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "Fast-toggle timing failed; DCP retained"}
set severe [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $severe]} {error "Fast-toggle DRC failed: $severe"}
close_project
source $root/scripts/export_fast.tcl
puts RIS_FAST_BUILD_PASS
exit
