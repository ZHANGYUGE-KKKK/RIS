set root [file normalize [file join [file dirname [info script]] ..]]
open_project $root/vivado/ddr2g_test.xpr
set_param general.maxThreads 8
synth_design -top ddr_test_wrapper -part xc7z045ffg900-2
source $root/scripts/mig_delay_groups.tcl
write_checkpoint -force $root/reports/synth.dcp
opt_design
place_design -directive Explore
phys_opt_design -directive Explore
route_design -directive Explore
write_checkpoint -force $root/reports/routed.dcp
report_timing_summary -max_paths 10 -file $root/reports/timing.rpt
report_drc -file $root/reports/drc.rpt
report_io -file $root/reports/io.rpt
report_cdc -details -file $root/reports/cdc.rpt
report_route_status -file $root/reports/route_status.rpt
set bad [get_timing_paths -quiet -slack_lesser_than 0 -max_paths 1]
if {[llength $bad]} {error "Timing failed; no BIT exported"}
set bad_hold [get_timing_paths -quiet -delay_type min -slack_lesser_than 0 -max_paths 1]
if {[llength $bad_hold]} {error "Hold timing failed; no BIT exported"}
set drc_errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $drc_errors]} {error "DRC errors; no BIT exported: $drc_errors"}
write_bitstream -force $root/export/ddr2g_test.bit
close_project
# Reopen the routed checkpoint in non-project mode for include_bit export.
source $root/scripts/export_final.tcl
