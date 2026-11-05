set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir $root/reports $root/export
create_project ddr2g_test $root/vivado -part xc7z045ffg900-2 -force
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files [list $root/rtl/ddr_bist.sv $root/rtl/diag_cdc.sv]
add_files -fileset utils_1 -norecurse $root/scripts/mig_delay_groups.tcl
set_property file_type Verilog [get_files [list */ddr_bist.sv */diag_cdc.sv]]
create_bd_design ddr_test
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
source $root/constraints/zc706_ps_preset.tcl
set_property -dict $zc706_ps_preset $ps
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 1 CONFIG.PCW_USE_M_AXI_GP1 0 \
 CONFIG.PCW_USE_S_AXI_HP0 0 CONFIG.PCW_UART0_PERIPHERAL_ENABLE 0 \
 CONFIG.PCW_UART1_PERIPHERAL_ENABLE 1 CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
 CONFIG.PCW_UART_PERIPHERAL_FREQMHZ 100 CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 100 \
 CONFIG.PCW_FPGA_FCLK0_ENABLE 1 CONFIG.PCW_FPGA_FCLK1_ENABLE 0 \
 CONFIG.PCW_FPGA_FCLK2_ENABLE 0 CONFIG.PCW_SPI0_PERIPHERAL_ENABLE 0 \
 CONFIG.PCW_SPI1_PERIPHERAL_ENABLE 0 CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 0 \
 CONFIG.PCW_QSPI_PERIPHERAL_ENABLE 0 CONFIG.PCW_I2C0_PERIPHERAL_ENABLE 0 \
 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 0 CONFIG.PCW_USB0_PERIPHERAL_ENABLE 0 \
 CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 0 CONFIG.PCW_ENET0_PERIPHERAL_ENABLE 0 \
 CONFIG.PCW_I2C_RESET_ENABLE 0 CONFIG.PCW_I2C0_RESET_ENABLE 0 \
 CONFIG.PCW_USB0_RESET_ENABLE 0] $ps
foreach intf {DDR FIXED_IO} {
    make_bd_intf_pins_external [get_bd_intf_pins ps7/$intf]
    set_property name $intf [get_bd_intf_ports ${intf}_0]
}
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk
set_property CONFIG.FREQ_HZ 200000000 [get_bd_intf_ports sys_clk]
create_bd_port -dir I -type rst cpu_reset
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports cpu_reset]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 clkbuf
set_property CONFIG.C_BUF_TYPE IBUFDS [get_bd_cells clkbuf]
connect_bd_intf_net [get_bd_intf_ports sys_clk] [get_bd_intf_pins clkbuf/CLK_IN_D]
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 mig_clock
set_property -dict [list CONFIG.PRIM_IN_FREQ 200 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 166.666667 \
    CONFIG.USE_RESET true CONFIG.RESET_TYPE ACTIVE_HIGH CONFIG.USE_LOCKED true] [get_bd_cells mig_clock]
