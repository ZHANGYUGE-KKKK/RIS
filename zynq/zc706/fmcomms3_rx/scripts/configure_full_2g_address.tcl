# A 1GiB GP0 slave window feeds a separate 2GiB AXI master address space.
# Only CPU transactions are banked. SG/S2MM remain continuous DMA bus addresses.
set window_source $root/PZ_UART.srcs/sources_1/new/mig_cpu_window.v
if {![llength [get_files -quiet $window_source]]} {add_files -norecurse $window_source}
if {![llength [get_bd_cells -quiet ddr_cpu_window]]} {
    create_bd_cell -type module -reference mig_cpu_window ddr_cpu_window
}
if {![llength [get_bd_cells -quiet axi_gpio_ddr_bank]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_ddr_bank
}
set_property -dict [list CONFIG.C_GPIO_WIDTH 1 CONFIG.C_ALL_OUTPUTS 1 \
    CONFIG.C_DOUT_DEFAULT 0x00000000 CONFIG.C_IS_DUAL 0] [get_bd_cells axi_gpio_ddr_bank]
set_property CONFIG.NUM_MI 5 [get_bd_cells axi_interconnect_1]

set old_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins processing_system7_0/M_AXI_GP0]]
if {[llength $old_net] && ![llength [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins ddr_cpu_window/S_AXI]]]} {
    delete_bd_objs $old_net
}
if {![llength [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins ddr_cpu_window/S_AXI]]]} {
    connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins ddr_cpu_window/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins ddr_cpu_window/M_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
}
if {![llength [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins axi_gpio_ddr_bank/S_AXI]]]} {
    connect_bd_intf_net [get_bd_intf_pins axi_interconnect_1/M04_AXI] [get_bd_intf_pins axi_gpio_ddr_bank/S_AXI]
}
ddr2g_join [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins ddr_cpu_window/aclk] [get_bd_pins axi_gpio_ddr_bank/s_axi_aclk] [get_bd_pins axi_interconnect_1/M04_ACLK]
ddr2g_join [get_bd_pins rst_ps_fclk0/peripheral_aresetn] \
    [get_bd_pins ddr_cpu_window/aresetn] [get_bd_pins axi_gpio_ddr_bank/s_axi_aresetn] [get_bd_pins axi_interconnect_1/M04_ARESETN]
ddr2g_join [get_bd_pins axi_gpio_ddr_bank/gpio_io_o] [get_bd_pins ddr_cpu_window/bank_select]

# Remove only the former MIG master segments before assigning the full range.
foreach master {processing_system7_0/Data axi_dma_0/Data_SG axi_dma_0/Data_S2MM ddr_cpu_window/M_AXI} {
    foreach segment [get_bd_addr_segs -quiet -of_objects [get_bd_addr_spaces $master]] {
        if {[string match *mig_7series_0_memaddr $segment]} {delete_bd_objs $segment}
    }
}
puts "CPU_WINDOW_SEGS [get_bd_addr_segs -of_objects [get_bd_intf_pins ddr_cpu_window/S_AXI]]"
foreach master {axi_dma_0/Data_SG axi_dma_0/Data_S2MM ddr_cpu_window/M_AXI} {
    assign_bd_address -offset 0x00000000 -range 0x80000000 \
        -target_address_space [get_bd_addr_spaces $master] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
}
assign_bd_address -offset 0x40000000 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs ddr_cpu_window/S_AXI/reg0] -force
assign_bd_address -offset 0x83000000 -range 0x10000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_gpio_ddr_bank/S_AXI/Reg] -force
puts "FULL_DDR: DMA 0..7fffffff; CPU 40000000..7fffffff banked by GPIO83000000"
