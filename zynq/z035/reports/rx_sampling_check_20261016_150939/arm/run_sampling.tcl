set out [file dirname [file normalize [info script]]]
set root [file dirname $out]
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*A9*#0"}
stop
proc regvalue {name} {
    set result [rrd -no-bits $name]
    if {![regexp {:\s*([0-9a-fA-F]+)} $result -> hex]} {error "Cannot read $name"}
    return [expr 0x$hex]
}
set saved [dict create]
foreach r {r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 sp lr pc cpsr} {
    dict set saved $r [regvalue $r]
}
set fd [open $out/saved_context.tcl w];puts $fd [list set saved $saved];close $fd
if {[mrd -value 0x00120508 4] ne {3912058880 3800936452 3796750344 3823120384} ||
    [dict get $saved pc] != 0x001345a8} {
    con;disconnect;error "Firmware/context changed; stop before using absolute addresses"
}
if {[mrd -value 0x80020000]!=0} {con;disconnect;error "Capture ARM must be zero"}
dow $out/sampling.elf
set return_pc [dict get $saved pc]
set breakpoint [bpadd -addr $return_pc -type hw]
proc call_sampling {action {a0 0} {a1 0}} {
    global saved return_pc
    rwr cpsr [expr {[dict get $saved cpsr]&~0x20}]
    rwr sp [dict get $saved sp];rwr lr $return_pc
    rwr r0 $action;rwr r1 $a0;rwr r2 $a1;rwr pc 0x02200324
    con -block -timeout 45
    set result [regvalue r0]
    puts "SAMPLING_ACTION $action $a0 $a1 result=$result rows=[mrd -value 0x02300018] passes=[mrd -value 0x0230001c]"
    if {$result!=0} {error "Sampling action $action failed: $result"}
}
proc dump_sampling {name} {
    global out
    mrd -bin -file $out/header_$name.bin 0x02300000 128
    mrd -bin -file $out/spi_$name.bin 0x02301000 1024
    set count [mrd -value 0x02300018]
    if {$count>0} {mrd -bin -file $out/rows_$name.bin 0x02302000 [expr {$count*24}]}
}
proc capture_condition {n name} {
    global root
    set fd [open $root/ready_$n w];puts $fd $name;close $fd
    set deadline [expr {[clock seconds]+90}]
    while {![file exists $root/captured_$n]} {
        if {[clock seconds]>$deadline} {error "ILA timeout for $name"}
        after 100
    }
    puts "CONDITION_CAPTURED $n $name"
}
set failed 0
if {[catch {
    call_sampling 0
    dump_sampling baseline
    capture_condition 0 ordinary_original
    call_sampling 6
    capture_condition 1 PRBS_original
    call_sampling 1
    dump_sampling frame_scan
    set best_frame [mrd -value 0x02300058]
    call_sampling 4 $best_frame 0
    capture_condition 2 PRBS_best_frame
    call_sampling 2
    dump_sampling spi_scan
    call_sampling 3
    dump_sampling fpga_scan
    call_sampling 4 16 0
    capture_condition 3 PRBS_frame16
    set original_delay [mrd -value 0x02301018]
    call_sampling 5 1 $original_delay
    capture_condition 4 PRBS_clock_inverted
    call_sampling 5 0 136
    capture_condition 5 PRBS_device_delay88
    call_sampling 7
    capture_condition 6 restored_original
    dump_sampling final
} message options]} {
    set failed 1
    puts "SAMPLING_ERROR $message\n[dict get $options -errorinfo]"
    catch {stop}
    if {[mrd -value 0x02300004]==1} {
        catch {call_sampling 7} restore_error
        puts "EMERGENCY_RESTORE $restore_error"
        catch {dump_sampling emergency}
    }
}
catch {stop}
catch {bpremove $breakpoint}
dict for {r value} $saved {if {$r ne "pc" && $r ne "cpsr"} {rwr $r $value}}
rwr cpsr [dict get $saved cpsr];rwr pc [dict get $saved pc]
configparams force-mem-access 1
puts "FINAL_ARM [mrd -value 0x80020000] FINAL_FLAGS [mrd -value 0x80020008]"
puts "RESTORE_RESULT [mrd -value 0x02300014]"
configparams force-mem-access 0
con
disconnect
if {$failed} {exit 1}
puts SAMPLING_CHECK_COMPLETE
exit
