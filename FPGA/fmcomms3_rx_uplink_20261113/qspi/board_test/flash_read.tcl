set base /home/wenhan/PROJECTS/RIS/FPGA/fmcomms3_rx_uplink_20261113
set package $base/qspi/boot
set out [file dirname [info script]]
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299995170"}
set cpu1 {name == "ARM Cortex-A9 MPCore #1" && jtag_cable_serial == "210299995170"}
set fpga {name == "xc7z045" && jtag_cable_serial == "210299995170"}
connect -url tcp:127.0.0.1:3121
foreach filter [list $cpu $cpu1 $fpga] {
    if {[llength [targets -target-properties -filter $filter]] != 1} {
        error "Expected exactly the confirmed RX ZC706 target on cable 210299995170"
    }
}
targets -set -filter $cpu
set mode [mrd -value 0xf800025c]
if {([expr {$mode}] & 15) != 0} {error "Receiver must be in JTAG boot mode"}
catch {targets -set -filter $cpu1; stop}
targets -set -filter $cpu
catch {stop}
rst -processor
source $package/ps7_init.tcl
ps7_init
ps7_post_config
dow $out/flash_read.elf
mwr 0x200000 0 3
con
set done 0
for {set n 0} {$n < 90} {incr n} {
    after 1000
    set state [mrd -value 0x200000 3]
    if {$n % 5 == 0} {puts "RX_QSPI_BACKUP_PROGRESS $state"}
    flush stdout
    set code [expr {[lindex $state 0]}]
    if {$code >= 57344} {error "Receiver read-only QSPI probe failed: $state"}
    if {$code == 24589} {
        if {[expr {[lindex $state 1]}] != 33554432 || [expr {[lindex $state 2]}] != 0x1860ef} {
            error "Receiver QSPI ID or backup length differs"
        }
        set done 1
        break
    }
}
catch {stop}
if {!$done} {error "Receiver QSPI read did not complete"}
mrd -bin -file $out/qspi_before.bin.part -size b 0x01000000 33554432
if {[file size $out/qspi_before.bin.part] != 33554432} {error "QSPI backup file truncated"}
file rename -force $out/qspi_before.bin.part $out/qspi_before.bin
puts "RX_QSPI_BACKUP_PASS [exec sha256sum $out/qspi_before.bin]"
disconnect
exit
