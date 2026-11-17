# Keep all BD wiring and MIG settings. Pipeline only the ILA probe inputs.
set pipe_dir [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $pipe_dir PZ_UART.xpr]
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $pipe_dir} {
    error "Open PZ_UART in $pipe_dir first."
}
set pipe_bd [get_files */design_1.bd]
open_bd_design $pipe_bd
set pipe_backup [file join $pipe_dir backups before_ila_pipeline_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $pipe_backup
file copy $pipe_bd [file join $pipe_backup design_1.bd]
file copy [file join $pipe_dir PZ_UART.xpr] $pipe_backup
file copy [file join $pipe_dir PZ_UART.srcs sources_1 bd design_1 ip design_1_mig_7series_0_0 mig_a.prj] $pipe_backup
set_property CONFIG.C_INPUT_PIPE_STAGES {2} [get_bd_cells ila_ddr]
validate_bd_design -force
save_bd_design
generate_target all $pipe_bd
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
puts "ILA_INPUT_PIPELINE_CONFIGURED"
