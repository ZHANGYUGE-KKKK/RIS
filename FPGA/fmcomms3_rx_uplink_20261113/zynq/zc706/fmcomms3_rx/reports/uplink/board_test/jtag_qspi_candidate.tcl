set root /home/wenhan/PROJECTS/RIS/FPGA/fmcomms3_rx_uplink_20261113/zynq/zc706/fmcomms3_rx
set out /home/wenhan/PROJECTS/RIS/FPGA/fmcomms3_rx_uplink_20261113/qspi/boot
set cable 210299995170
set apu [format {name == "APU" && jtag_cable_serial == "%s"} $cable]
set fpga [format {name =~ "xc7z045*" && jtag_cable_serial == "%s"} $cable]
set cpu [format {name =~ "*A9*#0" && jtag_cable_serial == "%s"} $cable]
connect -url tcp:127.0.0.1:3121
for {set attempt 0} {$attempt < 30} {incr attempt} {
    if {[llength [targets -target-properties -filter $cpu]] == 1} {break}
    after 350
}
foreach filter [list $apu $fpga $cpu] {
    if {[llength [targets -target-properties -filter $filter]] != 1} {
        puts [targets -target-properties]
        error "Expected a single receiver target matching $filter"
    }
}
targets -set -filter $cpu
set mode [mrd -value 0xf800025c]
puts "RX_CABLE $cable BOOT_MODE $mode"
if {([expr {$mode}] & 15) != 0} {error "Receiver must be in JTAG boot mode"}
targets -set -filter $apu
rst -system
after 1000
targets -set -filter $fpga
fpga -file $out/zc706_rx_uplink.bit
targets -set -filter $apu
loadhw -hw $out/zc706_rx_uplink.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
source $out/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -filter $cpu
dow $out/zc706_rx_uplink.elf
configparams force-mem-access 0
con
puts RX_JTAG_APP_RUNNING
disconnect
exit
