# Manual XSCT entry: volatile download, resets the selected board. No QSPI write.
# This file is never called by the build scripts or GUI.
set root [file normalize [file join [file dirname [info script]] ..]]
set artifacts $root/export_qam
puts [exec python3 $root/scripts/verify_package.py]
set serial 210299372306
if {[info exists ::env(RIS_JTAG_SERIAL)]} {set serial $::env(RIS_JTAG_SERIAL)}
set url tcp:127.0.0.1:3121
if {[info exists ::env(RIS_HW_SERVER)]} {set url $::env(RIS_HW_SERVER)}
connect -url $url
set apu_filter [format {name == "APU" && jtag_cable_serial == "%s"} $serial]
set fpga_filter [format {name =~ "xc7z045*" && jtag_cable_serial == "%s"} $serial]
set cpu_filter [format {name =~ "*A9*#0" && jtag_cable_serial == "%s"} $serial]
foreach filter [list $apu_filter $fpga_filter $cpu_filter] {
    if {[llength [targets -target-properties -filter $filter]] != 1} {
        error "Expected one RIS ZC706 target for cable $serial: $filter"
    }
}
targets -set -filter $apu_filter
rst -system
after 1000
targets -set -filter $fpga_filter
fpga -file $artifacts/ris_ctrl_unit.bit
targets -set -filter $apu_filter
loadhw -hw $artifacts/ris_ctrl_unit.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
source $artifacts/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -filter $cpu_filter
dow $artifacts/ris_all_io.elf
configparams force-mem-access 0
con
puts "RIS QAM1 network firmware started on $serial; TCP 192.168.1.11:7060; initial all LOW"
disconnect
exit
