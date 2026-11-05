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
if {[catch {domain active standalone_domain}]} {
    # Resume a partially created platform (for example after an interrupted
    # SDK launch), and keep the application domain name stable across Vitis.
    domain create -name standalone_domain -os standalone -proc ps7_cortexa9_0
    domain active standalone_domain
}
bsp config stdin ps7_uart_1
bsp config stdout ps7_uart_1
set lwip_version [expr {$fast ? "1.3" : "1.2"}]
if {[info exists ::env(RIS_LWIP_VERSION)]} {set lwip_version $::env(RIS_LWIP_VERSION)}
bsp setlib -name lwip211 -ver $lwip_version
foreach {key value} {
    api_mode RAW_API lwip_dhcp false phy_link_speed CONFIG_LINKSPEED_AUTODETECT
    no_sys_no_timers true mem_size 131072 memp_n_tcp_seg 256
    tcp_snd_buf 8192 tcp_wnd 8192 pbuf_pool_size 64
    use_axieth_on_zynq 0 use_emaclite_on_zynq 0
} {bsp config $key $value}
platform write
platform generate
file mkdir $artifacts
if {$fast && [file exists $workspace/$platform_name/hw/ps7_init.tcl]} {
    file copy -force $workspace/$platform_name/hw/ps7_init.tcl $artifacts/ps7_init.tcl
}
if {![file exists $workspace/$app_name/.project]} {
    app create -name ${app_name} -platform $platform_name -domain standalone_domain -template {Empty Application}
}
if {![file exists $workspace/$app_name/src]} {error "Application creation failed; inspect $workspace/IDE.log"}
foreach f [concat [glob $root/software/*.c] [glob $root/software/*.h] [glob $root/software/network/*.c] [glob $root/software/network/*.h]] {
    file copy -force $f $workspace/$app_name/src/
}
app config -name ${app_name} build-config Debug
# lwIP 2.1.1 v1.8's exported netif/xpqueue.h includes "debug.h" directly.
# Search quoted headers only: -I would shadow libc <errno.h> with lwIP's.
# Do not patch the installed vendor library.
set lwip_include $workspace/$platform_name/export/$platform_name/sw/$platform_name/standalone_domain/bspinclude/include/lwip
if {[lsearch -exact [app config -name ${app_name} include-path] $lwip_include]>=0} {
    app config -name ${app_name} -remove include-path $lwip_include
}
set lwip_quote [format {-iquote"%s"} $lwip_include]
if {[file exists $lwip_include/debug.h] && [string first $lwip_quote [app config -name ${app_name} compiler-misc]]<0} {
    app config -name ${app_name} -add compiler-misc $lwip_quote
}
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
if {[info exists ::env(RIS_MT_TABLE)] && $::env(RIS_MT_TABLE)} {
    if {![string match {*-DRIS_MT_TABLE*} [app config -name ${app_name} compiler-misc]]} {
        app config -name ${app_name} -add compiler-misc {-DRIS_MT_TABLE}
    }
}
# Some Vitis releases return normally even when make fails. A stale ELF must
# never be exported as the result of a failed rebuild.
set app_elf $workspace/$app_name/Debug/${app_name}.elf
file delete -force $app_elf
app build -name ${app_name}
if {![file exists $app_elf]} {error "Firmware build failed; no new ELF was produced"}
file mkdir $artifacts
foreach name {ris_ctrl_unit.bit ris_ctrl_unit.xsa ps7_init.tcl} {
    if {!$fast} {file copy -force $root/export/$name $artifacts/$name}
}
file copy -force $app_elf $artifacts/ris_all_io.elf
puts [exec python3 $root/scripts/finalize_export.py $artifacts]
if {$fast} {
    file mkdir $workspace/$app_name/_ide/bitstream $workspace/$app_name/_ide/psinit
    file copy -force $artifacts/ris_ctrl_unit.bit $workspace/$app_name/_ide/bitstream/ris_ctrl_unit.bit
    file copy -force $artifacts/ps7_init.tcl $workspace/$app_name/_ide/psinit/ps7_init.tcl
}
puts RIS_NETWORK_APPLICATION_BUILD_PASS
exit
