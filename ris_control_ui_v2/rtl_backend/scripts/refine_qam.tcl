# Resume physical optimization of this copy's routed, source-matched checkpoint.
set root [file normalize [file join [file dirname [info script]] ..]]
set report $root/reports/qam
set out $root/build/qam_hardware
set_param general.maxThreads 4
exec sha256sum --check $report/source_sha256.txt
open_checkpoint $out/routed.dcp
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
write_checkpoint -force $out/routed.dcp
report_timing_summary -max_paths 20 -file $report/timing.rpt
report_drc -file $report/drc.rpt
report_route_status -file $report/route_status.rpt
report_utilization -file $report/utilization.rpt
report_cdc -file $report/cdc.rpt
set f [open $report/timing.rpt];set timing [read $f];close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "QAM timing failed; checkpoint retained"}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]]} {error "QAM DRC failed"}
# Do not export a checkpoint built from sources edited during this run.
exec sha256sum --check $report/source_sha256.txt
close_project
open_checkpoint $out/routed.dcp
write_bitstream -force $root/export_qam/ris_ctrl_unit.bit
write_hw_platform -fixed -include_bit -force -file $root/export_qam/ris_ctrl_unit.xsa
close_project
puts RIS_QAM_BUILD_PASS
exit
