set out [file dirname [file normalize [info script]]]
set root /home/yyz/work/RIS/zynq/z035
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set dev [get_hw_devices -filter {PART == xc7z035}]
if {[llength $dev] != 1} {error "Expected one xc7z035"}
current_hw_device $dev
set_property PROBES.FILE $root/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
set_property FULL_PROBES.FILE $root/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
refresh_hw_device $dev
set core [get_hw_ilas -of_objects $dev -filter {CELL_NAME == ila_ad9361_rx}]
if {[llength $core] != 1} {error "Expected matching ila_ad9361_rx"}
set props [open $out/ila/core_properties.txt w]
report_property -all -file $out/ila/core_properties.rpt $core
foreach p [list_property $core] {puts $props "$p=[get_property $p $core]"}
close $props
set_property CONTROL.DATA_DEPTH [get_property STATIC.MAX_DATA_DEPTH $core] $core
set_property CONTROL.TRIGGER_POSITION 0 $core
set times [open $out/ila/capture_times.csv w]
puts $times "capture,host_start_ms,host_end_ms"
for {set n 0} {$n < 60} {incr n} {
    set started [clock milliseconds]
    run_hw_ila -trigger_now $core
    wait_on_hw_ila -timeout 0.1 $core
    set data [upload_hw_ila_data $core]
    set stem [format "%s/ila/baseline_%03d" $out $n]
    write_hw_ila_data -force -csv_file $stem.csv $data
    if {$n == 0 || $n == 59} {write_hw_ila_data -force $stem.ila $data}
    puts $times "$n,$started,[clock milliseconds]"
    flush $times
    puts "BASELINE_CAPTURE $n [clock format [clock seconds]]"
    after 1000
}
close $times
puts LONG_CAPTURE_COMPLETE
close_hw_manager
exit
