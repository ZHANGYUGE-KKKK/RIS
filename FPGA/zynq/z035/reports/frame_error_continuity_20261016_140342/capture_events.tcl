set out [file dirname [file normalize [info script]]]
set root /home/yyz/work/RIS/zynq/z035
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set dev [get_hw_devices -filter {PART == xc7z035}]
current_hw_device $dev
set_property PROBES.FILE $root/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
set_property FULL_PROBES.FILE $root/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
refresh_hw_device $dev
set core [get_hw_ilas -of_objects $dev -filter {CELL_NAME == ila_ad9361_rx}]
set_property CONTROL.TRIGGER_POSITION 1024 $core
set_property CONTROL.TRIGGER_CONDITION AND $core
foreach p [get_hw_probes -of_objects $core] {
    set width [get_property WIDTH $p]
    set_property TRIGGER_COMPARE_VALUE "eq${width}'b[string repeat X $width]" $p
}
set valid [get_hw_probes -of_objects $core -filter {NAME =~ *prefifo_valid_ref}]
set fault [get_hw_probes -of_objects $core -filter {NAME =~ *prefifo_frame_error_rx_ref}]
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $valid
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $fault
for {set n 0} {$n < 6} {incr n} {
    set deadline [expr {[clock seconds]+90}]
    while {![file exists $out/ready_$n]} {
        if {[clock seconds]>$deadline} {error "No ARM diagnostic ready for trial $n"}
        after 100
    }
    run_hw_ila $core
    close [open $out/armed_$n w]
    set wait_error [catch {wait_on_hw_ila -timeout 0.1 $core} msg]
    # Timeout can return without Tcl error; never upload the preceding capture.
    if {$wait_error || [get_property STATUS.CORE_STATUS $core] ne "FULL"} {
        puts "EVENT_TRIGGER_TIMEOUT $n $msg"
        catch {stop_hw_ila $core}
        close [open $out/captured_$n w]
        continue
    }
    set data [upload_hw_ila_data $core]
    set stem [format "%s/ila/event_%02d" $out $n]
    write_hw_ila_data -force -csv_file $stem.csv $data
    write_hw_ila_data -force $stem.ila $data
    close [open $out/captured_$n w]
    puts "EVENT_CAPTURED $n [clock format [clock seconds]]"
}
foreach p [get_hw_probes -of_objects $core] {
    set width [get_property WIDTH $p]
    set_property TRIGGER_COMPARE_VALUE "eq${width}'b[string repeat X $width]" $p
}
puts EVENT_CAPTURE_COMPLETE
close_hw_manager
exit
