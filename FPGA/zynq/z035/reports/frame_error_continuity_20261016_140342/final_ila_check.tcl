set out [file dirname [file normalize [info script]]]
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set dev [get_hw_devices -filter {PART == xc7z035}]
current_hw_device $dev
set_property PROBES.FILE /home/yyz/work/RIS/zynq/z035/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
refresh_hw_device $dev
set core [get_hw_ilas -of_objects $dev -filter {CELL_NAME == ila_ad9361_rx}]
foreach p [get_hw_probes -of_objects $core] {
    set width [get_property WIDTH $p]
    set_property TRIGGER_COMPARE_VALUE "eq${width}'b[string repeat X $width]" $p
}
set_property CONTROL.TRIGGER_POSITION 1024 $core
run_hw_ila -trigger_now $core
wait_on_hw_ila -timeout 0.1 $core
puts "FINAL_ILA_STATUS=[get_property STATUS.CORE_STATUS $core]"
puts "FINAL_ILA_SAMPLES=[get_property STATUS.SAMPLE_COUNT $core]"
set data [upload_hw_ila_data $core]
write_hw_ila_data -force -csv_file $out/ila/restored.csv $data
write_hw_ila_data -force $out/ila/restored.ila $data
close_hw_manager
exit
