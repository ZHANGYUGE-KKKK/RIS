set_param general.maxThreads 6
open_project ../zynq/zc706/fmcomms3_rx/vivado/PZ_UART.xpr
set bd [get_files design_1.bd]
open_bd_design $bd
report_ip_status -file ip_status_before.rpt
set locked [get_ips -all -filter {IS_LOCKED == 1}]
if {[llength $locked]} { puts "LOCKED_IPS $locked"; upgrade_ip $locked -log upgrade_ips.log }
report_ip_status -file ip_status_after.rpt
validate_bd_design -force
save_bd_design
set_property synth_checkpoint_mode None $bd
generate_target all $bd
update_compile_order -fileset sources_1
set_property top zc706_top [get_filesets sources_1]
synth_design -top zc706_top -part xc7z045ffg900-2
write_checkpoint -force baseline_synth.dcp
report_utilization -file baseline_utilization.rpt
report_timing_summary -file baseline_timing.rpt
puts "BASELINE_SYNTH_OK"
