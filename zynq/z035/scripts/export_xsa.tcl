set export_dir [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $export_dir PZ_UART.xpr]
if {[get_property NEEDS_REFRESH [get_runs impl_1]]} {
    error "Implementation is out of date; rebuild the current top before exporting."
}
open_run impl_1
set export_summary [report_timing_summary -return_string]
if {![string match {*All user specified timing constraints are met.*} $export_summary]} {
    error "Timing requirements are not met; hardware export stopped."
}
set export_top_name [get_property TOP [get_filesets sources_1]]
set export_file [file join $export_dir ${export_top_name}.xsa]
if {[file exists $export_file]} {
    set export_backup [file join $export_dir backups before_xsa_export_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
    file mkdir $export_backup
    file copy $export_file $export_backup
}
write_hw_platform -fixed -include_bit -force -file $export_file
puts "XSA_EXPORT_COMPLETE=$export_file"
close_project
