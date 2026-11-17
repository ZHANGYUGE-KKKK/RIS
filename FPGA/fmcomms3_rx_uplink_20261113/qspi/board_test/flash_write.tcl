set root /home/wenhan/PROJECTS/RIS/FPGA/ris_qam_backend
set base /home/wenhan/PROJECTS/RIS/FPGA/fmcomms3_rx_uplink_20261113
set package $base/qspi/boot
set report $base/zynq/zc706/fmcomms3_rx/reports/uplink/board_test/replay_qspi_candidate.log
if {![file exists $report] || [catch {exec grep -q PWM3_BOARD_REPLAY_PASS $report}]} {
    error "Missing board replay pass for this QSPI candidate"
}
set backup $base/qspi/board_test/qspi_before.bin
if {![file exists $backup] || [file size $backup] != 33554432} {
    error "Missing receiver Flash backup"
}
set image $package/BOOT.bin
set writer $root/build/flash_qam_20261102/direct_flash.elf
set length [file size $image]
if {[lindex [exec sha256sum $image] 0] ne "740dc4e18874315503ee8dca3c689676406f371199ebe5aa6207faa00c797f92" || $length != 13655056} {
    error "Unexpected uplink boot image"
}
if {[lindex [exec sha256sum $writer] 0] ne "b5e134b509039caadaad72d191ec58fd028328632d985eecc0216250a1552913"} {
    error "Unexpected direct Flash writer"
}
puts [exec python3 -B $package/verify_rx_boot.py $package]

connect -url tcp:127.0.0.1:3121
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299995170"}
set cpu1 {name == "ARM Cortex-A9 MPCore #1" && jtag_cable_serial == "210299995170"}
set fpga {name == "xc7z045" && jtag_cable_serial == "210299995170"}
for {set attempt 0} {$attempt < 10} {incr attempt} {
    if {[llength [targets -target-properties -filter $cpu]] == 1} { break }
    after 300
}
foreach filter [list $cpu $cpu1 $fpga] {
    if {[llength [targets -target-properties -filter $filter]] != 1} {
        error "Expected the confirmed ZC706 on cable 210299995170"
    }
}
targets -set -filter $cpu
set bootmode [mrd -value 0xf800025c]
puts "RX_BOOT_MODE $bootmode"
if {([expr {$bootmode}] & 15) != 0} {
    error "The validated writer requires JTAG boot mode before Flash programming"
}

catch {targets -set -filter $cpu1; stop}
targets -set -filter $cpu
catch {stop}
rst -processor
source $package/ps7_init.tcl
ps7_init
ps7_post_config
dow $writer
dow -data $image 0x1000000
mwr 0x200000 0 16
mwr 0x200020 2
mwr 0x200024 $length
puts "RX_UPLINK_FLASH_WRITE_START offset=0 bytes=$length"
flush stdout
con
set done 0
for {set n 0} {$n < 600} {incr n} {
    after 2000
    set state [mrd -value 0x200000 2]
    puts "FLASH_PROGRESS $state"
    flush stdout
    set code [expr {[lindex $state 0]}]
    if {$code >= 57344} {
        catch {stop}
        error "Flash writer failed: [mrd 0x200000 16]"
    }
    if {$code == 24589} {
        if {[expr {[lindex $state 1]}] != $length} {error "Verified byte count mismatch"}
        set done 1
        break
    }
}
catch {stop}
puts "FLASH_RESULT [mrd 0x200000 16]"
if {!$done} {error "Timed out; Flash update is unconfirmed"}
puts "RX_UPLINK_FLASH_DIRECT_PASS $length"
disconnect
exit
