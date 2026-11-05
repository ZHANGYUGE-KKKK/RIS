set root [file normalize [file join [file dirname [info script]] ..]]
set hardware $root/export/ddr2g_test.xsa
if {![file exists $hardware]} {set hardware $root/reports/ddr2g_bsp.xsa}
hsi::open_hw_design $hardware
hsi::create_sw_design ddr2g_bsp -proc ps7_cortexa9_0 -os standalone -os_ver 7.3
hsi::set_property CONFIG.stdin ps7_uart_1 [hsi::get_os]
hsi::set_property CONFIG.stdout ps7_uart_1 [hsi::get_os]
hsi::generate_bsp -dir $root/vitis/bsp -compile
puts DDR2G_BSP_READY
exit
