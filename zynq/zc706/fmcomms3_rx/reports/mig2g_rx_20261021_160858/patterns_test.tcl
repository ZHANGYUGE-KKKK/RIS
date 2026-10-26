set here [file dirname [file normalize [info script]]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
puts "DMA before known-page tests: [mrd -force -address-space AP0 0x81000030 12]"
set result [catch {
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_zero_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_zero_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_zero_2.bin 0x30000000 1024
puts "PAGE 30000000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_ones_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_ones_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_ones_2.bin 0x30000000 1024
puts "PAGE 30000000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_alternating_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_alternating_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_alternating_2.bin 0x30000000 1024
puts "PAGE 30000000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_random_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_random_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/30000000_random_2.bin 0x30000000 1024
puts "PAGE 30000000 random saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_zero_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_zero_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_zero_2.bin 0x40400000 1024
puts "PAGE 40400000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_ones_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_ones_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_ones_2.bin 0x40400000 1024
puts "PAGE 40400000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_alternating_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_alternating_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_alternating_2.bin 0x40400000 1024
puts "PAGE 40400000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_random_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_random_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40400000_random_2.bin 0x40400000 1024
puts "PAGE 40400000 random saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_zero_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_zero_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_zero_2.bin 0x404e4000 1024
puts "PAGE 404e4000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_ones_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_ones_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_ones_2.bin 0x404e4000 1024
puts "PAGE 404e4000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_alternating_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_alternating_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_alternating_2.bin 0x404e4000 1024
puts "PAGE 404e4000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_random_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_random_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/404e4000_random_2.bin 0x404e4000 1024
puts "PAGE 404e4000 random saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_zero_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_zero_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_zero_2.bin 0x40580000 1024
puts "PAGE 40580000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_ones_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_ones_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_ones_2.bin 0x40580000 1024
puts "PAGE 40580000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_alternating_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_alternating_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_alternating_2.bin 0x40580000 1024
puts "PAGE 40580000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_random_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_random_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/40580000_random_2.bin 0x40580000 1024
puts "PAGE 40580000 random saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_zero_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_zero_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_zero_2.bin 0x41184000 1024
puts "PAGE 41184000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_ones_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_ones_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_ones_2.bin 0x41184000 1024
puts "PAGE 41184000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_alternating_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_alternating_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_alternating_2.bin 0x41184000 1024
puts "PAGE 41184000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_random_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_random_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/41184000_random_2.bin 0x41184000 1024
puts "PAGE 41184000 random saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_zero_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_zero_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_zero_2.bin 0x425c4000 1024
puts "PAGE 425c4000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_ones_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_ones_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_ones_2.bin 0x425c4000 1024
puts "PAGE 425c4000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_alternating_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_alternating_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_alternating_2.bin 0x425c4000 1024
puts "PAGE 425c4000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_random_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_random_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/425c4000_random_2.bin 0x425c4000 1024
puts "PAGE 425c4000 random saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_zero_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_zero_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_zero_2.bin 0x4792f000 1024
puts "PAGE 4792f000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_ones_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_ones_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_ones_2.bin 0x4792f000 1024
puts "PAGE 4792f000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_alternating_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_alternating_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_alternating_2.bin 0x4792f000 1024
puts "PAGE 4792f000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_random_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_random_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/4792f000_random_2.bin 0x4792f000 1024
puts "PAGE 4792f000 random saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_zero_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_zero_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_zero_2.bin 0x70000000 1024
puts "PAGE 70000000 zero saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_ones_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_ones_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_ones_2.bin 0x70000000 1024
puts "PAGE 70000000 ones saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_alternating_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_alternating_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_alternating_2.bin 0x70000000 1024
puts "PAGE 70000000 alternating saved3reads"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_random_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_random_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_readback/70000000_random_2.bin 0x70000000 1024
puts "PAGE 70000000 random saved3reads"
} message options]
configparams force-mem-access 0
disconnect
if {$result} {return -options $options $message}
puts DDR2G_RX_KNOWN_PAGES_DONE
exit
