set out [file dirname [file normalize [info script]]]
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
    [dict get $saved pc] != 0x001345a8 || [mrd -value 0x80020000]!=0} {
    con;disconnect;error "Firmware/context/ARM changed; absolute calls not allowed"
}
set return_pc [dict get $saved pc]
set breakpoint ""
set ready 0
set trials_started 0
proc call_audit {action} {
    global saved return_pc
    rwr cpsr [expr {[dict get $saved cpsr]&~0x20}]
    rwr sp [dict get $saved sp];rwr lr $return_pc
    rwr r0 $action;rwr pc 0x0240015c
    con -block -timeout 10
    set result [regvalue r0]
    puts "AUDIT_ACTION $action result=$result"
    if {$result!=0} {error "Audit action failed: $result"}
}
proc dump_audit {name} {
    global out
    mrd -bin -file $out/header_$name.bin 0x02500000 128
    mrd -bin -file $out/spi_$name.bin 0x02501000 1024
    mrd -bin -file $out/rows_$name.bin 0x02502000 128
}
set failed 0
if {[catch {
    dow $out/audit.elf
    set breakpoint [bpadd -addr $return_pc -type hw]
    call_audit 0
    set ready 1
    dump_audit baseline
    foreach a {0x002 0x003 0x006 0x009 0x00a 0x010 0x011 0x012 0x03c 0x03d 0x03e 0x05e 0x247 0x287 0x292 0x293 0x294 0x3f4 0x3f5 0x3f6} {
        puts [format {SPI_BASELINE %03x %02x} $a [mrd -value [expr {0x02501000+4*$a}]]]
    }
    if {[mrd -value 0x02501040]!=200 || [mrd -value 0x02501018]!=15 ||
        [mrd -value 0x025010f4]!=0 || [mrd -value 0x025010f8]!=0} {
        error "Baseline differs from verified scan; leave SPI unchanged"
    }
    set trials_started 1
    call_audit 1
    dump_audit trials
    puts "TRIAL_COUNT [mrd -value 0x02500018] PASS_COUNT [mrd -value 0x0250001c] RESTORE [mrd -value 0x02500014]"
    for {set n 0} {$n<4} {incr n} {
        puts "TRIAL $n [mrd -value [expr {0x02502000+128*$n}] 17]"
    }
    call_audit 0
    dump_audit final
} message options]} {
    set failed 1
    puts "AUDIT_ERROR $message\n[dict get $options -errorinfo]"
    catch {stop}
    if {$ready && $trials_started} {
        if {[catch {call_audit 2} restore_error]} {puts "RESTORE_ERROR $restore_error"}
        catch {dump_audit emergency}
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
puts SPI_CONFIG_AUDIT_COMPLETE
exit
