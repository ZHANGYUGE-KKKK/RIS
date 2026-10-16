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

# Live pre-FIFO capture: every probe belongs to the external RX DATA_CLK.
create_debug_core ila_rx_prefifo ila
set_property -dict {C_DATA_DEPTH 2048 C_INPUT_PIPE_STAGES 2 C_ADV_TRIGGER false C_EN_STRG_QUAL false} [get_debug_cores ila_rx_prefifo]
set_property port_width 1 [get_debug_ports ila_rx_prefifo/clk]
connect_debug_port ila_rx_prefifo/clk [get_nets -of_objects [get_pins {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/i_rx_clk_global/O}]]

# probe0: lane_rise
set_property port_width 7 [get_debug_ports ila_rx_prefifo/probe0]
connect_debug_port ila_rx_prefifo/probe0 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[6]
}]

# probe1: lane_fall
create_debug_port ila_rx_prefifo probe
set_property port_width 7 [get_debug_ports ila_rx_prefifo/probe1]
connect_debug_port ila_rx_prefifo/probe1 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall[6]
}]

# probe2: lane_fall_d
create_debug_port ila_rx_prefifo probe
set_property port_width 7 [get_debug_ports ila_rx_prefifo/probe2]
connect_debug_port ila_rx_prefifo/probe2 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[6]
}]

# probe3: rx_data_pair
create_debug_port ila_rx_prefifo probe
set_property port_width 12 [get_debug_ports ila_rx_prefifo/probe3]
connect_debug_port ila_rx_prefifo/probe3 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[11]
}]

# probe4: frame_pair
create_debug_port ila_rx_prefifo probe
set_property port_width 2 [get_debug_ports ila_rx_prefifo/probe4]
connect_debug_port ila_rx_prefifo/probe4 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/frame_pair[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/frame_pair[1]
}]

# probe5: dbg_alt_frame_pair
create_debug_port ila_rx_prefifo probe
set_property port_width 2 [get_debug_ports ila_rx_prefifo/probe5]
connect_debug_port ila_rx_prefifo/probe5 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_alt_frame_pair[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_alt_frame_pair[1]
}]

# probe6: dbg_frame_window
create_debug_port ila_rx_prefifo probe
set_property port_width 4 [get_debug_ports ila_rx_prefifo/probe6]
connect_debug_port ila_rx_prefifo/probe6 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_frame_window[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_frame_window[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_frame_window[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_frame_window[3]
}]

# probe7: dbg_monitor_valid
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe7]
connect_debug_port ila_rx_prefifo/probe7 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_monitor_valid
}]

# probe8: dbg_window_bad
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe8]
connect_debug_port ila_rx_prefifo/probe8 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_bad
}]

# probe9: dbg_sequence_bad
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe9]
connect_debug_port ila_rx_prefifo/probe9 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_bad
}]

# probe10: dbg_window_errors
create_debug_port ila_rx_prefifo probe
set_property port_width 16 [get_debug_ports ila_rx_prefifo/probe10]
connect_debug_port ila_rx_prefifo/probe10 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_window_errors[15]
}]

# probe11: dbg_sequence_errors
create_debug_port ila_rx_prefifo probe
set_property port_width 16 [get_debug_ports ila_rx_prefifo/probe11]
connect_debug_port ila_rx_prefifo/probe11 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_sequence_errors[15]
}]

# probe12: dbg_reference_iq
create_debug_port ila_rx_prefifo probe
set_property port_width 48 [get_debug_ports ila_rx_prefifo/probe12]
connect_debug_port ila_rx_prefifo/probe12 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[23]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[24]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[25]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[26]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[27]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[28]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[29]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[30]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[31]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[32]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[33]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[34]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[35]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[36]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[37]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[38]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[39]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[40]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[41]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[42]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[43]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[44]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[45]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[46]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_iq[47]
}]

# probe13: dbg_reference_valid
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe13]
connect_debug_port ila_rx_prefifo/probe13 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/dbg_reference_valid
}]

# probe14: sample_data
create_debug_port ila_rx_prefifo probe
set_property port_width 64 [get_debug_ports ila_rx_prefifo/probe14]
connect_debug_port ila_rx_prefifo/probe14 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[23]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[24]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[25]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[26]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[27]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[28]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[29]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[30]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[31]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[32]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[33]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[34]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[35]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[36]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[37]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[38]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[39]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[40]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[41]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[42]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[43]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[44]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[45]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[46]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[47]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[48]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[49]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[50]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[51]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[52]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[53]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[54]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[55]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[56]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[57]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[58]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[59]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[60]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[61]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[62]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[63]
}]

# probe15: sample_valid
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe15]
connect_debug_port ila_rx_prefifo/probe15 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_valid
}]

# probe16: phase
create_debug_port ila_rx_prefifo probe
set_property port_width 3 [get_debug_ports ila_rx_prefifo/probe16]
connect_debug_port ila_rx_prefifo/probe16 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/phase[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/phase[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/phase[2]
}]

# probe17: locked_rx
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe17]
connect_debug_port ila_rx_prefifo/probe17 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/locked_rx
}]

# probe18: frame_error_rx
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe18]
connect_debug_port ila_rx_prefifo/probe18 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/frame_error_rx
}]

# probe19: pending_data
create_debug_port ila_rx_prefifo probe
set_property port_width 64 [get_debug_ports ila_rx_prefifo/probe19]
connect_debug_port ila_rx_prefifo/probe19 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[0]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[1]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[2]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[3]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[4]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[5]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[6]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[7]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[8]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[9]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[10]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[11]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[12]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[13]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[14]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[15]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[16]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[17]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[18]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[19]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[20]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[21]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[22]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[23]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[24]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[25]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[26]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[27]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[28]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[29]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[30]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[31]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[32]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[33]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[34]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[35]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[36]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[37]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[38]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[39]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[40]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[41]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[42]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[43]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[44]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[45]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[46]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[47]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[48]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[49]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[50]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[51]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[52]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[53]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[54]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[55]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[56]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[57]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[58]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[59]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[60]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[61]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[62]
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_data[63]
}]

# probe20: pending_valid
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe20]
connect_debug_port ila_rx_prefifo/probe20 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_valid
}]

# probe21: pending_last
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe21]
connect_debug_port ila_rx_prefifo/probe21 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/pending_last
}]

# probe22: fifo_source_ready
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe22]
connect_debug_port ila_rx_prefifo/probe22 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/fifo_source_ready
}]

# probe23: armed_rx
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe23]
connect_debug_port ila_rx_prefifo/probe23 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/armed_rx
}]

# probe24: overflow_rx
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe24]
connect_debug_port ila_rx_prefifo/probe24 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/overflow_rx
}]

# probe25: rx_resetn
create_debug_port ila_rx_prefifo probe
set_property port_width 1 [get_debug_ports ila_rx_prefifo/probe25]
connect_debug_port ila_rx_prefifo/probe25 [get_nets {
    u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_resetn
}]
