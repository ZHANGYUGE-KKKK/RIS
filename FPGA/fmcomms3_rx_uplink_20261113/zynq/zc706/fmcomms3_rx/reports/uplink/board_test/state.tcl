set root /home/wenhan/PROJECTS/RIS/FPGA/fmcomms3_rx_uplink_20261113/zynq/zc706/fmcomms3_rx
set out $root/reports/uplink
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
puts "RX_CPU_STATE [state]"
if {![catch {rrd pc} line]} {puts $line; con}
disconnect
exit
