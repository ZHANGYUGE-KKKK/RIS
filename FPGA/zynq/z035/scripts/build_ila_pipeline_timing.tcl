set pipe_build_dir [file normalize [file join [file dirname [info script]] ..]]
source [file join $pipe_build_dir scripts configure_ila_timing_optimization.tcl]
source [file join $pipe_build_dir scripts fix_ila_clock_probe.tcl]
set_param general.maxThreads 4
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
report_timing_summary -max_paths 10 -file [file join $pipe_build_dir reports ddr_timing_optimized timing_pipeline.rpt]
report_bus_skew -warn_on_violation -file [file join $pipe_build_dir reports ddr_timing_optimized bus_skew_pipeline.rpt]
puts "PIPELINE_WNS=[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]] PIPELINE_WHS=[get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]"
set pipe_summary [report_timing_summary -return_string]
if {![string match {*All user specified timing constraints are met.*} $pipe_summary]} {
    error "Timing is still negative; see timing_pipeline.rpt."
}
set pipe_top_name [get_property TOP [get_filesets sources_1]]
write_debug_probes -force [file join $pipe_build_dir PZ_UART.runs impl_1 ${pipe_top_name}.ltx]
puts "ILA_PIPELINE_TIMING_PASS"
