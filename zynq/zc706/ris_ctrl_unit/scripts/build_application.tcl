# XSCT 2020.2: xsct scripts/build_application.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set xsa $root/export/ris_ctrl_unit.xsa
if {[info exists ::env(RIS_XSA)]} {set xsa [file normalize $::env(RIS_XSA)]}
if {![file exists $xsa]} {error "Build the board hardware first"}
setws $root/vitis_code
if {[file exists $root/vitis_code/ris_platform/platform.spr]} {
    platform read $root/vitis_code/ris_platform/platform.spr
    platform active ris_platform
    platform config -updatehw $xsa
} else {
    platform create -name ris_platform -hw $xsa -proc ps7_cortexa9_0 -os standalone
}
platform active ris_platform
domain active standalone_domain
bsp config stdin ps7_uart_1
bsp config stdout ps7_uart_1
platform write
platform generate
if {![file exists $root/vitis_code/ris_all_io/.project]} {
    app create -name ris_all_io -platform ris_platform -domain standalone_domain -template {Empty Application}
}
foreach f [glob $root/software/*.c $root/software/*.h] {
    file copy -force $f $root/vitis_code/ris_all_io/src/
}
app config -name ris_all_io build-config Debug
set flags [app config -name ris_all_io compiler-misc]
if {![string match {*-std=gnu99*} $flags]} {
    app config -name ris_all_io -add compiler-misc {-std=gnu99 -Wall -Wextra}
}
app build -name ris_all_io
file copy -force $root/vitis_code/ris_all_io/Debug/ris_all_io.elf $root/export/ris_all_io.elf
if {[file exists $root/export/ris_ctrl_unit.bit]} {
    puts [exec python3 $root/scripts/finalize_export.py $root]
}
puts RIS_APPLICATION_BUILD_PASS
exit
