# Vivado 2020.2: vivado -mode batch -source scripts/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set project_file $root/vivado/ris_ctrl_unit.xpr
if {[file exists $project_file]} {
    error "Project already exists: $project_file (open it instead of overwriting it)"
}
file mkdir $root/reports
create_project ris_ctrl_unit $root/vivado -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_param general.maxThreads 4
add_files -norecurse [list $root/rtl/ris_595_byte.v $root/rtl/ris_595_timing.v $root/rtl/ris_595_single.v $root/rtl/ris_595_bringup.v $root/rtl/ris_ctrl_unit_top.v]

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
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 0 CONFIG.PCW_QSPI_PERIPHERAL_ENABLE 0 \
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
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 control_gpio
set_property -dict [list CONFIG.C_IS_DUAL 1 CONFIG.C_GPIO_WIDTH 32 \
    CONFIG.C_GPIO2_WIDTH 32 CONFIG.C_ALL_OUTPUTS 1 CONFIG.C_ALL_INPUTS_2 1 \
    CONFIG.C_DOUT_DEFAULT 0x00000000] [get_bd_cells control_gpio]
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins control_bus/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins control_bus/M00_AXI] [get_bd_intf_pins control_gpio/S_AXI]
create_bd_cell -type module -reference ris_595_bringup bringup
set_property CONFIG.HALF_PERIOD_CYCLES 5 [get_bd_cells bringup]
foreach pin {ps7/M_AXI_GP0_ACLK reset_pl/slowest_sync_clk control_bus/ACLK control_bus/S00_ACLK control_bus/M00_ACLK control_gpio/s_axi_aclk bringup/clk} {
    connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins $pin]
}
foreach pin {control_bus/ARESETN control_bus/S00_ARESETN control_bus/M00_ARESETN} {
    connect_bd_net [get_bd_pins reset_pl/interconnect_aresetn] [get_bd_pins $pin]
}
foreach pin {control_gpio/s_axi_aresetn bringup/resetn} {
    connect_bd_net [get_bd_pins reset_pl/peripheral_aresetn] [get_bd_pins $pin]
}
connect_bd_net [get_bd_pins control_gpio/gpio_io_o] [get_bd_pins bringup/command]
connect_bd_net [get_bd_pins bringup/status] [get_bd_pins control_gpio/gpio2_io_i]
foreach name {ris_data ris_shcp ris_stcp ris_mr_n ris_oe_n} {
    make_bd_pins_external [get_bd_pins bringup/$name]
    set_property name $name [get_bd_ports ${name}_0]
}
assign_bd_address -offset 0x41200000 -range 0x10000 \
    -target_address_space [get_bd_addr_spaces ps7/Data] \
    [get_bd_addr_segs control_gpio/S_AXI/Reg] -force
validate_bd_design
save_bd_design
set bd [get_files */ris_system.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
add_files -fileset constrs_1 -norecurse $root/constraints/ris_lpc.xdc
set_property PROCESSING_ORDER LATE [get_files */ris_lpc.xdc]
add_files -fileset sim_1 -norecurse $root/tests/tb_ris_595.sv
set_property top ris_ctrl_unit_top [current_fileset]
set_property top tb_ris_595 [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
write_bd_tcl -force $root/reports/ris_system_bd.tcl
report_ip_status -file $root/reports/ip_status.rpt
close_project
puts RIS_CTRL_PROJECT_PASS
exit
