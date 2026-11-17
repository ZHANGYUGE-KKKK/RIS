set root [file normalize [file join [file dirname [info script]] ..]]
set workspace $root/vitis_rx_uplink
set platform_name rx_uplink_platform
set hardware $root/reports/uplink/rx_uplink_hw.xsa
if {![file exists $hardware]} {error "Build the SGMII hardware platform first: $hardware"}
setws $workspace
if {[file exists $workspace/$platform_name/platform.spr]} {
    platform read $workspace/$platform_name/platform.spr
    platform active $platform_name
    platform config -updatehw $hardware
} else {
    platform create -name $platform_name -hw $hardware -proc ps7_cortexa9_0 -os standalone
}
platform active $platform_name
if {[catch {domain active standalone_domain}]} {
    domain create -name standalone_domain -os standalone -proc ps7_cortexa9_0
    domain active standalone_domain
}
bsp config stdin ps7_uart_1
bsp config stdout ps7_uart_1
bsp setlib -name lwip211 -ver 1.8
# Two GEMs each preallocate 64 RX pbufs; reserve 128 more for live traffic.
foreach {key value} {
    api_mode RAW_API lwip_dhcp false phy_link_speed CONFIG_LINKSPEED_AUTODETECT
    no_sys_no_timers true mem_size 1048576 memp_n_tcp_seg 1024
    tcp_snd_buf 65535 tcp_wnd 32768 pbuf_pool_size 512
    use_axieth_on_zynq 0 use_emaclite_on_zynq 0
} {bsp config $key $value}
platform write
platform generate
set bsp_root $workspace/$platform_name/ps7_cortexa9_0/standalone_domain/bsp
set domain_export $workspace/$platform_name/export/$platform_name/sw/$platform_name/standalone_domain
puts [exec python3 $root/scripts/patch_uplink_bsp.py --bsp $bsp_root --export $domain_export --rebuild 2>@1]
puts RX_UPLINK_BSP_OK
exit
