set out [file dirname [info script]]
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299995170"}
set apu {name == "APU" && jtag_cable_serial == "210299995170"}
connect -url tcp:127.0.0.1:3121
puts RX_BACKUP_CONNECTED; flush stdout
foreach filter [list $cpu $apu] {
    if {[llength [targets -target-properties -filter $filter]] != 1} {error "Missing receiver target"}
}
targets -set -filter $cpu
if {([expr {[mrd -value 0xf800025c]}] & 15) != 0} {error "Receiver must be in JTAG mode"}
set result [mrd -value 0x200000 3]
puts "RX_BACKUP_DDR_RESULT $result"; flush stdout
if {[expr {[lindex $result 0]}] != 24589 || [expr {[lindex $result 1]}] != 33554432 ||
    [expr {[lindex $result 2]}] != 0x1860ef} {error "Previous flash read did not complete: $result"}
targets -set -filter $cpu
set f [open $out/qspi_before.bin.part wb]
for {set n 0} {$n < 32} {incr n} {
    set address [expr {0x01000000 + $n * 1048576}]
    mrd -bin -file $out/qspi_chunk.bin -size w $address 262144
    if {[file size $out/qspi_chunk.bin] != 1048576} {error "Flash backup chunk truncated"}
    set data [open $out/qspi_chunk.bin rb]
    fcopy $data $f
    close $data
    if {$n % 4 == 3} {puts "RX_QSPI_EXPORT_MIB [expr {$n + 1}]"; flush stdout}
}
close $f
file delete $out/qspi_chunk.bin
if {[file size $out/qspi_before.bin.part] != 33554432} {error "QSPI backup truncated"}
file rename -force $out/qspi_before.bin.part $out/qspi_before.bin
puts "RX_QSPI_BACKUP_PASS [exec sha256sum $out/qspi_before.bin]"
disconnect
exit
