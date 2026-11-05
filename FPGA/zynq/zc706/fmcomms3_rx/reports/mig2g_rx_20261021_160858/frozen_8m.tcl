connect -url tcp:127.0.0.1:3121
targets -set -filter {name == "APU"}
configparams force-mem-access 1
puts "DMA frozen regs [mrd -force -address-space AP0 0x81000030 12]"
set result [catch {
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40400000_0.bin} 0x40400000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40400000_1.bin} 0x40400000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40400000_2.bin} 0x40400000 1024
after 50
puts "FROZEN 40400000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40407000_0.bin} 0x40407000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40407000_1.bin} 0x40407000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40407000_2.bin} 0x40407000 1024
after 50
puts "FROZEN 40407000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40408000_0.bin} 0x40408000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40408000_1.bin} 0x40408000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40408000_2.bin} 0x40408000 1024
after 50
puts "FROZEN 40408000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40480000_0.bin} 0x40480000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40480000_1.bin} 0x40480000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40480000_2.bin} 0x40480000 1024
after 50
puts "FROZEN 40480000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/404a5000_0.bin} 0x404a5000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/404a5000_1.bin} 0x404a5000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/404a5000_2.bin} 0x404a5000 1024
after 50
puts "FROZEN 404a5000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/404e4000_0.bin} 0x404e4000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/404e4000_1.bin} 0x404e4000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/404e4000_2.bin} 0x404e4000 1024
after 50
puts "FROZEN 404e4000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40500000_0.bin} 0x40500000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40500000_1.bin} 0x40500000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40500000_2.bin} 0x40500000 1024
after 50
puts "FROZEN 40500000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40564000_0.bin} 0x40564000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40564000_1.bin} 0x40564000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40564000_2.bin} 0x40564000 1024
after 50
puts "FROZEN 40564000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40580000_0.bin} 0x40580000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40580000_1.bin} 0x40580000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40580000_2.bin} 0x40580000 1024
after 50
puts "FROZEN 40580000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40600000_0.bin} 0x40600000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40600000_1.bin} 0x40600000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40600000_2.bin} 0x40600000 1024
after 50
puts "FROZEN 40600000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40700000_0.bin} 0x40700000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40700000_1.bin} 0x40700000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40700000_2.bin} 0x40700000 1024
after 50
puts "FROZEN 40700000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40800000_0.bin} 0x40800000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40800000_1.bin} 0x40800000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40800000_2.bin} 0x40800000 1024
after 50
puts "FROZEN 40800000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40a00000_0.bin} 0x40a00000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40a00000_1.bin} 0x40a00000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40a00000_2.bin} 0x40a00000 1024
after 50
puts "FROZEN 40a00000 saved3reads"
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40bff000_0.bin} 0x40bff000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40bff000_1.bin} 0x40bff000 1024
after 50
mrd -force -address-space AP0 -bin -file {/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/mig2g_rx_20261021_160858/frozen_8m/40bff000_2.bin} 0x40bff000 1024
after 50
puts "FROZEN 40bff000 saved3reads"
} message options]
configparams force-mem-access 0
disconnect
if {$result} {return -options $options $message}
exit
