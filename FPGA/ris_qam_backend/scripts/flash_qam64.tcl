# Explicit manual Flash update, authorized for the known RIS board.
# Reuses the board's previously validated direct QSPI writer. Never auto-run.
set root [file normalize [file join [file dirname [info script]] ..]]
set package $root/export_flash/20261105_qam64
set image $package/BOOT.bin
set writer $root/build/flash_qam_20261102/direct_flash.elf
set length [file size $image]
if {[lindex [exec sha256sum $image] 0] ne "e46e934f0f573209868e18f195cc27d5ad67fe0671c3f2272eb9807f32491665" || $length!=13556752} {
    error "Unexpected QAM64 boot image"
}
if {[lindex [exec sha256sum $writer] 0] ne "b5e134b509039caadaad72d191ec58fd028328632d985eecc0216250a1552913"} {
    error "Unexpected direct Flash writer"
}
puts [exec python3 $root/scripts/verify_package.py]
puts [exec python3 $root/scripts/verify_zynq_boot.py $package]
connect -url tcp:127.0.0.1:3121
after 1000
set cpu {name == "ARM Cortex-A9 MPCore #0" && jtag_cable_serial == "210299372306"}
set fpga {name == "xc7z045" && jtag_cable_serial == "210299372306"}
if {[llength [targets -target-properties -filter $cpu]]!=1 || [llength [targets -target-properties -filter $fpga]]!=1} {
    error "Expected exactly the confirmed ZC706 target on cable 210299372306"
}
targets -set -filter $cpu
set bootmode [mrd -value 0xf800025c]
puts "RIS_BOOT_MODE $bootmode"
if {([expr {$bootmode}] & 15)!=0} {error "Board must be in JTAG boot mode before Flash programming"}
catch {targets -set -filter {name == "ARM Cortex-A9 MPCore #1" && jtag_cable_serial == "210299372306"}; stop}
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
con
set done 0
for {set n 0} {$n<600} {incr n} {
    after 2000
    set state [mrd -value 0x200000 2]
    puts "FLASH_PROGRESS $state"
    flush stdout
    set code [expr {[lindex $state 0]}]
    if {$code>=57344} {catch {stop}; error "Flash writer failed: [mrd 0x200000 16]"}
    if {$code==24589} {
        if {[expr {[lindex $state 1]}]!=$length} {error "Verified byte count mismatch"}
        set done 1
        break
    }
}
catch {stop}
puts "FLASH_RESULT [mrd 0x200000 16]"
if {!$done} {error "Timed out; Flash update is NOT confirmed"}
puts "RIS_QAM_FLASH_DIRECT_PASS $length"
disconnect
exit
