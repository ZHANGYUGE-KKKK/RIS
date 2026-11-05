# Apply to the current PZ_UART design in the GUI, or run in batch mode.
# MIG configuration and DDR pin selections are preserved.
set fix_dir [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $fix_dir PZ_UART.xpr]
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $fix_dir} {
    error "Open the PZ_UART project in $fix_dir first."
}
set fix_bd [get_files */design_1.bd]
open_bd_design $fix_bd
set fix_backup [file join $fix_dir backups before_axi_reset_fix_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $fix_backup
file copy $fix_bd [file join $fix_backup design_1.bd]
file copy [file join $fix_dir PZ_UART.xpr] [file join $fix_backup PZ_UART.xpr]
set fix_wrapper [file join $fix_dir PZ_UART.srcs sources_1 bd design_1 hdl design_1_wrapper.v]
if {[file exists $fix_wrapper]} {file copy $fix_wrapper $fix_backup}

set_property -dict [list CONFIG.PCW_NAND_CYCLES_T_RC {30} CONFIG.PCW_NAND_CYCLES_T_WC {30}] [get_bd_cells processing_system7_0]

proc fix_attach {source destination} {
    set fix_source [get_bd_pins $source]
    set fix_destination [get_bd_pins $destination]
    set fix_old_net [get_bd_nets -quiet -of_objects $fix_destination]
    set fix_source_net [get_bd_nets -quiet -of_objects $fix_source]
    if {[llength $fix_old_net] && $fix_old_net eq $fix_source_net} {return}
    if {[llength $fix_old_net]} {disconnect_bd_net $fix_old_net $fix_destination}
    connect_bd_net $fix_source $fix_destination
}

if {[llength [get_bd_cells -quiet rst_ps_fclk0]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps_fclk0
}
# Vivado propagates ext_reset_in polarity from the connected reset source.
set_property CONFIG.C_AUX_RESET_HIGH {1} [get_bd_cells rst_ps_fclk0]
foreach {fix_cell fix_value} {reset_const_zero 0 reset_const_one 1} {
    if {[llength [get_bd_cells -quiet $fix_cell]] == 0} {
        create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 $fix_cell
    }
    set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL $fix_value] [get_bd_cells $fix_cell]
}
fix_attach processing_system7_0/FCLK_CLK0 rst_ps_fclk0/slowest_sync_clk
fix_attach processing_system7_0/FCLK_RESET0_N rst_ps_fclk0/ext_reset_in
fix_attach reset_const_zero/dout rst_ps_fclk0/aux_reset_in
fix_attach reset_const_zero/dout rst_ps_fclk0/mb_debug_sys_rst
fix_attach reset_const_one/dout rst_ps_fclk0/dcm_locked
fix_attach rst_ps_fclk0/interconnect_aresetn axi_interconnect_0/S00_ARESETN

# The existing reset block belongs to the MIG ui_clk domain. Calibration
# completion is a ready signal: low must hold reset and high must release it.
set_property CONFIG.C_AUX_RESET_HIGH {0} [get_bd_cells proc_sys_reset_0]
fix_attach mig_7series_0/mmcm_locked proc_sys_reset_0/dcm_locked
fix_attach reset_const_zero/dout proc_sys_reset_0/mb_debug_sys_rst

validate_bd_design -force
save_bd_design
generate_target all $fix_bd
puts "AXI_RESET_AND_NAND_FIX_OK"
