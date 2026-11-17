set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299995170"}
set fpga {name == "xc7z045" && jtag_cable_serial == "210299995170"}
connect -url tcp:127.0.0.1:3121
for {set attempt 0} {$attempt < 15} {incr attempt} {
    if {[llength [targets -target-properties -filter $cpu]] == 1} {break}
    after 300
}
foreach filter [list $cpu $fpga] {
    if {[llength [targets -target-properties -filter $filter]] != 1} {error "Receiver JTAG target unavailable"}
}
targets -set -filter $cpu
set mode [mrd -value 0xf800025c]
puts "RX_COLD_BOOT_MODE $mode"
if {([expr {$mode}] & 15) != 1} {error "Receiver is not booting from QSPI"}
puts "RX_CPU_STATE [state]"
puts RX_QSPI_BOOTMODE_PASS
disconnect
exit
