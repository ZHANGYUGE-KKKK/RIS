set root [file normalize [file join [file dirname [info script]] ..]]
setws $root/vitis_code
if {[file exists $root/vitis_code/key_ctrl/platform.spr]} {
    platform read $root/vitis_code/key_ctrl/platform.spr
    platform active key_ctrl
    platform config -updatehw $root/export/zc706_top.xsa
} else {
    platform create -name key_ctrl -hw $root/export/zc706_top.xsa -proc ps7_cortexa9_0 -os standalone
}
platform active key_ctrl
domain active standalone_domain
bsp config stdin ps7_uart_1
bsp config stdout ps7_uart_1
bsp setlib -name lwip211 -ver 1.2
foreach {key value} {
    api_mode RAW_API lwip_dhcp false phy_link_speed CONFIG_LINKSPEED_AUTODETECT
    no_sys_no_timers true mem_size 1048576 memp_n_tcp_seg 1024
    tcp_snd_buf 65535 tcp_wnd 32768 pbuf_pool_size 512
    use_axieth_on_zynq 0 use_emaclite_on_zynq 0
} {
    bsp config $key $value
}
platform generate
puts ZC706_VITIS_PLATFORM_PASS
exit