connect_bd_net [get_bd_pins clkbuf/IBUF_OUT] [get_bd_pins mig_clock/clk_in1]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins mig_clock/reset]
set mig [create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig]
set_property CONFIG.BOARD_MIG_PARAM Custom $mig
set_property CONFIG.RESET_BOARD_INTERFACE Custom $mig
set_property CONFIG.XML_INPUT_FILE $root/constraints/ddr2g_mig.prj $mig
report_property $mig -file $root/reports/mig_properties.rpt
make_bd_intf_pins_external [get_bd_intf_pins mig/DDR3]
set_property name DDR3 [get_bd_intf_ports DDR3_0]
connect_bd_net [get_bd_pins mig_clock/clk_out1] [get_bd_pins mig/sys_clk_i]
if {[llength [get_bd_pins -quiet mig/clk_ref_i]]} {
    connect_bd_net [get_bd_pins clkbuf/IBUF_OUT] [get_bd_pins mig/clk_ref_i]
}
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 inv_reset
set_property -dict [list CONFIG.C_SIZE 1 CONFIG.C_OPERATION not] [get_bd_cells inv_reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins inv_reset/Op1]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 mig_reset_gate
set_property -dict [list CONFIG.C_SIZE 1 CONFIG.C_OPERATION and] [get_bd_cells mig_reset_gate]
connect_bd_net [get_bd_pins inv_reset/Res] [get_bd_pins mig_reset_gate/Op1]
connect_bd_net [get_bd_pins mig_clock/locked] [get_bd_pins mig_reset_gate/Op2]
connect_bd_net [get_bd_pins mig_reset_gate/Res] [get_bd_pins mig/sys_rst]
foreach name {reset_cpu reset_ddr} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 $name
    set_property CONFIG.C_AUX_RESET_HIGH 0 [get_bd_cells $name]
}
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins reset_cpu/slowest_sync_clk] [get_bd_pins ps7/M_AXI_GP0_ACLK]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins reset_cpu/ext_reset_in] [get_bd_pins reset_ddr/aux_reset_in]
connect_bd_net [get_bd_pins mig/mmcm_locked] [get_bd_pins reset_cpu/dcm_locked] [get_bd_pins reset_ddr/dcm_locked]
connect_bd_net [get_bd_pins mig/ui_clk] [get_bd_pins reset_ddr/slowest_sync_clk]
connect_bd_net [get_bd_pins mig/ui_clk_sync_rst] [get_bd_pins reset_ddr/ext_reset_in]
connect_bd_net [get_bd_pins reset_ddr/peripheral_aresetn] [get_bd_pins mig/aresetn]
create_bd_cell -type module -reference ddr_bist bist
create_bd_cell -type module -reference diag_cdc diag
connect_bd_intf_net [get_bd_intf_pins bist/M_AXI] [get_bd_intf_pins mig/S_AXI]
connect_bd_net [get_bd_pins mig/ui_clk] [get_bd_pins bist/aclk]
connect_bd_net [get_bd_pins reset_ddr/peripheral_aresetn] [get_bd_pins bist/aresetn]
connect_bd_net [get_bd_pins mig/init_calib_complete] [get_bd_pins bist/calib_complete]
connect_bd_net [get_bd_pins mig/mmcm_locked] [get_bd_pins bist/mmcm_locked]
connect_bd_net [get_bd_pins mig/ui_clk_sync_rst] [get_bd_pins bist/ui_reset]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins diag/clk]
connect_bd_net [get_bd_pins reset_cpu/peripheral_aresetn] [get_bd_pins diag/resetn]
foreach {source sink} {status status_async first_bad_address address_async first_expected expected_async first_actual actual_async error_words errors_async} {
    connect_bd_net [get_bd_pins bist/$source] [get_bd_pins diag/$sink]
}
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 control_bus
set_property CONFIG.NUM_MI 3 [get_bd_cells control_bus]
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins control_bus/S00_AXI]
foreach pin {ACLK S00_ACLK M00_ACLK M01_ACLK M02_ACLK} {
    connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins control_bus/$pin]
}
foreach pin {ARESETN S00_ARESETN M00_ARESETN M01_ARESETN M02_ARESETN} {
    connect_bd_net [get_bd_pins reset_cpu/interconnect_aresetn] [get_bd_pins control_bus/$pin]
}
set index 0
foreach name {control_gpio error_gpio value_gpio} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 $name
    set_property -dict [list CONFIG.C_IS_DUAL 1 CONFIG.C_GPIO_WIDTH 32 CONFIG.C_GPIO2_WIDTH 32 \
        CONFIG.C_ALL_INPUTS 1 CONFIG.C_ALL_INPUTS_2 1] [get_bd_cells $name]
    connect_bd_intf_net [get_bd_intf_pins control_bus/M0${index}_AXI] [get_bd_intf_pins $name/S_AXI]
    connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins $name/s_axi_aclk]
    connect_bd_net [get_bd_pins reset_cpu/peripheral_aresetn] [get_bd_pins $name/s_axi_aresetn]
    incr index
}
set_property -dict [list CONFIG.C_ALL_INPUTS 0 CONFIG.C_ALL_OUTPUTS 1] [get_bd_cells control_gpio]
connect_bd_net [get_bd_pins control_gpio/gpio_io_o] [get_bd_pins bist/command]
connect_bd_net [get_bd_pins diag/status] [get_bd_pins control_gpio/gpio2_io_i]
connect_bd_net [get_bd_pins diag/address] [get_bd_pins error_gpio/gpio_io_i]
connect_bd_net [get_bd_pins diag/errors] [get_bd_pins error_gpio/gpio2_io_i]
connect_bd_net [get_bd_pins diag/expected] [get_bd_pins value_gpio/gpio_io_i]
connect_bd_net [get_bd_pins diag/actual] [get_bd_pins value_gpio/gpio2_io_i]
foreach {name offset} {control_gpio 0x41200000 error_gpio 0x41210000 value_gpio 0x41220000} {
    assign_bd_address -offset $offset -range 0x10000 -target_address_space [get_bd_addr_spaces ps7/Data] [get_bd_addr_segs $name/S_AXI/Reg] -force
}
puts "BIST address spaces: [get_bd_addr_spaces bist/*]"
puts "MIG address segments: [get_bd_addr_segs -of_objects [get_bd_intf_pins mig/S_AXI]]"
assign_bd_address -offset 0 -range 0x80000000 -target_address_space [get_bd_addr_spaces bist/M_AXI] [get_bd_addr_segs -of_objects [get_bd_intf_pins mig/S_AXI]] -force
validate_bd_design
save_bd_design
set bd [get_files */ddr_test.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
add_files -fileset constrs_1 $root/constraints/board.xdc
set_property top ddr_test_wrapper [current_fileset]
set_property STEPS.SYNTH_DESIGN.TCL.POST $root/scripts/mig_delay_groups.tcl [get_runs synth_1]
update_compile_order -fileset sources_1
write_bd_tcl -force $root/reports/ddr_test_bd.tcl
report_ip_status -file $root/reports/ip_status.rpt
close_project
puts DDR2G_PROJECT_PREPARED
exit
