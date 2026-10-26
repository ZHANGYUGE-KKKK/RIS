# Volatile JTAG programming and bounded receive test. PuTTY owns the UART.
# Usage: xsct scripts/run_ad9361_rx_board.tcl /absolute/report/directory
set board_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv] != 1} {error "Expected report directory"}
set report [file normalize [lindex $argv 0]]
set platform $board_root/vitis_code/key_ctrl/export/key_ctrl
set elf $board_root/vitis_code/key_ctrlll/Debug/key_ctrlll.elf
set toolchain /home/yyz/vivado2020.2/main/Vitis/2020.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin
set symbols [exec $toolchain/arm-none-eabi-nm -S $elf]
set reports [dict create]
foreach name {official_rx_report rx_baseline_report rx_pn_stability_report rx_restored_report rf_clock_test_report} {
    if {![regexp -line [format {^([0-9a-fA-F]+) +([0-9a-fA-F]+) +[a-zA-Z] +%s$} $name] $symbols -> address size]} {
        error "Missing report symbol $name"
    }
    dict set reports $name [list [expr 0x$address] [expr (0x$size+3)/4]]
}
set fd [open $report/report_symbols.tcl w]
puts $fd [list set reports $reports]
close $fd
connect -url tcp:127.0.0.1:3121
after 2000
puts "TARGETS=[targets]"
jtag targets -set -filter {name == "Digilent JTAG-HS1 210512180081"}
jtag frequency 15000000
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 2000
targets -set -filter {name =~ "xc7z035*"}
fpga -file $board_root/PZ_UART.runs/impl_1/pz7035_top.bit
targets -set -nocase -filter {name =~ "APU*"}
loadhw -hw $platform/hw/pz7035_top.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
source $platform/hw/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
dow $elf
configparams force-mem-access 0
set fd [open $report/uart_offset.txt w]
puts $fd [file size $board_root/reports/fmcomms3/vitis_uart.log]
close $fd
con
puts "RX_BOARD_STARTED [clock format [clock seconds]]"
set restored_address [lindex [dict get $reports rx_restored_report] 0]
set deadline [expr {[clock milliseconds]+180000}]
set completed 0
while {[clock milliseconds] < $deadline} {
    after 1000
    if {[mrd -value [expr {$restored_address+4}]] == 1} {set completed 1; break}
}
# The final PLL check takes another two seconds after the restored-RF monitor.
if {$completed} {after 3000}
dict for {name location} $reports {
    lassign $location address words
    mrd -bin -file $report/${name}.bin $address $words
    puts "REPORT $name ADDRESS=[format 0x%08x $address] WORDS=$words HEADER=[mrd -value $address 8]"
}
puts "RX_GPIO_ARM=[mrd -value 0x80020000] RX_GPIO_FLAGS=[mrd -value 0x80020008]"
puts "RX_DIAGNOSTIC_REGISTERS=[mrd -value 0x82001000 12]"
puts "CPU_STATE=[targets]"
disconnect
if {!$completed} {error "RX board diagnostic did not complete within 180 seconds; inspect reports/UART before resetting BIST"}
puts AD9361_RX_BOARD_DIAGNOSTIC_COMPLETE
exit
