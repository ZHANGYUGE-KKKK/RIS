# Can be sourced in the GUI or run in batch mode. No BD/IP settings change.
set board_top_dir [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $board_top_dir PZ_UART.xpr]
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $board_top_dir} {
    error "Open PZ_UART in $board_top_dir first."
}
set board_top_bd [get_files */design_1.bd]
open_bd_design $board_top_bd
# Remove the previous hand-edited wrapper so Vivado generates the full interface.
set board_top_wrapper [file join [file dirname $board_top_bd] hdl design_1_wrapper.v]
if {[file exists $board_top_wrapper]} {
    set board_top_backup [file join $board_top_dir backups before_wrapper_regeneration_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
    file mkdir $board_top_backup
    file copy $board_top_wrapper $board_top_backup
    file delete $board_top_wrapper
}
make_wrapper -files $board_top_bd -top -force
set board_top_file [file join $board_top_dir PZ_UART.srcs sources_1 new pz7035_top.v]
if {[llength [get_files -quiet $board_top_file]] == 0} {
    add_files -norecurse $board_top_file
}
set_property top pz7035_top [get_filesets sources_1]
set_property top_auto_set 0 [get_filesets sources_1]
set_property top pz7035_top [get_filesets sim_1]
set_property top_auto_set 0 [get_filesets sim_1]
update_compile_order -fileset sources_1
puts "BOARD_TOP_CONFIGURED=pz7035_top"
