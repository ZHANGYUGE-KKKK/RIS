set out [file dirname [file normalize [info script]]]
connect -url tcp:127.0.0.1:3121
set target_deadline [expr {[clock milliseconds]+10000}]
while {[catch {targets -set -nocase -filter {name =~ "*A9*#0"}} target_error]} {
    if {[clock milliseconds]>$target_deadline} {
        puts "JTAG_TARGETS [jtag targets]"
        disconnect
        error "No Cortex-A9 target after enumeration wait: $target_error"
    }
    after 500
}
configparams force-mem-access 1
catch {stop}
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
if {[catch {
    if {[mrd -value 0x00120508 4] ne {3912058880 3800936452 3796750344 3823120384} ||
        [dict get $saved pc] != 0x001345a8 || [mrd -value 0x80020000]!=0} {
        error "Firmware/context/ARM changed; absolute calls not allowed"
    }
} preflight_error]} {
    configparams force-mem-access 0
    con;disconnect;error $preflight_error
}
set return_pc [dict get $saved pc]
set breakpoint ""
set ready 0
set trials_started 0
proc call_trial {action} {
    global saved return_pc
    rwr cpsr [expr {[dict get $saved cpsr]&~0x20}]
    rwr sp [dict get $saved sp];rwr lr $return_pc
    rwr r0 $action;rwr pc 0x02600458
    con -block -timeout 20
    set result [regvalue r0]
    puts "BLOG_TRIAL_ACTION $action result=$result"
    if {$result!=0} {error "Trial action failed: $result"}
}
proc dump_trial {name} {
    global out
    mrd -bin -file $out/header_$name.bin 0x02700000 128
    mrd -bin -file $out/spi_$name.bin 0x02701000 1024
    set count [mrd -value 0x02700018]
    if {$count>0 && $count<=256} {
        mrd -bin -file $out/rows_$name.bin 0x02702000 [expr {$count*32}]
    }
}
set failed 0
if {[catch {
    dow $out/trial.elf
    set breakpoint [bpadd -addr $return_pc -type hw]
    call_trial 0
    set ready 1
    dump_trial baseline
    foreach a {0x006 0x009 0x010 0x011 0x012 0x03c 0x03d 0x03e 0x3f4 0x3f5 0x3f6} {
        puts [format {SPI_BASELINE %03x %02x} $a [mrd -value [expr {0x02701000+4*$a}]]]
    }
    set trials_started 1
    call_trial 1
    dump_trial trials
    puts "TRIAL_COUNT [mrd -value 0x02700018] PASS_COUNT [mrd -value 0x0270001c] RESTORE [mrd -value 0x02700014]"
    call_trial 0
    dump_trial final
} message options]} {
    set failed 1
    puts "BLOG_TRIAL_ERROR $message\n[dict get $options -errorinfo]"
    catch {stop}
    if {$ready && $trials_started} {
        if {[catch {call_trial 2} restore_error]} {puts "RESTORE_ERROR $restore_error"}
        catch {dump_trial emergency}
    }
}
catch {stop}
if {$breakpoint ne ""} {catch {bpremove $breakpoint}}
dict for {r value} $saved {if {$r ne "pc" && $r ne "cpsr"} {rwr $r $value}}
rwr cpsr [dict get $saved cpsr];rwr pc [dict get $saved pc]
configparams force-mem-access 1
puts "FINAL_ARM [mrd -value 0x80020000] FINAL_FLAGS [mrd -value 0x80020008]"
configparams force-mem-access 0
con
disconnect
if {$failed} {exit 1}
puts BLOG_TIMING_TRIAL_COMPLETE
exit
