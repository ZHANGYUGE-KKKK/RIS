set root [file normalize [file join [file dirname [info script]] ../..]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "ARM Cortex-A9 MPCore #0"}
stop
set saved [dict create]
foreach reg {r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 sp lr pc cpsr} {
 set val [rrd $reg]
 if {![regexp {:\s*([0-9a-fA-F]{8})} $val -> hex]} {error "Cannot save $reg"}
 dict set saved $reg 0x$hex
}
puts "SAVED CPU0 $saved"
configparams force-mem-access 1
dow $root/reports/dma_board_20261021/spd_probe.elf
rwr sp 0x30030000
con
after 2000
stop
puts "SPD helper PC=[rrd pc]"
targets -set -filter {name == "APU"}
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/spd_result.bin 0x30018000 70
targets -set -filter {name == "ARM Cortex-A9 MPCore #0"}
rwr cpsr [dict get $saved cpsr]
dict for {reg val} $saved {if {$reg ne "cpsr"} {rwr $reg $val}}
configparams force-mem-access 0
con
puts "RESTORED CPU0"
disconnect
exit
