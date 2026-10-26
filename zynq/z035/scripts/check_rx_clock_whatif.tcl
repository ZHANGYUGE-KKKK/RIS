# Read-only routed-DCP clock audit; no source/project/artifact modifications.
set rx_audit_root [file normalize [file join [file dirname [info script]] ..]]
set rx_audit_out $rx_audit_root/reports/rx_axis_board_20261016/clock_whatif_245m
file mkdir $rx_audit_out
open_checkpoint $rx_audit_root/reports/rx_axis_board_20261016/pz7035_top_routed.dcp
set rx_hier u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst
report_clocks -file $rx_audit_out/clocks_original.rpt
report_timing -from [get_clocks rfmc_rx] -to [get_clocks rfmc_rx] -max_paths 30 -path_type full_clock_expanded -file $rx_audit_out/rx_timing_original.rpt
set rx_audit_fd [open $rx_audit_out/physical_clock_path.txt w]
foreach rx_port {rx_clk_p rx_clk_n rx_frame_p rx_frame_n} {
    set rx_obj [get_ports $rx_port]
    puts $rx_audit_fd "PORT $rx_port PACKAGE_PIN=[get_property PACKAGE_PIN $rx_obj] IOSTANDARD=[get_property IOSTANDARD $rx_obj]"
    puts $rx_audit_fd "NETS [get_nets -segments -of_objects $rx_obj]"
    puts $rx_audit_fd "PINS [get_pins -of_objects [get_nets -segments -of_objects $rx_obj]]"
}
foreach rx_cell [get_cells -hier -filter "NAME =~ $rx_hier/* && (REF_NAME == BUFG || REF_NAME == IBUFDS || REF_NAME == IDDR)"] {
    puts $rx_audit_fd "CELL $rx_cell REF=[get_property REF_NAME $rx_cell] LOC=[get_property LOC $rx_cell] BEL=[get_property BEL $rx_cell]"
    foreach rx_pin [get_pins -of_objects $rx_cell] {
        puts $rx_audit_fd "  PIN $rx_pin NET=[get_nets -of_objects $rx_pin] CLOCK=[get_clocks -quiet -of_objects $rx_pin]"
    }
}
close $rx_audit_fd
create_clock -name rfmc_rx -period 4.069010 [get_ports rx_clk_p]
report_clocks -file $rx_audit_out/clocks_245m.rpt
report_timing_summary -max_paths 50 -file $rx_audit_out/timing_245m.rpt
report_timing -from [get_clocks rfmc_rx] -to [get_clocks rfmc_rx] -max_paths 50 -path_type full_clock_expanded -file $rx_audit_out/rx_timing_245m.rpt
report_timing -from [get_clocks rfmc_rx] -to [get_clocks rfmc_rx] -delay_type min -max_paths 20 -path_type full_clock_expanded -file $rx_audit_out/rx_hold_245m.rpt
set rx_data_starts [get_cells -hier -filter "IS_SEQUENTIAL && NAME =~ $rx_hier/* && NAME !~ $rx_hier/u_rx_reset/*"]
report_timing -from $rx_data_starts -to [get_clocks rfmc_rx] -max_paths 50 -path_type full_clock_expanded -file $rx_audit_out/rx_dynamic_245m.rpt
report_timing -from [get_cells -hier -filter "NAME =~ $rx_hier/edge_counter_rx_reg*"] -to [get_clocks rfmc_rx] -max_paths 24 -path_type full_clock_expanded -file $rx_audit_out/clock_counter_245m.rpt
set rx_vendor_count_cells [get_cells -hier -filter "NAME =~ $rx_hier/u_registers_pn/i_up_adc_common/i_clock_mon/d_count_reg*"]
puts "VENDOR_CLOCK_COUNTER_CELLS=$rx_vendor_count_cells"
report_timing -from $rx_vendor_count_cells -to [get_clocks rfmc_rx] -max_paths 40 -path_type full_clock_expanded -file $rx_audit_out/vendor_clock_counter_245m.rpt
set rx_audit_fd [open $rx_audit_out/violating_paths_245m.tsv w]
puts $rx_audit_fd "SLACK\tDATAPATH_DELAY\tSTARTPOINT\tENDPOINT"
foreach rx_path [get_timing_paths -group rfmc_rx -slack_lesser_than 0 -max_paths 1000] {
    puts $rx_audit_fd "[get_property SLACK $rx_path]\t[get_property DATAPATH_DELAY $rx_path]\t[get_property STARTPOINT_PIN $rx_path]\t[get_property ENDPOINT_PIN $rx_path]"
}
close $rx_audit_fd
report_bus_skew -file $rx_audit_out/bus_skew_245m.rpt
report_clock_interaction -file $rx_audit_out/clock_interaction_245m.rpt
puts "RX_CLOCK_WHATIF_COMPLETE=$rx_audit_out"
close_design
