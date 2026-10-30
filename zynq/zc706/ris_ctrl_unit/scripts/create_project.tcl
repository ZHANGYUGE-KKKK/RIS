# Vivado 2020.2: vivado -mode batch -source scripts/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set project_dir $root/vivado_axi
set frame_slots 256
set fast_toggle 0
set qspi_enable 0
set report_dir $root/reports
if {[info exists ::env(RIS_QSPI_ENABLE)]} {set qspi_enable $::env(RIS_QSPI_ENABLE)}
if {[info exists ::env(RIS_REPORT_DIR)]} {set report_dir $::env(RIS_REPORT_DIR)}
if {[info exists ::env(RIS_FAST_TOGGLE)]} {set fast_toggle $::env(RIS_FAST_TOGGLE)}
if {[info exists ::env(RIS_PROJECT_DIR)]} {set project_dir [file normalize $::env(RIS_PROJECT_DIR)]}
if {[info exists ::env(RIS_FRAME_SLOTS)]} {set frame_slots $::env(RIS_FRAME_SLOTS)}
if {![string is integer -strict $frame_slots] || $frame_slots<1 || $frame_slots>256} {error "Invalid frame capacity"}
set project_file $project_dir/ris_ctrl_unit.xpr
if {[file exists $project_file]} {
    error "Project already exists: $project_file (open it instead of overwriting it)"
}
file mkdir $report_dir
create_project ris_ctrl_unit $project_dir -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_param general.maxThreads 4
add_files -norecurse [concat [glob $root/rtl/*.v] [glob $root/rtl/*.sv]]

create_bd_design ris_system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
# Local snapshot of ../fmcomms3_rx/constraints/zc706_ps_preset.tcl.
source $root/constraints/zc706_ps_preset.tcl
set_property -dict $zc706_ps_preset $ps
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 1 CONFIG.PCW_USE_M_AXI_GP1 0 \
    CONFIG.PCW_USE_S_AXI_HP0 0 CONFIG.PCW_USE_S_AXI_HP1 0 \
    CONFIG.PCW_USE_S_AXI_HP2 0 CONFIG.PCW_USE_S_AXI_HP3 0 \
    CONFIG.PCW_UART0_PERIPHERAL_ENABLE 0 \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE 1 \
    CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
    CONFIG.PCW_UART_PERIPHERAL_FREQMHZ 100 \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 100 \
    CONFIG.PCW_FPGA_FCLK0_ENABLE 1 CONFIG.PCW_FPGA_FCLK1_ENABLE 0 \
    CONFIG.PCW_FPGA_FCLK2_ENABLE 0 CONFIG.PCW_FPGA_FCLK3_ENABLE 0 \
    CONFIG.PCW_SPI0_PERIPHERAL_ENABLE 0 CONFIG.PCW_SPI1_PERIPHERAL_ENABLE 0 \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 0 CONFIG.PCW_QSPI_PERIPHERAL_ENABLE $qspi_enable \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE 0 CONFIG.PCW_I2C0_PERIPHERAL_ENABLE 0 \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE 0 CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 0 \
    CONFIG.PCW_I2C_RESET_ENABLE 0 CONFIG.PCW_I2C0_RESET_ENABLE 0 \
    CONFIG.PCW_USB0_RESET_ENABLE 0] $ps
foreach intf {DDR FIXED_IO} {
    make_bd_intf_pins_external [get_bd_intf_pins ps7/$intf]
    set_property name $intf [get_bd_intf_ports ${intf}_0]
}

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset_pl
# ext_reset_in polarity is propagated from PS FCLK_RESET0_N by BD validation.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_one
set_property -dict [list CONFIG.CONST_WIDTH 1 CONFIG.CONST_VAL 1] [get_bd_cells constant_one]
connect_bd_net [get_bd_pins constant_one/dout] [get_bd_pins reset_pl/dcm_locked]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins reset_pl/ext_reset_in]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 control_bus
set_property CONFIG.NUM_MI 1 [get_bd_cells control_bus]
create_bd_cell -type module -reference ris_controller_axi controller
set_property -dict [list CONFIG.ID_WIDTH 12 CONFIG.FRAME_SLOTS $frame_slots CONFIG.FAST_TOGGLE_ENABLE $fast_toggle] [get_bd_cells controller]
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins control_bus/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins control_bus/M00_AXI] [get_bd_intf_pins controller/S_AXI]
foreach pin {ps7/M_AXI_GP0_ACLK reset_pl/slowest_sync_clk control_bus/ACLK control_bus/S00_ACLK control_bus/M00_ACLK controller/s_axi_aclk} {
    connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins $pin]
}
foreach pin {control_bus/ARESETN control_bus/S00_ARESETN control_bus/M00_ARESETN} {
    connect_bd_net [get_bd_pins reset_pl/interconnect_aresetn] [get_bd_pins $pin]
}
connect_bd_net [get_bd_pins reset_pl/peripheral_aresetn] [get_bd_pins controller/s_axi_aresetn]
foreach name {ris_data ris_shcp ris_stcp ris_mr_n ris_oe_n} {
    make_bd_pins_external [get_bd_pins controller/$name]
    set_property name $name [get_bd_ports ${name}_0]
}
assign_bd_address -offset 0x41200000 -range 0x10000 \
    -target_address_space [get_bd_addr_spaces ps7/Data] \
    [get_bd_addr_segs -of_objects [get_bd_intf_pins controller/S_AXI]] -force
validate_bd_design
save_bd_design
set bd [get_files */ris_system.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
add_files -fileset constrs_1 -norecurse $root/constraints/ris_lpc.xdc
set_property PROCESSING_ORDER LATE [get_files */ris_lpc.xdc]
if {$fast_toggle} {
    add_files -fileset constrs_1 -norecurse $root/constraints/ris_fast.xdc
    set_property PROCESSING_ORDER LATE [get_files */ris_fast.xdc]
}
add_files -fileset sim_1 -norecurse $root/tests/tb_ris_controller.sv
set_property top ris_ctrl_unit_top [current_fileset]
set_property top tb_ris_controller [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
write_bd_tcl -force $report_dir/ris_axi_system_bd.tcl
report_ip_status -file $report_dir/ip_status.rpt
close_project
puts RIS_AXI_PROJECT_PASS
exit
