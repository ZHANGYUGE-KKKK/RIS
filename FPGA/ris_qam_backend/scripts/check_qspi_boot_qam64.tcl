# Read-only acceptance after the user switches to QSPI and cycles board power.
# Does not stop/reset/download or write to the target.
set root [file normalize [file join [file dirname [info script]] ..]]
set package $root/export_flash/20261105_qam64
puts [exec python3 $root/scripts/verify_zynq_boot.py $package]
# Resolve symbol addresses from this exact ELF rather than the prior build.
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
# Import the matching address map into the debugger only; no register init.
loadhw -hw $package/ris_ctrl_unit.xsa -mem-ranges [list {0x40000000 0xbfffffff}]
set id [mrd -value 0x41200200]
puts "RIS_QAM_ID $id"
if {[expr {$id}]!=0x51414d31} {error "QAM1 FPGA ID does not match"}
set id64 [mrd -value 0x41200254]
puts "RIS_QAM64_ID $id64"
if {[expr {$id64}]!=0x51413634} {error "64QAM FPGA capability missing"}
set min64 [mrd -value 0x41200258]
puts "RIS_QAM64_MIN_EVENT $min64"
if {[expr {$min64}]!=29} {error "64QAM timing capability differs"}
set mailbox [mrd -value $mailbox_address 12]
puts "RIS_MAILBOX $mailbox"
if {[expr {[lindex $mailbox 0]}]!=0x52495331 || [expr {[lindex $mailbox 1]}]!=1 || [expr {[lindex $mailbox 2]}]!=1} {
    error "QAM network application is not ready at its expected mailbox"
}
if {[expr {[lindex $mailbox 11]}]!=0} {error "Application reports hardware errors"}
set network [mrd -value $active_address]
puts "RIS_NETWORK_ACTIVE $network"
if {[expr {$network}]!=1} {error "Matching firmware TCP listener was not initialized"}
puts "RIS_QAM64_COLD_BOOT_PASS: QSPI mode, QAM1 + QA64 FPGA and matching ARM application ready; no target writes"
disconnect
exit
