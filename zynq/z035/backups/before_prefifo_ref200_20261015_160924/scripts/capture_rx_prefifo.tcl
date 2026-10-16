# Run after programming matching BIT/LTX and initializing the AD9361.
# Keeps the captures visible in the existing Vivado GUI.
set root /home/yyz/work/RIS/zynq/z035
set out $root/reports/prefifo_ila
open_hw_manager
if {[llength [get_hw_servers -quiet]] == 0} {connect_hw_server -url localhost:3121}
if {[llength [get_hw_devices -quiet -filter {PART == xc7z035}]] == 0} {open_hw_target}
set dev [get_hw_devices -filter {PART == xc7z035}]
current_hw_device $dev
set_property PROGRAM.FILE $root/PZ_UART.runs/impl_1/pz7035_top.bit $dev
set_property PROBES.FILE $root/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
set_property FULL_PROBES.FILE $root/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
refresh_hw_device $dev
set core [get_hw_ilas -of_objects $dev -filter {CELL_NAME == ila_rx_prefifo}]
if {[llength $core] != 1} {error "Expected one RX pre-FIFO ILA"}
set propfile [open $out/core_properties.txt w]
foreach prop [list_property $core] {puts $propfile "$prop=[get_property $prop $core]"}
close $propfile
foreach p [get_hw_probes -of_objects $core] {puts "RX_PROBE [get_property NAME $p]"}
for {set n 0} {$n < 3} {incr n} {
    if {[catch {
        run_hw_ila -trigger_now $core
        wait_on_hw_ila $core
        set data [upload_hw_ila_data $core]
        write_hw_ila_data -force -csv_file $out/prefifo_$n.csv $data
        write_hw_ila_data -force $out/prefifo_$n.ila $data
        catch {display_hw_ila_data $data}
    } capture_error]} {
        set statusfile [open $out/live_capture_status.txt w]
        puts $statusfile "FAIL [clock format [clock seconds]] $capture_error"
        close $statusfile
        puts "PREFIFO_LIVE_CAPTURE_FAILED: $capture_error"
        break
    }
}
set ref [get_hw_ilas -of_objects $dev -filter {CELL_NAME == ila_rx_frame}]
run_hw_ila -trigger_now $ref
wait_on_hw_ila $ref
set refdata [upload_hw_ila_data $ref]
write_hw_ila_data -force -csv_file $out/ref200.csv $refdata
write_hw_ila_data -force $out/ref200.ila $refdata
catch {display_hw_ila_data $refdata}
puts PREFIFO_CAPTURE_ATTEMPT_COMPLETE
