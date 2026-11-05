# XSCT: volatile JTAG program/download; no flash write.
set board_dir [file normalize [file join [file dirname [info script]] ../..]]
connect -url tcp:127.0.0.1:3121
after 3000
puts "JTAG=[jtag targets]"
after 1000
puts "AVAILABLE_TARGETS=[targets]"
if {[llength [targets -target-properties -filter {name == "ARM Cortex-A9 MPCore #0"}]] != 1} {error "Expected one Cortex-A9 core 0"}
targets -set -filter {name == "ARM Cortex-A9 MPCore #0"}
catch {stop}
rst -system
after 1000
targets -set -filter {name =~ "xc7z035*"}
fpga -file $board_dir/PZ_UART.runs/impl_1/pz7035_top.bit
targets -set -filter {name =~ "ARM*#0"}
source $board_dir/vitis_code/key_ctrlll/_ide/psinit/ps7_init.tcl
ps7_init
ps7_post_config
dow $board_dir/vitis_code/key_ctrlll/Debug/key_ctrlll.elf
con
puts "FMCOMMS3_PROGRAM_RUNNING [clock format [clock seconds]]"
after 20000
set fm_symbols [exec arm-none-eabi-nm -n $board_dir/vitis_code/key_ctrlll/Debug/key_ctrlll.elf]
foreach {fm_name fm_words} {ad_config_report 34 rf_clock_test_report 9 mig_test_report 9} {
    if {![regexp -line [format {^([0-9a-fA-F]+) +[a-zA-Z] +%s$} $fm_name] $fm_symbols fm_match fm_address]} {error "Missing report symbol $fm_name"}
    puts "REPORT $fm_name ADDRESS=0x$fm_address"
    puts [mrd 0x$fm_address $fm_words]
}
puts "CPU_STATE=[targets]"
disconnect
exit
