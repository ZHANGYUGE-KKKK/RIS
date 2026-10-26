set root [file normalize [file join [file dirname [info script]] ..]]
set out $root/reports/implementation
file mkdir $out
file mkdir $root/export
open_project $root/vivado/PZ_UART.xpr
set_param general.maxThreads 8
synth_design -top zc706_top -part xc7z045ffg900-2
source $root/scripts/mig_2g_delay_groups.tcl
write_checkpoint -force $out/synth.dcp
report_io -file $out/io_synth.rpt
report_timing_summary -max_paths 10 -file $out/timing_synth.rpt
close_project
source $root/scripts/implement_zc706.tcl
