# Dedicated MT hardware build; accepted FAST/QSPI packages are retained.
set root [file normalize [file join [file dirname [info script]] ..]]
set report $root/reports/mt
set out $root/build/mt_hardware
file mkdir $report $out $root/export_mt
set_param general.maxThreads 4
open_project $root/vivado_mt/ris_ctrl_unit.xpr
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
report_cdc -file $report/cdc.rpt
set f [open $report/timing.rpt];set timing [read $f];close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "MT timing failed; checkpoint retained"}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]]} {error "MT DRC failed"}
close_project
open_checkpoint $out/routed.dcp
write_bitstream -force $root/export_mt/ris_ctrl_unit.bit
write_hw_platform -fixed -include_bit -force -file $root/export_mt/ris_ctrl_unit.xsa
close_project
puts RIS_MT_BUILD_PASS
exit
