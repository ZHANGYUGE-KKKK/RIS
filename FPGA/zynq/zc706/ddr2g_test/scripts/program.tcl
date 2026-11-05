# Manual use after installing the 2GB DIMM and powering the ZC706 on.
# xsct scripts/program.tcl run  (omit run to leave CPU halted)
set root [file normalize [file join [file dirname [info script]] ..]]
foreach f {ddr2g_test.bit ddr2g_test.xsa ddr2g_test.elf ps7_init.tcl} {
    if {![file exists $root/export/$f]} {error "Missing artifact $f"}
}
connect -url tcp:127.0.0.1:3121
after 1000
if {[llength [targets -target-properties -filter {name =~ "xc7z045*"}]]!=1} {
    error "Expected exactly one XC7Z045. Select/disconnect cables if both boards are attached."
}
targets -set -filter {name == "APU"}
rst -system
after 1000
targets -set -filter {name =~ "xc7z045*"}
fpga -file $root/export/ddr2g_test.bit
targets -set -filter {name == "APU"}
loadhw -hw $root/export/ddr2g_test.xsa -regs
configparams force-mem-access 1
source $root/export/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
dow $root/export/ddr2g_test.elf
configparams force-mem-access 0
if {[lindex $argv 0] eq "run"} {
    con
    puts "DDR2G test ready: UART 115200 8N1, commands s / 0 / 1 / f / a"
} else {puts "DDR2G ELF downloaded; CPU halted at entry"}
disconnect
exit
