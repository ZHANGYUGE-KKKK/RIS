set here [file dirname [file normalize [info script]]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
set result [catch {
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_zero_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_zero_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_zero_2.bin 0x30000000 1024
puts "TEST running 30000000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_ones_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_ones_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_ones_2.bin 0x30000000 1024
puts "TEST running 30000000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_alternating_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_alternating_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_alternating_2.bin 0x30000000 1024
puts "TEST running 30000000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_random_0.bin 0x30000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_random_1.bin 0x30000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/30000000_random_2.bin 0x30000000 1024
puts "TEST running 30000000 random"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_zero_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_zero_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_zero_2.bin 0x40400000 1024
puts "TEST running 40400000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_ones_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_ones_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_ones_2.bin 0x40400000 1024
puts "TEST running 40400000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_alternating_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_alternating_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_alternating_2.bin 0x40400000 1024
puts "TEST running 40400000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_random_0.bin 0x40400000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_random_1.bin 0x40400000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40400000_random_2.bin 0x40400000 1024
puts "TEST running 40400000 random"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_zero_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_zero_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_zero_2.bin 0x404e4000 1024
puts "TEST running 404e4000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_ones_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_ones_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_ones_2.bin 0x404e4000 1024
puts "TEST running 404e4000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_alternating_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_alternating_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_alternating_2.bin 0x404e4000 1024
puts "TEST running 404e4000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_random_0.bin 0x404e4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_random_1.bin 0x404e4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/404e4000_random_2.bin 0x404e4000 1024
puts "TEST running 404e4000 random"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_zero_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_zero_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_zero_2.bin 0x40580000 1024
puts "TEST running 40580000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_ones_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_ones_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_ones_2.bin 0x40580000 1024
puts "TEST running 40580000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_alternating_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_alternating_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_alternating_2.bin 0x40580000 1024
puts "TEST running 40580000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_random_0.bin 0x40580000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_random_1.bin 0x40580000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/40580000_random_2.bin 0x40580000 1024
puts "TEST running 40580000 random"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_zero_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_zero_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_zero_2.bin 0x41184000 1024
puts "TEST running 41184000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_ones_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_ones_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_ones_2.bin 0x41184000 1024
puts "TEST running 41184000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_alternating_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_alternating_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_alternating_2.bin 0x41184000 1024
puts "TEST running 41184000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_random_0.bin 0x41184000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_random_1.bin 0x41184000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/41184000_random_2.bin 0x41184000 1024
puts "TEST running 41184000 random"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_zero_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_zero_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_zero_2.bin 0x425c4000 1024
puts "TEST running 425c4000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_ones_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_ones_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_ones_2.bin 0x425c4000 1024
puts "TEST running 425c4000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_alternating_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_alternating_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_alternating_2.bin 0x425c4000 1024
puts "TEST running 425c4000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_random_0.bin 0x425c4000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_random_1.bin 0x425c4000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/425c4000_random_2.bin 0x425c4000 1024
puts "TEST running 425c4000 random"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_zero_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_zero_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_zero_2.bin 0x4792f000 1024
puts "TEST running 4792f000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_ones_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_ones_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_ones_2.bin 0x4792f000 1024
puts "TEST running 4792f000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_alternating_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_alternating_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_alternating_2.bin 0x4792f000 1024
puts "TEST running 4792f000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_random_0.bin 0x4792f000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_random_1.bin 0x4792f000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/4792f000_random_2.bin 0x4792f000 1024
puts "TEST running 4792f000 random"
mwr -force -address-space AP0 -bin -file $here/patterns/zero.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_zero_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_zero_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_zero_2.bin 0x70000000 1024
puts "TEST running 70000000 zero"
mwr -force -address-space AP0 -bin -file $here/patterns/ones.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_ones_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_ones_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_ones_2.bin 0x70000000 1024
puts "TEST running 70000000 ones"
mwr -force -address-space AP0 -bin -file $here/patterns/alternating.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_alternating_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_alternating_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_alternating_2.bin 0x70000000 1024
puts "TEST running 70000000 alternating"
mwr -force -address-space AP0 -bin -file $here/patterns/random.bin 0x70000000 1024
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_random_0.bin 0x70000000 1024
after 20
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_random_1.bin 0x70000000 1024
after 200
mrd -force -address-space AP0 -bin -file $here/patterns_running/70000000_random_2.bin 0x70000000 1024
puts "TEST running 70000000 random"
} message]
configparams force-mem-access 0
disconnect
if {$result} {error $message}
exit
