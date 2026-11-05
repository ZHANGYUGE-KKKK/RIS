# Rebuild the actual project after the receiver reset/CDC timing fix.
# No clock periods or input data timing are relaxed.
set ris_project [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $ris_project PZ_UART.xpr]
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
set ris_cdc [get_files *rfmc6000_iq_axis_cdc.xdc]
if {[llength $ris_cdc] != 1} {error "Receiver CDC file missing or ambiguous"}
set_property SCOPED_TO_REF rfmc6000_iq_axis $ris_cdc
open_bd_design [get_files */design_1.bd]
update_module_reference [get_ips design_1_rfmc6000_iq_axis_0_0]
validate_bd_design
save_bd_design
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis did not finish"}
launch_runs impl_1 -to_step route_design -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation did not finish"}
open_run impl_1
set ris_report_dir [file join $ris_project reports rfmc6000_timing_fix]
file mkdir $ris_report_dir
report_timing_summary -max_paths 10 -file [file join $ris_report_dir timing_route.rpt]
report_cdc -details -file [file join $ris_report_dir cdc.rpt]
report_bus_skew -file [file join $ris_report_dir bus_skew.rpt]
report_exceptions -file [file join $ris_report_dir exceptions.rpt]
report_drc -file [file join $ris_report_dir drc.rpt]
set ris_setup [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 100]
set ris_hold [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 100]
if {[llength $ris_setup] || [llength $ris_hold]} {
    error "Timing violations remain: setup=[llength $ris_setup], hold=[llength $ris_hold]"
}
puts "RFMC6000_INTEGRATED_SETUP_HOLD_PASS"
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Bitstream generation did not finish"}
puts "RFMC6000_TIMING_FIX_BITSTREAM_COMPLETE"
close_project
exit
