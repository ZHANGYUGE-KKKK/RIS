# Read-only acceptance after the user switches to QSPI and cycles board power.
# Does not stop/reset/download or write to the target.
set root [file normalize [file join [file dirname [info script]] ..]]
connect -url tcp:127.0.0.1:3121
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299372306"}
if {[llength [targets -target-properties -filter $cpu]]!=1} {error "Expected confirmed RIS board"}
targets -set -filter $cpu
set mode [mrd -value 0xf800025c]
puts "RIS_BOOT_MODE $mode"
if {([expr {$mode}] & 15)!=1} {error "QSPI boot mode is not latched"}
# Import the matching address map into the debugger only; no register init.
loadhw -hw $root/export_qam/ris_ctrl_unit.xsa -mem-ranges [list {0x40000000 0xbfffffff}]
set id [mrd -value 0x41200200]
puts "RIS_QAM_ID $id"
if {[expr {$id}]!=0x51414d31} {error "QAM1 FPGA ID does not match"}
set mailbox [mrd -value 0x00121004 12]
puts "RIS_MAILBOX $mailbox"
if {[expr {[lindex $mailbox 0]}]!=0x52495331 || [expr {[lindex $mailbox 1]}]!=1 || [expr {[lindex $mailbox 2]}]!=1} {
    error "QAM network application is not ready at its expected mailbox"
}
if {[expr {[lindex $mailbox 11]}]!=0} {error "Application reports hardware errors"}
set network [mrd -value 0x00200784]
puts "RIS_NETWORK_ACTIVE $network"
if {[expr {$network}]!=1} {error "Matching firmware TCP listener was not initialized"}
puts "RIS_QAM_COLD_BOOT_PASS: QSPI mode, QAM1 FPGA and matching ARM application ready; no target writes"
disconnect
exit
