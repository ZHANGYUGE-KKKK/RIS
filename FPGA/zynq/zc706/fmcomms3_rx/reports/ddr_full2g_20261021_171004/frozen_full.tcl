connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
set result [catch {
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00400000_0.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00407000_0.bin} 0x40407000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00408000_0.bin} 0x40408000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00480000_0.bin} 0x40480000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/004a5000_0.bin} 0x404a5000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/004e4000_0.bin} 0x404e4000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00500000_0.bin} 0x40500000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00564000_0.bin} 0x40564000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00580000_0.bin} 0x40580000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00600000_0.bin} 0x40600000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00700000_0.bin} 0x40700000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/01184000_0.bin} 0x41184000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/025c4000_0.bin} 0x425c4000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/20300000_0.bin} 0x60300000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/3ffff000_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/40000000_0.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/40200000_0.bin} 0x40200000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/60100000_0.bin} 0x60100000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/7ffff000_0.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00400000_1.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00407000_1.bin} 0x40407000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00408000_1.bin} 0x40408000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00480000_1.bin} 0x40480000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/004a5000_1.bin} 0x404a5000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/004e4000_1.bin} 0x404e4000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00500000_1.bin} 0x40500000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00564000_1.bin} 0x40564000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00580000_1.bin} 0x40580000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00600000_1.bin} 0x40600000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00700000_1.bin} 0x40700000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/01184000_1.bin} 0x41184000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/025c4000_1.bin} 0x425c4000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/20300000_1.bin} 0x60300000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/3ffff000_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/40000000_1.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/40200000_1.bin} 0x40200000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/60100000_1.bin} 0x60100000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/7ffff000_1.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00400000_2.bin} 0x40400000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00407000_2.bin} 0x40407000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00408000_2.bin} 0x40408000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00480000_2.bin} 0x40480000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/004a5000_2.bin} 0x404a5000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/004e4000_2.bin} 0x404e4000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00500000_2.bin} 0x40500000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00564000_2.bin} 0x40564000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00580000_2.bin} 0x40580000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00600000_2.bin} 0x40600000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/00700000_2.bin} 0x40700000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/01184000_2.bin} 0x41184000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/025c4000_2.bin} 0x425c4000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/20300000_2.bin} 0x60300000 1024
mwr -force -address-space AP0 0x83000000 0
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/3ffff000_2.bin} 0x7ffff000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/40000000_2.bin} 0x40000000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/40200000_2.bin} 0x40200000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/60100000_2.bin} 0x60100000 1024
mwr -force -address-space AP0 0x83000000 1
after 1
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/frozen_full/7ffff000_2.bin} 0x7ffff000 1024
} message options]
mwr -force -address-space AP0 0x83000000 0
puts "CPU bank restored [mrd -force -address-space AP0 0x83000000 1]"
configparams force-mem-access 0
disconnect
if {$result} {return -options $options $message}
exit
