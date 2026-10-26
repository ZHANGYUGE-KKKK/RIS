# Standalone synthesis/CDC check. Does not open or modify PZ_UART.xpr.
# Run Vivado from a temporary directory; reports are written to that cwd.
set ris_project_dir [file normalize [file join [file dirname [info script]] ..]]
create_project -in_memory -part xc7z035ffg900-2
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
read_verilog [file join $ris_project_dir PZ_UART.srcs sources_1 new rfmc6000_iq_axis.v]
synth_design -top rfmc6000_iq_axis -part xc7z035ffg900-2
create_clock -period 4.069 -name rf_rx [get_ports rx_clk_p]
create_clock -period 5.000 -name ref200 [get_ports ref_clk200]
create_clock -period 10.000 -name axis100 [get_ports m_axis_aclk]
read_xdc [file join $ris_project_dir PZ_UART.srcs constrs_1 new rfmc6000_iq_axis_cdc.xdc]
# The in-memory flow creates clocks after synthesis. Refresh the two XPM Gray
# pointer bounds with real clock periods; early XPM loading can use defaults.
foreach ris_direction {wr rd} {
    set ris_gray "i_cdc_fifo/xpm_fifo_base_inst/gen_cdc_pntr.${ris_direction}_pntr_cdc_inst"
    set ris_src [get_cells "$ris_gray/src_gray_ff_reg*"]
    set ris_dst [get_cells -hier -regexp [format {%s/dest_graysync_ff_reg\[0\].*} $ris_gray]]
    set ris_src_period [get_property -min PERIOD [get_clocks -of_objects \
        [get_pins -of_objects $ris_src -filter {REF_PIN_NAME == C}]]]
    set ris_dst_period [get_property -min PERIOD [get_clocks -of_objects \
        [get_pins -of_objects $ris_dst -filter {REF_PIN_NAME == C}]]]
    set_max_delay -datapath_only -from $ris_src -to $ris_dst $ris_src_period
    set_bus_skew -from $ris_src -to $ris_dst [expr {min($ris_src_period, $ris_dst_period)}]
}
report_utilization -file utilization.rpt
report_cdc -details -file cdc.rpt
report_timing_summary -file timing_synth.rpt
report_bus_skew -file bus_skew_synth.rpt
write_checkpoint -force iq_axis_synth.dcp
puts "RFMC6000_IQ_AXIS_SYNTH_PASS"
if {[llength $argv] && [lindex $argv 0] eq "route"} {
    # Only the LVDS input LOCs represent the real board. AXIS/status/clock
    # ports get artificial standalone placement. No bitstream is generated.
    set_property IOSTANDARD LVCMOS18 [get_ports *]
    foreach {ris_port ris_ball} {
        rx_clk_p AB27 rx_clk_n AC27 rx_frame_p T30 rx_frame_n U30
        rx_data_p[0] W29 rx_data_n[0] W30 rx_data_p[1] U24 rx_data_n[1] V24
        rx_data_p[2] T24 rx_data_n[2] T25 rx_data_p[3] N28 rx_data_n[3] P28
        rx_data_p[4] U22 rx_data_n[4] V22 rx_data_p[5] P21 rx_data_n[5] R21
    } {
        set_property -dict [list PACKAGE_PIN $ris_ball IOSTANDARD LVDS_25 \
                                DIFF_TERM false] [get_ports $ris_port]
    }
    opt_design
    place_design
    phys_opt_design
    route_design
    report_drc -file route_drc.rpt
    report_timing_summary -file timing_route.rpt
    report_bus_skew -file bus_skew_route.rpt
    write_checkpoint -force iq_axis_route.dcp
    puts "RFMC6000_IQ_AXIS_ROUTE_COMPLETE"
}
exit
