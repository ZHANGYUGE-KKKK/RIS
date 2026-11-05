# All diagnostic probes belong to ref_clk200 (MIG ui_clk, 200 MHz).
# RX snapshot uses XPM handshake CDC; RX edge count uses XPM Gray CDC.
create_debug_core ila_rx_frame ila
set_property -dict {C_DATA_DEPTH 2048 C_INPUT_PIPE_STAGES 2 C_ADV_TRIGGER false C_EN_STRG_QUAL false} [get_debug_cores ila_rx_frame]
set_property port_width 1 [get_debug_ports ila_rx_frame/clk]
connect_debug_port ila_rx_frame/clk [get_nets -of_objects [get_pins {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/ref_clk200}]]

# probe0: diag_snapshot_valid_ref
set_property port_width 1 [get_debug_ports ila_rx_frame/probe0]
connect_debug_port ila_rx_frame/probe0 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_snapshot_valid_ref
}]

# probe1: diag_snapshot_pulse_ref
create_debug_port ila_rx_frame probe
set_property port_width 1 [get_debug_ports ila_rx_frame/probe1]
connect_debug_port ila_rx_frame/probe1 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_snapshot_pulse_ref
}]

# probe2: rx_clock_active_ref
create_debug_port ila_rx_frame probe
set_property port_width 1 [get_debug_ports ila_rx_frame/probe2]
connect_debug_port ila_rx_frame/probe2 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_clock_active_ref
}]

# probe3: rx_edges_per_ms_ref
create_debug_port ila_rx_frame probe
set_property port_width 24 [get_debug_ports ila_rx_frame/probe3]
connect_debug_port ila_rx_frame/probe3 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_edges_per_ms_ref[23]
}]

# probe4: rx_counter_ref
create_debug_port ila_rx_frame probe
set_property port_width 24 [get_debug_ports ila_rx_frame/probe4]
connect_debug_port ila_rx_frame/probe4 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_counter_ref[23]
}]

# probe5: diag_rx_counter_ref
create_debug_port ila_rx_frame probe
set_property port_width 24 [get_debug_ports ila_rx_frame/probe5]
connect_debug_port ila_rx_frame/probe5 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_counter_ref[23]
}]

# probe6: diag_frame_history_ref
create_debug_port ila_rx_frame probe
set_property port_width 16 [get_debug_ports ila_rx_frame/probe6]
connect_debug_port ila_rx_frame/probe6 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_history_ref[15]
}]

# probe7: diag_sample_data_ref
create_debug_port ila_rx_frame probe
set_property port_width 64 [get_debug_ports ila_rx_frame/probe7]
connect_debug_port ila_rx_frame/probe7 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[23]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[24]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[25]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[26]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[27]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[28]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[29]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[30]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[31]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[32]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[33]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[34]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[35]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[36]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[37]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[38]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[39]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[40]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[41]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[42]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[43]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[44]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[45]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[46]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[47]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[48]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[49]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[50]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[51]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[52]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[53]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[54]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[55]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[56]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[57]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[58]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[59]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[60]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[61]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[62]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_sample_data_ref[63]
}]

# probe8: diag_rx_data_pair_ref
create_debug_port ila_rx_frame probe
set_property port_width 12 [get_debug_ports ila_rx_frame/probe8]
connect_debug_port ila_rx_frame/probe8 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_rx_data_pair_ref[11]
}]

# probe9: diag_lane_fall_ref
create_debug_port ila_rx_frame probe
set_property port_width 7 [get_debug_ports ila_rx_frame/probe9]
connect_debug_port ila_rx_frame/probe9 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_fall_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_fall_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_fall_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_fall_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_fall_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_fall_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_fall_ref[6]
}]

# probe10: diag_lane_rise_ref
create_debug_port ila_rx_frame probe
set_property port_width 7 [get_debug_ports ila_rx_frame/probe10]
connect_debug_port ila_rx_frame/probe10 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_rise_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_rise_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_rise_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_rise_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_rise_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_rise_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_lane_rise_ref[6]
}]

