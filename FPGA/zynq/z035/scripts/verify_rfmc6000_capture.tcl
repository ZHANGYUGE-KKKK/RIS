set project_dir [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $project_dir PZ_UART.xpr]
set_param general.maxThreads 4
open_bd_design [get_files */design_1.bd]
validate_bd_design
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    [string match *ERROR* [get_property STATUS [get_runs synth_1]]]} {
    error "Capture hardware synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
open_run synth_1
opt_design
report_drc -file [file join $project_dir reports capture_drc.rpt] -force
report_io -file [file join $project_dir reports capture_io.rpt] -force
report_utilization -file [file join $project_dir reports capture_utilization.rpt] -force
write_checkpoint -force [file join $project_dir reports capture_opt.dcp]
puts "CAPTURE_SYNTH_OPT_OK"
