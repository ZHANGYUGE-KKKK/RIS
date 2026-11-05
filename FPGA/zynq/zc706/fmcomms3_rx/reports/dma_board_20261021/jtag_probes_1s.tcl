set root [file normalize [file join [file dirname [info script]] ../..]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/40400000_0.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/40400000_1.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/40400000_2.bin 0x40400000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/404e4000_0.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/404e4000_1.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/404e4000_2.bin 0x404e4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/40580000_0.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/40580000_1.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/40580000_2.bin 0x40580000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/41184000_0.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/41184000_1.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/41184000_2.bin 0x41184000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/425c4000_0.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/425c4000_1.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/425c4000_2.bin 0x425c4000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/4792f000_0.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/4792f000_1.bin 0x4792f000 1024
mrd -force -address-space AP0 -bin -file $root/reports/dma_board_20261021/jtag_probes_1s/4792f000_2.bin 0x4792f000 1024
configparams force-mem-access 0
disconnect
exit
