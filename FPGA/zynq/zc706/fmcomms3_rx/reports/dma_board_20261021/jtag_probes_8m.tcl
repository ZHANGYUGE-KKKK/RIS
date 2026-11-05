set root [file normalize [file join [file dirname [info script]] ../..]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
foreach address {0x40000000 0x40400000 0x404E4000 0x40580000 0x40BFF000} {
    for {set trial 0} {$trial < 4} {incr trial} {
        set name [format "%08x_%d.bin" $address $trial]
        mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_8m/$name $address 1024
        puts "READ $name"
    }
}
configparams force-mem-access 0
disconnect
exit