# probe11: diag_frame_pair_ref
create_debug_port ila_rx_frame probe
set_property port_width 2 [get_debug_ports ila_rx_frame/probe11]
connect_debug_port ila_rx_frame/probe11 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_pair_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_frame_pair_ref[1]
}]

# probe12: diag_phase_ref
create_debug_port ila_rx_frame probe
set_property port_width 2 [get_debug_ports ila_rx_frame/probe12]
connect_debug_port ila_rx_frame/probe12 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_phase_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_phase_ref[1]
}]

# probe13: diag_flags_ref
create_debug_port ila_rx_frame probe
set_property port_width 8 [get_debug_ports ila_rx_frame/probe13]
connect_debug_port ila_rx_frame/probe13 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/diag_flags_ref[7]
}]

# Pre-FIFO records are written by RX, frozen, then read by ref_clk200.
# All ILA probes below are registered/read in ref_clk200; no live RX bus CDC.
create_debug_core ila_rx_prefifo ila
set_property -dict {C_DATA_DEPTH 2048 C_INPUT_PIPE_STAGES 2 C_ADV_TRIGGER false C_EN_STRG_QUAL false} [get_debug_cores ila_rx_prefifo]
set_property port_width 1 [get_debug_ports ila_rx_prefifo/clk]
connect_debug_port ila_rx_prefifo/clk [get_nets -of_objects [get_pins {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/ref_clk200}]]

# probe0: prefifo_lane_rise_ref
set_property port_width 7 [get_debug_ports ila_rx_prefifo/probe0]
connect_debug_port ila_rx_prefifo/probe0 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_rise_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_rise_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_rise_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_rise_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_rise_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_rise_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_rise_ref[6]
}]

# probe1: prefifo_lane_fall_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 7 [get_debug_ports ila_rx_prefifo/probe1]
connect_debug_port ila_rx_prefifo/probe1 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_ref[6]
}]

# probe2: prefifo_lane_fall_d_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 7 [get_debug_ports ila_rx_prefifo/probe2]
connect_debug_port ila_rx_prefifo/probe2 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_d_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_d_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_d_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_d_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_d_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_d_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_lane_fall_d_ref[6]
}]

# probe3: prefifo_rx_data_pair_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 12 [get_debug_ports ila_rx_prefifo/probe3]
connect_debug_port ila_rx_prefifo/probe3 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_data_pair_ref[11]
}]

# probe4: prefifo_frame_pair_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 2 [get_debug_ports ila_rx_prefifo/probe4]
connect_debug_port ila_rx_prefifo/probe4 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_frame_pair_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_frame_pair_ref[1]
}]

# probe5: prefifo_dbg_alt_frame_pair_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 2 [get_debug_ports ila_rx_prefifo/probe5]
connect_debug_port ila_rx_prefifo/probe5 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_alt_frame_pair_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_alt_frame_pair_ref[1]
}]

# probe6: prefifo_dbg_frame_window_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 4 [get_debug_ports ila_rx_prefifo/probe6]
connect_debug_port ila_rx_prefifo/probe6 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_frame_window_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_frame_window_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_frame_window_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_frame_window_ref[3]
}]

# probe7: prefifo_dbg_monitor_valid_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe7]
connect_debug_port ila_rx_prefifo/probe7 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_monitor_valid_ref
}]

# probe8: prefifo_dbg_window_bad_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe8]
connect_debug_port ila_rx_prefifo/probe8 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_bad_ref
}]

# probe9: prefifo_dbg_sequence_bad_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe9]
connect_debug_port ila_rx_prefifo/probe9 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_bad_ref
}]

# probe10: prefifo_dbg_window_errors_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 16 [get_debug_ports ila_rx_prefifo/probe10]
connect_debug_port ila_rx_prefifo/probe10 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_window_errors_ref[15]
}]

# probe11: prefifo_dbg_sequence_errors_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 16 [get_debug_ports ila_rx_prefifo/probe11]
connect_debug_port ila_rx_prefifo/probe11 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_sequence_errors_ref[15]
}]

