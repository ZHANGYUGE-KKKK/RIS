set root /home/wenhan/PROJECTS/RIS/FPGA/ris_qam_backend
set package $root/export_flash/20261113_uplink
set symbols [exec readelf -sW $package/ris_all_io.elf]
if {![regexp -line {^\s+[0-9]+:\s+([0-9a-fA-F]+)\s+[0-9]+\s+OBJECT\s+GLOBAL\s+DEFAULT\s+[0-9]+\s+ris_mailbox\s*$} $symbols unused mailbox_hex]} {
    error "No matching mailbox symbol"
}
scan $mailbox_hex %x mailbox_address
connect -url tcp:127.0.0.1:3121
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299372306"}
for {set attempt 0} {$attempt < 10} {incr attempt} {
    if {[llength [targets -target-properties -filter $cpu]] == 1} { break }
    after 300
}
if {[llength [targets -target-properties -filter $cpu]] != 1} {error "Expected confirmed RIS board"}
targets -set -filter $cpu
set mode [mrd -value 0xf800025c]
puts "RIS_BOOT_MODE $mode"
if {([expr {$mode}] & 15) != 1} {error "QSPI boot mode is not latched"}
loadhw -hw $package/ris_ctrl_unit.xsa -mem-ranges [list {0x40000000 0xbfffffff}]
foreach {address expected label} {
    0x41200200 0x51414d31 RIS_QAM_ID
    0x41200254 0x51413634 RIS_QAM64_ID
    0x4120025c 0x51505231 RIS_QPR1_ID
} {
    set value [mrd -value $address]
    puts "$label $value"
    if {[expr {$value}] != $expected} {error "Unexpected $label"}
}
set mailbox [mrd -value $mailbox_address 12]
puts "RIS_MAILBOX $mailbox"
if {[expr {[lindex $mailbox 0]}] != 0x52495331 || [expr {[lindex $mailbox 1]}] != 1 || [expr {[lindex $mailbox 2]}] != 1 || [expr {[lindex $mailbox 11]}] != 0} {
    error "Unexpected application mailbox contents"
}
puts RIS_UPLINK_QSPI_BOOT_PASS
disconnect
exit
