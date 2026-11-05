# Run with Vivado 2020.2: vivado -mode gui -source scripts/build_fmcomms3.tcl
set fm_root [file normalize [file join [file dirname [info script]] ..]]
set fm_status [file join $fm_root reports fmcomms3 build_status.txt]
file mkdir [file dirname $fm_status]
set fm_fd [open $fm_status w]
puts $fm_fd "START [clock format [clock seconds]]"
close $fm_fd
if {[catch {
    if {[current_project -quiet] eq ""} {open_project $fm_root/PZ_UART.xpr}
    if {[file normalize [get_property DIRECTORY [current_project]]] ne $fm_root} {error "Unexpected active project"}
    catch {close_design}
    set fm_xdc $fm_root/PZ_UART.srcs/constrs_1/new/fmcomms3_io.xdc
    if {[llength [get_files -quiet $fm_xdc]] == 0} {add_files -fileset constrs_1 -norecurse $fm_xdc}
    set_property USED_IN_SYNTHESIS true [get_files $fm_xdc]
    set_property USED_IN_IMPLEMENTATION true [get_files $fm_xdc]
    open_bd_design [get_files */design_1.bd]
    update_module_reference [get_ips design_1_rfmc6000_iq_axis_0_0]
    # Match reference main.c: seven lanes at 12 taps, delayed falling edge.
    set_property -dict [list CONFIG.FALLING_EDGE_DELAY 1 CONFIG.INPUT_DELAY_TAPS 0x318C6318C] [get_bd_cells rfmc6000_iq_axis_0]
    # A disconnected wrapper IOBUF still requires a package pin. Remove only
    # the obsolete board interface and keep the PS SPI1 controller enabled.
    set fm_spi1_port [get_bd_intf_ports -quiet SPI_6208]
    if {[llength $fm_spi1_port]} {
        delete_bd_objs [get_bd_intf_nets -of_objects $fm_spi1_port]
        delete_bd_objs $fm_spi1_port
        connect_bd_net [get_bd_pins reset_const_zero/dout] \
            [get_bd_pins processing_system7_0/SPI1_MOSI_I] \
            [get_bd_pins processing_system7_0/SPI1_MISO_I] \
            [get_bd_pins processing_system7_0/SPI1_SCLK_I]
        connect_bd_net [get_bd_pins reset_const_one/dout] \
            [get_bd_pins processing_system7_0/SPI1_SS_I]
    }
    validate_bd_design
    save_bd_design
    generate_target all [get_files */design_1.bd]
    make_wrapper -files [get_files */design_1.bd] -top -force
    source $fm_root/scripts/rebuild_export_current.tcl
    foreach {fm_port fm_ball} {
        SPI_9361_io0_io AF30 SPI_9361_io1_io AG30
        SPI_9361_sck_io AK30 SPI_9361_ss_io AJ30
        GPIO_PS_tri_io[0] AC29
        rf_enable P25 rf_txnrx P26 rf_en_agc T22 rf_sync_in T23
        rx_clk_p R27 rx_clk_n T27 rx_frame_p R25 rx_frame_n R26
        rx_data_p[0] P21 rx_data_n[0] R21
        rx_data_p[1] N28 rx_data_n[1] P28
        rx_data_p[2] T24 rx_data_n[2] T25
        rx_data_p[3] U22 rx_data_n[3] V22
        rx_data_p[4] T30 rx_data_n[4] U30
        rx_data_p[5] N29 rx_data_n[5] P29
    } {
        set fm_obj [get_ports $fm_port]
        if {[llength $fm_obj] != 1 || [get_property PACKAGE_PIN $fm_obj] ne $fm_ball} {error "Pin mismatch: $fm_port -> $fm_ball"}
        if {[get_property IOSTANDARD $fm_obj] eq "DEFAULT"} {error "Missing IOSTANDARD on $fm_port"}
    }
    if {[llength [get_ports -quiet {SPI_6208_* cdcm_sync}]] != 0} {error "Legacy CDCM6208 pins still exposed"}
    set fm_ila_clk [get_clocks -of_objects [get_pins ila_rx_frame/clk]]
    if {[llength $fm_ila_clk] != 1 || abs([get_property PERIOD $fm_ila_clk]-5.0)>0.001} {error "Diagnostic ILA must use 200 MHz"}
    report_io -file $ris_reports/io.rpt
    write_debug_probes -force $fm_root/PZ_UART.runs/impl_1/pz7035_top.ltx
    set fm_fd [open $fm_status a]
    puts $fm_fd "PASS [clock format [clock seconds]]"
    puts $fm_fd "REPORTS=$ris_reports"
    puts $fm_fd "XSA=$ris_xsa"
    puts $fm_fd "PIN_MAP=PASS; ILA_CLOCK_PERIOD_NS=5.000"
    close $fm_fd
    puts FMCOMMS3_BUILD_PASS
} fm_error fm_options]} {
    set fm_fd [open $fm_status a]
    puts $fm_fd "FAIL $fm_error"
    puts $fm_fd [dict get $fm_options -errorinfo]
    close $fm_fd
    error $fm_error
}
