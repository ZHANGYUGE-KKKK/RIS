# Run in the existing Vivado GUI after generating the BD Output Products.
# Keep that project and the final implemented design open for review.
set ris_project_dir [file normalize [file join [file dirname [info script]] ..]]
if {[current_project -quiet] eq ""} {
    open_project [file join $ris_project_dir PZ_UART.xpr]
}
if {[file normalize [get_property DIRECTORY [current_project]]] ne $ris_project_dir} {
    error "The active project is not PZ_UART in $ris_project_dir"
}
if {[get_property TOP [get_filesets sources_1]] ne "pz7035_top"} {
    error "Expected pz7035_top as the current top"
}
set ris_stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set ris_reports [file join $ris_project_dir reports gui_rebuild_$ris_stamp]
file mkdir $ris_reports
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
set ris_cdc [get_files -quiet *ad9361_rx_cdc.xdc]
if {[llength $ris_cdc] == 1 && [get_property IS_ENABLED $ris_cdc]} {
    set_property SCOPED_TO_REF ad9361_rx_axis $ris_cdc
    set ris_strict_cdc 1
} else {
    set ris_strict_cdc 0
    set ris_cdc [get_files *rfmc6000_iq_axis_cdc.xdc]
    if {[llength $ris_cdc] != 1} {error "Receiver CDC file missing or ambiguous"}
    set_property SCOPED_TO_REF rfmc6000_iq_axis $ris_cdc
}
if {[current_bd_design -quiet] ne ""} {
    save_bd_design
}
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
puts "RIS_GUI_SYNTHESIS_COMPLETE"
launch_runs impl_1 -to_step route_design -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
report_timing_summary -max_paths 10 -file [file join $ris_reports timing_route.rpt]
report_bus_skew -file [file join $ris_reports bus_skew.rpt]
report_cdc -details -file [file join $ris_reports cdc.rpt]
if {$ris_strict_cdc} {
    set ris_fd [open [file join $ris_reports cdc.rpt] r]
    set ris_cdc_report [read $ris_fd]
    close $ris_fd
    if {[regexp -line {^CDC-[0-9]+[ \t]+Critical[ \t]+[1-9]} $ris_cdc_report]} {
        error "Unresolved critical CDC paths; see $ris_reports/cdc.rpt"
    }
}
report_drc -file [file join $ris_reports drc.rpt]
set ris_fd [open [file join $ris_reports timing_route.rpt] r]
set ris_summary [read $ris_fd]
close $ris_fd
if {![string match {*All user specified timing constraints are met.*} $ris_summary]} {
    error "Timing did not close; see $ris_reports/timing_route.rpt"
}
set ris_fd [open [file join $ris_reports bus_skew.rpt] r]
set ris_skew [read $ris_fd]
close $ris_fd
if {[regexp -line {^\s+(Slow|Fast)\s+[0-9.]+\s+[0-9.]+\s+-[0-9.]+\s*$} $ris_skew]} {
    error "Bus skew violation; see $ris_reports/bus_skew.rpt"
}
puts "RIS_GUI_ROUTED_TIMING_PASS"
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Bitstream generation failed: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
set ris_xsa [file join $ris_project_dir pz7035_top.xsa]
if {[file exists $ris_xsa]} {
    set ris_backup [file join $ris_project_dir backups before_xsa_export_$ris_stamp]
    file mkdir $ris_backup
    file copy $ris_xsa $ris_backup
}
write_hw_platform -fixed -include_bit -force -file $ris_xsa
report_timing_summary -name ris_latest_timing_$ris_stamp -max_paths 10
puts "RIS_GUI_BUILD_EXPORT_COMPLETE=$ris_xsa"
puts "RIS_GUI_REPORTS=$ris_reports"
