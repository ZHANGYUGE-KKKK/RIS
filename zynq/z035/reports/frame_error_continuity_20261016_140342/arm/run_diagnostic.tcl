set out [file dirname [file normalize [info script]]]
set root [file dirname $out]
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*A9*#0"}
stop
proc regvalue {name} {
    set text [rrd -no-bits $name]
    if {![regexp {:\s*([0-9a-fA-F]+)} $text -> hex]} {error "Cannot parse $name: $text"}
    return [expr 0x$hex]
}
set saved [dict create]
set ris_command [mrd -value 0x001480a8]
foreach r {r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 sp lr pc cpsr} {
    dict set saved $r [regvalue $r]
}
set fd [open $out/saved_cpu_context.tcl w]; puts $fd [list set saved $saved]; close $fd
set expected {3912058880 3800936452 3796750344 3823120384}
if {[mrd -value 0x00120508 4] ne $expected || [dict get $saved pc] != 0x001345a8} {
    error "Expected matching firmware stopped in _exit; refusing stale addresses"
}
dow $out/diagnostic.elf
set return_pc [dict get $saved pc]
set breakpoint [bpadd -addr $return_pc -type hw]
proc set_call {entry arg0 arg1} {
    global saved return_pc
    rwr cpsr [expr {[dict get $saved cpsr] & ~0x20}]
    rwr sp [dict get $saved sp]
    rwr lr $return_pc
    rwr r0 $arg0
    rwr r1 $arg1
    rwr pc $entry
}
proc waitfile {path seconds} {
    set deadline [expr {[clock seconds]+$seconds}]
    while {![file exists $path]} {
        if {[clock seconds]>$deadline} {error "Timeout waiting for $path"}
        after 100
    }
}
set trial [expr {[llength $argv] ? [lindex $argv 0] : 0}]
set failed 0
for {set n $trial} {$n < 7} {incr n} {
    foreach prefix {ready armed captured} {file delete -force $root/${prefix}_$n}
}
if {[catch {
    foreach mode [lrange {0 0 0 1 1 1 2} $trial end] {
        puts "TRIAL_START $trial mode=$mode [clock format [clock seconds]]"
        mwr 0x0210000c 0
        mwr 0x02100010 0
        mwr 0x02100014 0
        set_call 0x02000088 $mode 256
        con
        set deadline [expr {[clock seconds]+15}]
        while {1} {
            set stage [mrd -value 0x02100010]
            if {$stage == 7 || $stage == 100} break
            if {[clock seconds]>$deadline} {error "Preparation timeout trial=$trial stage=$stage"}
            after 100
        }
        if {$stage == 7} {
            close [open $root/ready_$trial w]
            waitfile $root/armed_$trial 60
            mwr 0x0210000c 1
            puts "TRIAL_GATE_RELEASED $trial"
            set deadline [expr {[clock seconds]+15}]
            while {[mrd -value 0x02100014] != 1} {
                if {[clock seconds]>$deadline} {error "Diagnostic timeout trial=$trial"}
                after 100
            }
        }
        after 100
        catch {stop}
        puts "TRIAL_CPU $trial pc=[rrd pc] result=[rrd r0]"
        mrd -bin -file $out/trial_$trial.bin 0x02100000 64
        mrd -bin -file $out/descriptors_$trial.bin 0x40000000 4096
        # Save the first 64 KiB even on failure; the sentinel distinguishes
        # diagnostic partial writes from a completed/accepted DMA window.
        if {$mode != 2} {mrd -bin -file $out/payload_$trial.bin 0x40100000 16384}
        puts "TRIAL_REPORT $trial [mrd -value 0x02100000 49]"
        if {$mode != 2} {waitfile $root/captured_$trial 30}
        set_call 0x0200060c 0 0
        con -block -timeout 10
        puts "TRIAL_RESTORE $trial result=[rrd r0]"
        mrd -bin -file $out/trial_${trial}_restored.bin 0x02100000 64
        if {[regvalue r0] != 0} {error "Restore failed trial=$trial"}
        incr trial
    }
} message options]} {
    set failed 1
    puts "DIAGNOSTIC_ERROR $message"
    puts [dict get $options -errorinfo]
    catch {stop}
    catch {
        set_call 0x0200060c 0 0
        con -block -timeout 10
        puts "EMERGENCY_RESTORE [rrd r0]"
    }
}
catch {stop}
catch {bpremove $breakpoint}
dict for {r value} $saved {if {$r ne "pc" && $r ne "cpsr"} {rwr $r $value}}
rwr cpsr [dict get $saved cpsr]
rwr pc [dict get $saved pc]
puts "FINAL_GPIO [mrd -value 0x80020000] [mrd -value 0x80020008]"
mwr 0x80010004 0
mwr 0x80010000 $ris_command
con
disconnect
if {$failed} {exit 1}
puts ARM_DIAGNOSTIC_COMPLETE
exit
