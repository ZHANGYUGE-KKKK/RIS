connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
set result [catch {
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00000000_zero.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00400000_zero.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/04000000_zero.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/3ffff000_zero.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40000000_zero.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40400000_zero.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/44000000_zero.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/7ffff000_zero.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_zero_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_zero_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_zero_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_zero_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_zero_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_zero_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_zero_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_zero_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_zero_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_zero_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_zero_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_zero_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_zero_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_zero_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_zero_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_zero_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_zero_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_zero_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_zero_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_zero_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_zero_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_zero_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_zero_2.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_zero_2.bin} 0x7ffff000 1024
puts "RANK_TEST zero saved 24 reads"
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00000000_ones.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00400000_ones.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/04000000_ones.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/3ffff000_ones.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40000000_ones.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40400000_ones.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/44000000_ones.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/7ffff000_ones.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_ones_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_ones_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_ones_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_ones_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_ones_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_ones_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_ones_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_ones_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_ones_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_ones_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_ones_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_ones_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_ones_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_ones_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_ones_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_ones_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_ones_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_ones_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_ones_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_ones_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_ones_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_ones_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_ones_2.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_ones_2.bin} 0x7ffff000 1024
puts "RANK_TEST ones saved 24 reads"
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00000000_alternating.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00400000_alternating.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/04000000_alternating.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/3ffff000_alternating.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40000000_alternating.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40400000_alternating.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/44000000_alternating.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/7ffff000_alternating.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_alternating_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_alternating_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_alternating_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_alternating_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_alternating_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_alternating_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_alternating_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_alternating_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_alternating_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_alternating_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_alternating_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_alternating_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_alternating_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_alternating_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_alternating_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_alternating_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_alternating_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_alternating_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_alternating_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_alternating_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_alternating_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_alternating_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_alternating_2.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_alternating_2.bin} 0x7ffff000 1024
puts "RANK_TEST alternating saved 24 reads"
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00000000_address.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/00400000_address.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/04000000_address.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/3ffff000_address.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40000000_address.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/40400000_address.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/44000000_address.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mwr -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_patterns/7ffff000_address.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_address_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_address_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_address_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_address_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_address_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_address_0.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_address_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_address_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_address_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_address_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_address_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_address_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_address_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_address_1.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_address_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_address_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00000000_address_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40000000_address_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/00400000_address_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/40400000_address_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/04000000_address_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/44000000_address_2.bin} 0x44000000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/3ffff000_address_2.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/rank_reads/7ffff000_address_2.bin} 0x7ffff000 1024
puts "RANK_TEST address saved 24 reads"
} message options]
mwr -force -address-space AP0 0x83000000 0
puts "bank restored [mrd -force -address-space AP0 0x83000000 1]"
configparams force-mem-access 0
disconnect
if {$result} {return -options $options $message}
puts RANK_PATTERNS_DONE
exit