# probe12: prefifo_dbg_reference_iq_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 48 [get_debug_ports ila_rx_prefifo/probe12]
connect_debug_port ila_rx_prefifo/probe12 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[23]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[24]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[25]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[26]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[27]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[28]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[29]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[30]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[31]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[32]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[33]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[34]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[35]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[36]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[37]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[38]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[39]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[40]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[41]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[42]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[43]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[44]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[45]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[46]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_iq_ref[47]
}]

# probe13: prefifo_dbg_reference_valid_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe13]
connect_debug_port ila_rx_prefifo/probe13 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_dbg_reference_valid_ref
}]

# probe14: prefifo_sample_data_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 64 [get_debug_ports ila_rx_prefifo/probe14]
connect_debug_port ila_rx_prefifo/probe14 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[23]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[24]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[25]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[26]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[27]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[28]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[29]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[30]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[31]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[32]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[33]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[34]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[35]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[36]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[37]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[38]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[39]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[40]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[41]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[42]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[43]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[44]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[45]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[46]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[47]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[48]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[49]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[50]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[51]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[52]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[53]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[54]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[55]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[56]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[57]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[58]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[59]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[60]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[61]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[62]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_data_ref[63]
}]

# probe15: prefifo_sample_valid_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe15]
connect_debug_port ila_rx_prefifo/probe15 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_sample_valid_ref
}]

# probe16: prefifo_phase_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 3 [get_debug_ports ila_rx_prefifo/probe16]
connect_debug_port ila_rx_prefifo/probe16 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_phase_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_phase_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_phase_ref[2]
}]

# probe17: prefifo_locked_rx_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe17]
connect_debug_port ila_rx_prefifo/probe17 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_locked_rx_ref
}]

# probe18: prefifo_frame_error_rx_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe18]
connect_debug_port ila_rx_prefifo/probe18 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_frame_error_rx_ref
}]

# probe19: prefifo_pending_data_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 64 [get_debug_ports ila_rx_prefifo/probe19]
connect_debug_port ila_rx_prefifo/probe19 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[23]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[24]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[25]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[26]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[27]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[28]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[29]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[30]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[31]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[32]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[33]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[34]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[35]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[36]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[37]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[38]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[39]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[40]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[41]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[42]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[43]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[44]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[45]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[46]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[47]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[48]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[49]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[50]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[51]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[52]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[53]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[54]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[55]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[56]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[57]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[58]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[59]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[60]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[61]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[62]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_data_ref[63]
}]

# probe20: prefifo_pending_valid_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe20]
connect_debug_port ila_rx_prefifo/probe20 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_valid_ref
}]

# probe21: prefifo_pending_last_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe21]
connect_debug_port ila_rx_prefifo/probe21 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_pending_last_ref
}]

# probe22: prefifo_fifo_source_ready_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe22]
connect_debug_port ila_rx_prefifo/probe22 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_fifo_source_ready_ref
}]

# probe23: prefifo_armed_rx_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe23]
connect_debug_port ila_rx_prefifo/probe23 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_armed_rx_ref
}]

# probe24: prefifo_overflow_rx_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe24]
connect_debug_port ila_rx_prefifo/probe24 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_overflow_rx_ref
}]

# probe25: prefifo_rx_resetn_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe25]
connect_debug_port ila_rx_prefifo/probe25 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_resetn_ref
}]

# probe26: prefifo_rx_edge_counter_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 24 [get_debug_ports ila_rx_prefifo/probe26]
connect_debug_port ila_rx_prefifo/probe26 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_rx_edge_counter_ref[23]
}]

# probe27: prefifo_valid_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe27]
connect_debug_port ila_rx_prefifo/probe27 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_valid_ref
}]

# probe28: prefifo_index_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 6 [get_debug_ports ila_rx_prefifo/probe28]
connect_debug_port ila_rx_prefifo/probe28 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_index_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_index_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_index_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_index_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_index_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_index_ref[5]
}]

# probe29: prefifo_batch_ref
create_debug_port ila_rx_prefifo probe
set_property port_width 16 [get_debug_ports ila_rx_prefifo/probe29]
connect_debug_port ila_rx_prefifo/probe29 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/prefifo_batch_ref[15]
}]
