# Remove the unused legacy ILA from the project; keep its files on disk.
set ila_project_dir [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $ila_project_dir PZ_UART.xpr]
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $ila_project_dir} {
    error "Open PZ_UART in $ila_project_dir first."
}
set ila_compile_files [get_files -compile_order sources -used_in synthesis]
foreach ila_compile_file $ila_compile_files {
    if {[file tail $ila_compile_file] eq "key_ctrl_55.v"} {
        error "key_ctrl_55 is now active; keep its ILA instead of removing it."
    }
}
set ila_unused_file [get_files -quiet */ila_0/ila_0.xci]
if {[llength $ila_unused_file]} {
    set ila_backup_dir [file join $ila_project_dir backups before_unused_ila_removal_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
    file mkdir $ila_backup_dir
    file copy [file join $ila_project_dir PZ_UART.xpr] $ila_backup_dir
    remove_files $ila_unused_file
}
if {[llength [get_files -quiet */ila_0/ila_0.xci]]} {
    error "Legacy ILA remains registered in the project."
}
puts "UNUSED_ILA_REMOVED_OK"
