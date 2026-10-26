# Run after program_board.tcl. Exercises running ARM firmware through its mailbox.
# Checks AXI completion, all 50 command mirrors, frame counts and OE control.
# Does not claim physical 595 output readback.
# With one argument 0/1/b/s/d/e, performs only that control action instead.
set root [file normalize [file join [file dirname [info script]] ..]]
set artifacts $root/export
if {[info exists ::env(RIS_EXPORT_DIR)]} {set artifacts [file normalize $::env(RIS_EXPORT_DIR)]}
set serial 210299995170
if {[info exists ::env(RIS_JTAG_SERIAL)]} {set serial $::env(RIS_JTAG_SERIAL)}
set url tcp:127.0.0.1:3121
if {[info exists ::env(RIS_HW_SERVER)]} {set url $::env(RIS_HW_SERVER)}
set nm /home/yyz/vivado2020.2/main/Vitis/2020.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-nm
if {[info exists ::env(RIS_ARM_NM)]} {set nm $::env(RIS_ARM_NM)}
set symbols [exec $nm -g $artifacts/ris_all_io.elf]
if {![regexp -line {^([0-9a-fA-F]+) [A-Za-z] ris_mailbox$} $symbols -> address]} {
    error "ELF mailbox symbol missing"
}
scan $address %x mailbox
connect -url $url
targets -set -filter [format {name =~ "*A9*#0" && jtag_cable_serial == "%s"} $serial]
proc read32 {address} {
    # XSCT 2020.2 returns numeric decimal values, not hexadecimal text.
    return [expr {[lindex [mrd -value $address 1] 0] & 0xffffffff}]
}
proc wait_word {address expected} {
    for {set n 0} {$n < 100} {incr n} {
        if {[read32 $address] == $expected} {return}
        after 50
    }
    error [format "Timeout at 0x%08x: wanted %08x, read %08x" $address $expected [read32 $address]]
}
if {[read32 $mailbox] != 0x52495331 || [read32 [expr {$mailbox+4}]] != 1} {
    error "Firmware mailbox signature/version mismatch"
}
wait_word [expr {$mailbox+8}] 1
set sequence [read32 [expr {$mailbox+20}]]
proc request {command} {
    global mailbox sequence
    incr sequence
    mwr [expr {$mailbox+16}] $command
    mwr [expr {$mailbox+12}] $sequence
    wait_word [expr {$mailbox+20}] $sequence
    if {[read32 [expr {$mailbox+24}]] != 0} {error "Firmware command $command failed"}
    if {[read32 [expr {$mailbox+44}]] != 0} {error "Controller ERROR_FLAGS nonzero"}
}
if {[llength $argv]} {
    if {[llength $argv] != 1 || ![dict exists {0 1 1 2 b 3 s 4 d 5 e 6} [lindex $argv 0]]} {
        error "Usage: xsct scripts/verify_board.tcl ?0|1|b|s|d|e?"
    }
    request [dict get {0 1 1 2 b 3 s 4 d 5 e 6} [lindex $argv 0]]
    puts [format "RIS_CONTROL_PASS pattern=%u status=%08x errors=%08x frames=%u" \
        [read32 [expr {$mailbox+28}]] [read32 [expr {$mailbox+40}]] \
        [read32 [expr {$mailbox+44}]] [read32 [expr {$mailbox+32}]]]
    disconnect
    exit
}
set verification_rc [catch {
set frame_slots [read32 0x4120008c]
if {$frame_slots<1 || $frame_slots>256} {error "Unexpected frame capacity: $frame_slots"}
set last_word [expr {0x41201000+$frame_slots*64-4}]
foreach {address value} [list 0x41201000 0x01234567 0x41201004 0x89abcdef $last_word 0xa5a55a5a] {
    mwr $address $value
    if {[read32 $address] != $value} {error "Frame BRAM read/write mismatch at $address"}
}
puts "PASS: frame BRAM reads/writes at first words and final word ($frame_slots slots)"
set previous [read32 [expr {$mailbox+32}]]
for {set n 0} {$n < 20} {incr n} {
    set high [expr {$n % 2}]
    request [expr {$high ? 2 : 1}]
    set frames [read32 [expr {$mailbox+32}]]
    if {$frames != $previous+1} {error "Frame counter did not advance exactly once"}
    set previous $frames
    set status [read32 [expr {$mailbox+40}]]
    if {($status & 0xff) != 0xc2} {error [format "Unexpected HOLD/IDLE/OE status %08x" $status]}
    for {set w 0} {$w < 13} {incr w} {
        set expected [expr {$high ? ($w == 12 ? 0xffff : 0xffffffff) : 0}]
        if {[read32 [expr {$mailbox+48+$w*4}]] != $expected} {
            error "50-chip image mismatch at word $w"
        }
    }
    puts "PASS update $n: all [expr {$high ? {HIGH} : {LOW}}], frame=$frames, status=[format %08x $status]"
}
request 5
if {[read32 [expr {$mailbox+40}]] & 0x80} {error "OE disable failed"}
request 6
if {!([read32 [expr {$mailbox+40}]] & 0x80)} {error "OE enable failed"}
request 1
puts "RIS_BOARD_SMOKE_PASS: ARM firmware/AXI4/BRAM/50 mirrors/20 updates/OE; final all LOW"
puts "Physical Q outputs are not read back (Q7S is not connected)."
} verification_error]
if {$verification_rc} {
    catch {request 1}
    disconnect
    error $verification_error
}
disconnect
exit
