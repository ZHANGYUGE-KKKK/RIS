# Run in the current Vivado GUI AFTER Vitis downloads matching BIT and ELF.
# Receiver probes observe live AXIS words/status in the 100 MHz AXIS domain.
# Tuple and clock counters are independent synchronized diagnostics.
set adi_root [file normalize [file join [file dirname [info script]] ..]]
set adi_out $adi_root/reports/ad9361_official_port/ila
file mkdir $adi_out
if {[catch {
    open_hw_manager
    if {![llength [get_hw_servers -quiet]]} {connect_hw_server -url localhost:3121}
    if {![llength [get_hw_devices -quiet -filter {PART == xc7z035}]]} {open_hw_target}
    set adi_dev [get_hw_devices -filter {PART == xc7z035}]
    if {[llength $adi_dev] != 1} {error "Expected one xc7z035"}
    current_hw_device $adi_dev
    set_property PROGRAM.FILE $adi_root/PZ_UART.runs/impl_1/pz7035_top.bit $adi_dev
    set_property PROBES.FILE $adi_root/PZ_UART.runs/impl_1/pz7035_top.ltx $adi_dev
    set_property FULL_PROBES.FILE $adi_root/PZ_UART.runs/impl_1/pz7035_top.ltx $adi_dev
    refresh_hw_device $adi_dev
    set adi_ila [get_hw_ilas -of_objects $adi_dev -filter {CELL_NAME == ila_ad9361_rx}]
    if {[llength $adi_ila] != 1} {error "Expected ila_ad9361_rx; check matching BIT/LTX"}
    set adi_fd [open $adi_out/core_properties.txt w]
    foreach adi_prop [list_property $adi_ila] {puts $adi_fd "$adi_prop=[get_property $adi_prop $adi_ila]"}
    close $adi_fd
    # Match the five probes of the rewritten receiver; fail early with stale
    # BIT/LTX files rather than presenting an unrelated waveform layout.
    set adi_seen_probes {}
    foreach adi_probe [get_hw_probes -of_objects $adi_ila] {
        set adi_probe_name [file tail [get_property NAME $adi_probe]]
        switch -- $adi_probe_name {
            debug_axis_data - debug_raw_rx {
                set_property DISPLAY_RADIX HEX $adi_probe
                lappend adi_seen_probes $adi_probe_name
            }
            debug_axis_flags {
                set_property DISPLAY_RADIX BINARY $adi_probe
                lappend adi_seen_probes $adi_probe_name
            }
            debug_sample_count - debug_clock_count {
                set_property DISPLAY_RADIX UNSIGNED $adi_probe
                lappend adi_seen_probes $adi_probe_name
            }
        }
    }
    if {[lsort -unique $adi_seen_probes] ne [lsort {
            debug_axis_data debug_axis_flags debug_sample_count debug_clock_count debug_raw_rx}]} {
        error "Receiver ILA probes do not match the rewritten AXIS receiver; load matching BIT/LTX"
    }
    for {set adi_n 0} {$adi_n < 3} {incr adi_n} {
        run_hw_ila -trigger_now $adi_ila
        wait_on_hw_ila $adi_ila
        set adi_data [upload_hw_ila_data $adi_ila]
        write_hw_ila_data -force -csv_file $adi_out/rx_$adi_n.csv $adi_data
        write_hw_ila_data -force $adi_out/rx_$adi_n.ila $adi_data
        catch {display_hw_ila_data $adi_data}
    }
    source $adi_root/scripts/configure_ad9361_rx_view.tcl
    set adi_fd [open $adi_out/capture_status.txt w]
    puts $adi_fd "PASS [clock format [clock seconds]]; 3 captures; 100 MHz AXIS ILA"
    close $adi_fd
    puts AD9361_RX_CAPTURE_PASS
} adi_error adi_options]} {
    set adi_fd [open $adi_out/capture_status.txt w]
    puts $adi_fd "FAIL [clock format [clock seconds]] $adi_error\n[dict get $adi_options -errorinfo]"
    close $adi_fd
    error $adi_error
}
