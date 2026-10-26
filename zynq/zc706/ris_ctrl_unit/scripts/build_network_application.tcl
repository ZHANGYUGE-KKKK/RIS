# Separate workspace and ELF; retains the accepted UART application/package.
set root [file normalize [file join [file dirname [info script]] ..]]
set workspace $root/vitis_network
set platform_name ris_network_platform
set app_name ris_network
set hardware $root/export/ris_ctrl_unit.xsa
set artifacts $root/export_network
set fast 0
foreach {key variable} {RIS_NETWORK_WORKSPACE workspace RIS_NETWORK_PLATFORM platform_name RIS_NETWORK_APP app_name RIS_XSA hardware RIS_EXPORT_DIR artifacts RIS_FAST_TOGGLE fast} {
    if {[info exists ::env($key)]} {set $variable $::env($key)}
}
setws $workspace
if {[file exists $workspace/$platform_name/platform.spr]} {
    platform read $workspace/$platform_name/platform.spr
    platform active $platform_name
    if {$fast} {platform config -updatehw $hardware}
} else {
    platform create -name $platform_name -hw $hardware -proc ps7_cortexa9_0 -os standalone
}
platform active $platform_name
domain active standalone_domain
bsp config stdin ps7_uart_1
bsp config stdout ps7_uart_1
if {$fast} {bsp setlib -name lwip211 -ver 1.3} else {bsp setlib -name lwip211 -ver 1.2}
foreach {key value} {
    api_mode RAW_API lwip_dhcp false phy_link_speed CONFIG_LINKSPEED_AUTODETECT
    no_sys_no_timers true mem_size 131072 memp_n_tcp_seg 256
    tcp_snd_buf 8192 tcp_wnd 8192 pbuf_pool_size 64
    use_axieth_on_zynq 0 use_emaclite_on_zynq 0
} {bsp config $key $value}
platform write
platform generate
if {![file exists $workspace/$app_name/.project]} {
    app create -name ${app_name} -platform $platform_name -domain standalone_domain -template {Empty Application}
}
if {![file exists $workspace/$app_name/src]} {error "Application creation failed; inspect $workspace/IDE.log"}
foreach f [concat [glob $root/software/*.c] [glob $root/software/*.h] [glob $root/software/network/*.c] [glob $root/software/network/*.h]] {
    file copy -force $f $workspace/$app_name/src/
}
app config -name ${app_name} build-config Debug
set flags [app config -name ${app_name} compiler-misc]
if {![string match {*-DRIS_ENABLE_NETWORK*} $flags]} {
    app config -name ${app_name} -add compiler-misc {-std=gnu99 -Wall -Wextra -DRIS_ENABLE_NETWORK}
}
if {$fast && ![string match {*-DRIS_FAST_TOGGLE*} [app config -name ${app_name} compiler-misc]]} {
    app config -name ${app_name} -add compiler-misc {-DRIS_FAST_TOGGLE}
}
if {[lsearch -exact [app config -name ${app_name} libraries] lwip4]<0} {
    app config -name ${app_name} -add libraries lwip4
}
app build -name ${app_name}
file mkdir $artifacts
foreach name {ris_ctrl_unit.bit ris_ctrl_unit.xsa ps7_init.tcl} {
    if {!$fast} {file copy -force $root/export/$name $artifacts/$name}
}
file copy -force $workspace/$app_name/Debug/${app_name}.elf $artifacts/ris_all_io.elf
puts [exec python3 $root/scripts/finalize_export.py $artifacts]
if {$fast} {
    file mkdir $workspace/$app_name/_ide/bitstream $workspace/$app_name/_ide/psinit
    file copy -force $artifacts/ris_ctrl_unit.bit $workspace/$app_name/_ide/bitstream/ris_ctrl_unit.bit
    file copy -force $artifacts/ps7_init.tcl $workspace/$app_name/_ide/psinit/ps7_init.tcl
}
puts RIS_NETWORK_APPLICATION_BUILD_PASS
exit
