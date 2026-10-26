set root [file normalize [file join [file dirname [info script]] ../..]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "ARM Cortex-A9 MPCore #0"}
stop
puts "CPU0 PC=[rrd pc] CPSR=[rrd cpsr]"
targets -set -filter {name == "ARM Cortex-A9 MPCore #1"}
stop
puts "CPU1 PC=[rrd pc] CPSR=[rrd cpsr]"
targets -set -filter {name == "APU"}
configparams force-mem-access 1
mwr -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_patterns/random.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/30000000_0.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/30000000_1.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/30000000_2.bin 0x30000000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/30000000_3.bin 0x30000000 1024
puts "HALTED TEST 0x30000000"
mwr -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_patterns/random.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40400000_0.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40400000_1.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40400000_2.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40400000_3.bin 0x40400000 1024
puts "HALTED TEST 0x40400000"
mwr -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_patterns/random.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40580000_0.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40580000_1.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40580000_2.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/40580000_3.bin 0x40580000 1024
puts "HALTED TEST 0x40580000"
mwr -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_patterns/random.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/41184000_0.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/41184000_1.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/41184000_2.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/41184000_3.bin 0x41184000 1024
puts "HALTED TEST 0x41184000"
mwr -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_patterns/random.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/425c4000_0.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/425c4000_1.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/425c4000_2.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/memory_halted/425c4000_3.bin 0x425c4000 1024
puts "HALTED TEST 0x425c4000"
configparams force-mem-access 0
targets -set -filter {name == "ARM Cortex-A9 MPCore #1"}
con
targets -set -filter {name == "ARM Cortex-A9 MPCore #0"}
con
disconnect
exit
