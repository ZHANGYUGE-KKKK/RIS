# Build the replacement platform in an isolated workspace while the old GUI
# workspace remains open. Publish only after final hardware checks pass.
set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv]} {
    set report [file normalize [lindex $argv 0]]
} else {
    set f [open $root/reports/mig2g_active.txt];set report [string trim [read $f]];close $f
}
file mkdir $report/platform_hw
file copy -force $report/bsp_preview.xsa $report/platform_hw/zc706_top.xsa
setws $report/vitis_stage
if {[file exists $report/vitis_stage/key_ctrl/platform.spr]} {
    platform read $report/vitis_stage/key_ctrl/platform.spr
    platform active key_ctrl
    platform config -updatehw $report/platform_hw/zc706_top.xsa
} else {
    platform create -name key_ctrl -hw $report/platform_hw/zc706_top.xsa -proc ps7_cortexa9_0 -os standalone -out $report/vitis_stage
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
platform write
platform generate
puts RX_DDR2G_VITIS_STAGE_READY
exit
