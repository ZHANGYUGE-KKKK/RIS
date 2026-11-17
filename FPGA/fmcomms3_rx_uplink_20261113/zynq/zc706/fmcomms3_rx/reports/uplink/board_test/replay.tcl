set cable 210299995170
set cpu [format {name =~ "*A9*#0" && jtag_cable_serial == "%s"} $cable]
set length 3932160
set iq 0x00775a40
set decoder 0x0012bb18
set flush 0x00112818
set source [file join [file dirname [info script]] pwm3_known_iq.bin]
if {[file size $source] != $length} {error "Incorrect IQ length"}
connect -url tcp:127.0.0.1:3121
if {[llength [targets -target-properties -filter $cpu]] != 1} {
    error "Expected one matching receiver CPU"
}
targets -set -filter $cpu
proc reg_value {name} {
    set line [rrd $name]
    if {![regexp -nocase {:\s*(?:0x)?([[:xdigit:]]+)\s*$} $line -> value]} {
        error "Cannot parse $name: $line"
    }
    return [expr 0x$value]
}
set bp [bpadd -addr $decoder -type hw]
set resume 0
set failed [catch {
    for {set n 0} {$n < 100} {incr n} {
        after 100
        if {[catch {rrd pc}]} {continue}
        set pc [reg_value pc]
        if {$pc == $decoder} {set resume 1; break}
    }
    if {!$resume} {error "Receiver did not hit PWM3 decoder"}
    if {[reg_value r0] != $iq} {error "Unexpected decoder input address"}
    puts "RX_PWM3_DECODER_STOPPED pc=[format 0x%08x [reg_value pc]] iq=[format 0x%08x [reg_value r0]]"
    foreach reg {r0 r1 r2 r3 r12 lr cpsr} {set saved($reg) [reg_value $reg]}
    rwr r0 $iq
    rwr r1 $length
    rwr lr $decoder
    con -addr $flush -block -timeout 12
    if {[reg_value pc] != $decoder} {error "Cache maintenance did not return to decoder"}
    foreach reg {r0 r1 r2 r3 r12 lr cpsr} {rwr $reg $saved($reg)}
    dow -data $source $iq
    puts "RX_PWM3_IQ_REPLAY_LOADED $length"
} message]
catch {bpremove $bp}
if {$resume} {catch {con}}
disconnect
if {$failed} {error $message}
exit
