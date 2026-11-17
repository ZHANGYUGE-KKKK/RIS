# Independent sender firmware build; never downloads or programs hardware.
set root [file normalize [file join [file dirname [info script]] ..]]
set workspace $root/vitis_uplink
set platform_name ris_uplink_platform
set app_name ris_uplink_network
set artifacts $root/export_uplink
set hardware $artifacts/ris_ctrl_unit.xsa
foreach {key variable} {RIS_UPLINK_WORKSPACE workspace RIS_UPLINK_EXPORT artifacts RIS_UPLINK_XSA hardware} {
    if {[info exists ::env($key)]} {set $variable [file normalize $::env($key)]}
}
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
    no_sys_no_timers true mem_size 262144 memp_n_tcp_seg 256
    tcp_snd_buf 8192 tcp_wnd 8192 pbuf_pool_size 256
    use_axieth_on_zynq 0 use_emaclite_on_zynq 0
} {bsp config $key $value}
platform write
platform generate
if {[info exists ::env(RIS_UPLINK_PLATFORM_ONLY)] && $::env(RIS_UPLINK_PLATFORM_ONLY)} {
    puts RIS_UPLINK_PLATFORM_BUILD_PASS
    exit
}

# The installed Xilinx library remains untouched. Apply the documented dual-GEM
# fixes only to this generated platform and rebuild its exported libraries.
set bsp_root $workspace/$platform_name/ps7_cortexa9_0/standalone_domain/bsp
set domain_export $workspace/$platform_name/export/$platform_name/sw/$platform_name/standalone_domain
puts [exec python3 $root/scripts/patch_uplink_bsp.py --bsp $bsp_root --export $domain_export --rebuild 2>@1]

if {![file exists $workspace/$app_name/.project]} {
    app create -name $app_name -platform $platform_name -domain standalone_domain -template {Empty Application}
}
if {![file exists $workspace/$app_name/src]} {error "Application creation failed"}
foreach f [concat [glob $root/software/*.c] [glob $root/software/*.h] [glob $root/software/*.inc] [glob $root/software/network/*.c] [glob $root/software/network/*.h]] {
    file copy -force $f $workspace/$app_name/src/
}
app config -name $app_name build-config Debug
set lwip_include $domain_export/bspinclude/include/lwip
set lwip_quote [format {-iquote"%s"} $lwip_include]
if {[file exists $lwip_include/debug.h] && [string first $lwip_quote [app config -name $app_name compiler-misc]]<0} {
    app config -name $app_name -add compiler-misc $lwip_quote
}
foreach flag {-std=gnu99 -Wall -Wextra -DRIS_ENABLE_NETWORK -DRIS_FAST_TOGGLE -DRIS_MT_TABLE -DRIS_QAM_TABLE} {
    if {[string first $flag [app config -name $app_name compiler-misc]]<0} {
        app config -name $app_name -add compiler-misc $flag
    }
}
if {[lsearch -exact [app config -name $app_name libraries] lwip4]<0} {
    app config -name $app_name -add libraries lwip4
}
set elf $workspace/$app_name/Debug/${app_name}.elf
file delete -force $elf
app build -name $app_name
if {![file exists $elf]} {error "Firmware build failed; no new ELF was produced"}
file mkdir $artifacts
file copy -force $elf $artifacts/ris_uplink_network.elf
if {[file exists $workspace/$platform_name/hw/ps7_init.tcl]} {
    file copy -force $workspace/$platform_name/hw/ps7_init.tcl $artifacts/ps7_init.tcl
}
puts RIS_UPLINK_FIRMWARE_BUILD_PASS
exit
