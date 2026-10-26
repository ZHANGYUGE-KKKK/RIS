# Read MIG calibration and optionally capture the receiver's coherent probes.
# Usage: vivado -mode batch -source this.tcl -tclargs REPORT [capture]
set board_root [file normalize [file join [file dirname [info script]] ..]]
set report [file normalize [lindex $argv 0]]
file mkdir $report
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set device [get_hw_devices -filter {PART == xc7z035}]
if {[llength $device] != 1} {error "Expected exactly one xc7z035"}
current_hw_device $device
if {[lindex $argv 1] eq "capture"} {
    set_property PROBES.FILE $board_root/PZ_UART.runs/impl_1/pz7035_top.ltx $device
    set_property FULL_PROBES.FILE $board_root/PZ_UART.runs/impl_1/pz7035_top.ltx $device
}
refresh_hw_device $device
set fd [open $report/mig_calibration.txt w]
foreach mig [get_hw_migs -of_objects $device] {
    refresh_hw_mig $mig
    puts $fd "MIG=$mig"
    foreach prop [list_property $mig] {puts $fd "$prop=[get_property $prop $mig]"}
}
close $fd
if {[lindex $argv 1] eq "capture"} {
    set ila [get_hw_ilas -of_objects $device -filter {CELL_NAME == ila_ad9361_rx}]
    if {[llength $ila] != 1} {error "Receiver ILA missing"}
    foreach probe [get_hw_probes -of_objects $ila] {set_property DISPLAY_RADIX HEX $probe}
    for {set n 0} {$n < 3} {incr n} {
        run_hw_ila -trigger_now $ila
        wait_on_hw_ila $ila
        set data [upload_hw_ila_data $ila]
        write_hw_ila_data -force -csv_file $report/rx_$n.csv $data
        write_hw_ila_data -force $report/rx_$n.ila $data
    }
}
close_hw_target
disconnect_hw_server
close_hw_manager
puts RX_HARDWARE_INSPECTION_COMPLETE
exit
