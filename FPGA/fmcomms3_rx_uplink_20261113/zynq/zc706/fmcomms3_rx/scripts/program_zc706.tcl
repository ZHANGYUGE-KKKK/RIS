# Prepared for manual use; migration/build never invokes this script.
# xsct scripts/program_zc706.tcl        -> download and leave CPU halted
# xsct scripts/program_zc706.tcl run    -> download and run the original app
set root [file normalize [file join [file dirname [info script]] ..]]
set platform $root/vitis_code/key_ctrl/export/key_ctrl
set elf $root/vitis_code/key_ctrlll/Debug/key_ctrlll.elf
foreach file [list $root/export/zc706_top.bit $platform/hw/zc706_top.xsa $platform/hw/ps7_init.tcl $elf] {
    if {![file exists $file]} {error "Missing prepared artifact: $file"}
}
connect -url tcp:127.0.0.1:3121
after 1500
if {[llength [targets -target-properties -filter {name =~ "xc7z045*"}]] != 1} {
    error "Expected exactly one XC7Z045 target; select the ZC706 cable explicitly if multiple boards are attached"
}
targets -set -filter {name == "APU"}
rst -system
after 1000
targets -set -filter {name =~ "xc7z045*"}
fpga -file $root/export/zc706_top.bit
targets -set -filter {name == "APU"}
loadhw -hw $platform/hw/zc706_top.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
source $platform/hw/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
dow $elf
configparams force-mem-access 0
if {[lindex $argv 0] eq "run"} {
    con
    puts "ZC706 application running; UART1 115200 8N1"
} else {
    puts "ZC706 application downloaded and halted at ELF entry; ready for manual debug"
}
disconnect
exit
