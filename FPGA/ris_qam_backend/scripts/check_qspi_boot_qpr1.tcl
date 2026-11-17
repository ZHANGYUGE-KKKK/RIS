# Read-only acceptance after QSPI selection and a full power cycle.
set root [file normalize [file join [file dirname [info script]] ..]]
set package $root/export_flash/20261109_qpr1
set symbols [exec readelf -sW $package/ris_all_io.elf]
if {![regexp -line {^\s+[0-9]+:\s+([0-9a-fA-F]+)\s+[0-9]+\s+OBJECT\s+GLOBAL\s+DEFAULT\s+[0-9]+\s+ris_mailbox\s*$} $symbols unused mailbox_hex]} {error "No matching mailbox symbol"}
if {![regexp -line {^\s+[0-9]+:\s+([0-9a-fA-F]+)\s+4\s+[^ ]+\s+LOCAL\s+DEFAULT\s+[0-9]+\s+active\s*$} $symbols unused active_hex]} {error "No matching network active symbol"}
scan $mailbox_hex %x mailbox_address
scan $active_hex %x active_address
connect -url tcp:127.0.0.1:3121
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299372306"}
if {[llength [targets -target-properties -filter $cpu]]!=1} {error "Expected confirmed RIS board"}
targets -set -filter $cpu
set mode [mrd -value 0xf800025c]
puts "RIS_BOOT_MODE $mode"
if {([expr {$mode}] & 15)!=1} {error "QSPI boot mode is not latched"}
# Import the matching map into the debugger only; no target initialization.
loadhw -hw $package/ris_ctrl_unit.xsa -mem-ranges [list {0x40000000 0xbfffffff}]
foreach {address expected label} {
    0x41200200 0x51414d31 RIS_QAM_ID
    0x41200254 0x51413634 RIS_QAM64_ID
    0x41200258 29 RIS_QAM64_MIN_EVENT
    0x4120025c 0x51505231 RIS_QPR1_ID
    0x41200264 14 RIS_QPR1_CAPACITY
} {
    set value [mrd -value $address]
    puts "$label $value"
    if {[expr {$value}]!=$expected} {error "Unexpected $label"}
}
set mailbox [mrd -value $mailbox_address 12]
puts "RIS_MAILBOX $mailbox"
if {[expr {[lindex $mailbox 0]}]!=0x52495331 || [expr {[lindex $mailbox 1]}]!=1 || [expr {[lindex $mailbox 2]}]!=1} {
    error "QPR1 network application is not ready at its expected mailbox"
}
if {[expr {[lindex $mailbox 11]}]!=0} {error "Application reports hardware errors"}
set network [mrd -value $active_address]
puts "RIS_NETWORK_ACTIVE $network"
if {[expr {$network}]!=1} {error "Matching firmware TCP listener was not initialized"}
puts "RIS_QPR1_COLD_BOOT_PASS: QSPI, QAM1 + QA64 + QPR1 and matching application ready; no target writes"
disconnect
exit
