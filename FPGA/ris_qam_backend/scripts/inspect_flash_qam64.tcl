# Read-only JTAG identity and boot-mode check; never stops or writes targets.
connect -url tcp:127.0.0.1:3121
after 1000
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299372306"}
set fpga {name == "xc7z045" && jtag_cable_serial == "210299372306"}
if {[llength [targets -target-properties -filter $cpu]]!=1 || [llength [targets -target-properties -filter $fpga]]!=1} {
    puts [targets]
    error "Expected confirmed XC7Z045 board on cable 210299372306"
}
puts "RIS_CONFIRMED_CABLE 210299372306"
puts "RIS_CONFIRMED_FPGA xc7z045"
targets -set -filter $cpu
puts "RIS_BOOT_MODE [mrd -value 0xf800025c]"
puts "RIS_PREFLIGHT_READ_ONLY_PASS"
disconnect
exit
