# xsct scripts/program_board.tcl
# Volatile JTAG download only. Leaves the all-LOW application running.
set root [file normalize [file join [file dirname [info script]] ..]]
set artifacts $root/export
if {[info exists ::env(RIS_EXPORT_DIR)]} {set artifacts [file normalize $::env(RIS_EXPORT_DIR)]}
set serial 210299995170
if {[info exists ::env(RIS_JTAG_SERIAL)]} {set serial $::env(RIS_JTAG_SERIAL)}
set url tcp:127.0.0.1:3121
if {[info exists ::env(RIS_HW_SERVER)]} {set url $::env(RIS_HW_SERVER)}
foreach f [list $artifacts/ris_ctrl_unit.bit $artifacts/ris_ctrl_unit.xsa \
               $artifacts/ris_all_io.elf $artifacts/ps7_init.tcl] {
    if {![file exists $f]} {error "Missing artifact: $f"}
}
connect -url $url
set apu_filter [format {name == "APU" && jtag_cable_serial == "%s"} $serial]
set fpga_filter [format {name =~ "xc7z045*" && jtag_cable_serial == "%s"} $serial]
set cpu_filter [format {name =~ "*A9*#0" && jtag_cable_serial == "%s"} $serial]
if {[llength [targets -target-properties -filter $fpga_filter]] != 1} {
    error "Expected the confirmed RIS ZC706 cable $serial"
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
puts "RIS application started on $serial; UART1 115200 8N1; initial pattern all LOW"
disconnect
exit
