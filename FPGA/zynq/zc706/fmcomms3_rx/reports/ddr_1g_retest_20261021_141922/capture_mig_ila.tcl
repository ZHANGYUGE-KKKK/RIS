set here [file dirname [file normalize [info script]]]
set root [file normalize [file join $here ../..]]
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set dev [get_hw_devices -filter {PART == "xc7z045"}]
if {[llength $dev] != 1} {error "Expected one XC7Z045"}
set_property PROBES.FILE $root/export/zc706_top.ltx $dev
refresh_hw_device $dev
set ila [get_hw_ilas -of_objects $dev -filter {CELL_NAME =~ *ila_ddr*}]
puts "DDR_ILA=$ila"
if {[llength $ila] != 1} {error "Expected exactly one DDR ILA"}
report_property $ila
set_property CONTROL.TRIGGER_POSITION 0 $ila
run_hw_ila $ila -trigger_now
wait_on_hw_ila -timeout 10 $ila
set data [upload_hw_ila_data $ila]
write_hw_ila_data -force -csv_file $here/mig_state.csv $data
close_hw_manager
exit
