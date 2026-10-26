set root [file normalize [file join [file dirname [info script]] ../..]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
for {set n 0} {$n < 8} {incr n} {
    set address [expr {0x40400000+$n*0x100000}]
    mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/capture8m_jtag/chunk$n.bin $address 262144
    puts "SAVED MiB $n"
}
configparams force-mem-access 0
disconnect
exit
