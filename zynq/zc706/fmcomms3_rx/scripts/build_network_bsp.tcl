# Independent HSI generation: works while Eclipse owns the Vitis workspace.
set root [file normalize [file join [file dirname [info script]] ..]]
set target $root/vitis_code/network_bsp
set hardware $root/export/zc706_top.xsa
if {[llength $argv] >= 1} {set target [file normalize [lindex $argv 0]]}
if {[llength $argv] >= 2} {set hardware [file normalize [lindex $argv 1]]}
hsi::open_hw_design $hardware
hsi::create_sw_design network_bsp -proc ps7_cortexa9_0 -os standalone -os_ver 7.3
hsi::set_property CONFIG.stdin ps7_uart_1 [hsi::get_os]
hsi::set_property CONFIG.stdout ps7_uart_1 [hsi::get_os]
set lib [hsi::add_library lwip211 1.2]
foreach {key value} {
    api_mode RAW_API lwip_dhcp false phy_link_speed CONFIG_LINKSPEED_AUTODETECT
    no_sys_no_timers true mem_size 1048576 memp_n_tcp_seg 1024
    tcp_snd_buf 65535 tcp_wnd 32768 pbuf_pool_size 512
    use_axieth_on_zynq 0 use_emaclite_on_zynq 0
} {
    hsi::set_property CONFIG.$key $value $lib
}
hsi::generate_bsp -dir $target -compile
puts "NETWORK_BSP_READY $target"
exit
