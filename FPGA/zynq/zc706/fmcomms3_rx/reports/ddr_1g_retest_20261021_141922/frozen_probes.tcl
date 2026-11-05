set here [file dirname [file normalize [info script]]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
puts "DMA frozen regs [mrd -force -address-space AP0 0x81000030 12]"
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40000000_0.bin 0x40000000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40000000_1.bin 0x40000000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40000000_2.bin 0x40000000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40000000_3.bin 0x40000000 1024
puts "FROZEN 0x40000000 saved4reads"
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40400000_0.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40400000_1.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40400000_2.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40400000_3.bin 0x40400000 1024
puts "FROZEN 0x40400000 saved4reads"
mrd -force -address-space AP0 -bin -file $here/frozen_probes/404e4000_0.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/404e4000_1.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/404e4000_2.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/404e4000_3.bin 0x404e4000 1024
puts "FROZEN 0x404e4000 saved4reads"
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40580000_0.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40580000_1.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40580000_2.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40580000_3.bin 0x40580000 1024
puts "FROZEN 0x40580000 saved4reads"
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40bff000_0.bin 0x40bff000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40bff000_1.bin 0x40bff000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40bff000_2.bin 0x40bff000 1024
mrd -force -address-space AP0 -bin -file $here/frozen_probes/40bff000_3.bin 0x40bff000 1024
puts "FROZEN 0x40bff000 saved4reads"
configparams force-mem-access 0
disconnect
exit
