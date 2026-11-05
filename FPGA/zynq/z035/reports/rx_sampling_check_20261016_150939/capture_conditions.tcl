set out [file dirname [file normalize [info script]]]
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set dev [get_hw_devices -filter {PART == xc7z035}]
current_hw_device $dev
set_property PROBES.FILE /home/yyz/work/RIS/zynq/z035/PZ_UART.runs/impl_1/pz7035_top.ltx $dev
refresh_hw_device $dev
set core [get_hw_ilas -of_objects $dev -filter {CELL_NAME == ila_ad9361_rx}]
set_property CONTROL.TRIGGER_POSITION 0 $core
foreach probe [get_hw_probes -of_objects $core] {
    set width [get_property WIDTH $probe]
    set_property TRIGGER_COMPARE_VALUE "eq${width}'b[string repeat X $width]" $probe
}
for {set condition 0} {$condition<7} {incr condition} {
    set deadline [expr {[clock seconds]+180}]
    while {![file exists $out/ready_$condition]} {
        if {[clock seconds]>$deadline} {error "No ready condition $condition"}
        after 100
    }
    set fd [open $out/ready_$condition r];set label [string trim [read $fd]];close $fd
    for {set n 0} {$n<3} {incr n} {
        run_hw_ila -trigger_now $core
        wait_on_hw_ila -timeout 0.1 $core
        if {[get_property STATUS.CORE_STATUS $core] ne "FULL"} {error "No fresh full capture"}
        set data [upload_hw_ila_data $core]
        set stem [format "%s/ila/condition_%02d_%s_%d" $out $condition $label $n]
        write_hw_ila_data -force -csv_file $stem.csv $data
        if {$n==0} {write_hw_ila_data -force $stem.ila $data}
    }
    close [open $out/captured_$condition w]
    puts "SAMPLING_ILA_CONDITION $condition $label [clock format [clock seconds]]"
}
set_property CONTROL.TRIGGER_POSITION 1024 $core
puts SAMPLING_ILA_COMPLETE
close_hw_manager
exit
