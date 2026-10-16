# Coherent 64-RX-cycle records replayed in the 200 MHz reference domain.
create_debug_core ila_ad9361_rx ila
set_property -dict {C_DATA_DEPTH 2048 C_INPUT_PIPE_STAGES 2 C_ADV_TRIGGER false C_EN_STRG_QUAL false} [get_debug_cores ila_ad9361_rx]
set_property port_width 1 [get_debug_ports ila_ad9361_rx/clk]
connect_debug_port ila_ad9361_rx/clk [get_nets -of_objects [get_pins {u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/ref_clk200}]]

# probe0: prefifo_valid_ref
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe0]
connect_debug_port ila_ad9361_rx/probe0 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_valid_ref
}]

# probe1: prefifo_index_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 6 [get_debug_ports ila_ad9361_rx/probe1]
connect_debug_port ila_ad9361_rx/probe1 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_index_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_index_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_index_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_index_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_index_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_index_ref[5]
}]

# probe2: prefifo_batch_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 16 [get_debug_ports ila_ad9361_rx/probe2]
connect_debug_port ila_ad9361_rx/probe2 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[11]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[12]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[13]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[14]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_batch_ref[15]
}]

# probe3: prefifo_raw_frame_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 2 [get_debug_ports ila_ad9361_rx/probe3]
connect_debug_port ila_ad9361_rx/probe3 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_frame_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_frame_ref[1]
}]

# probe4: prefifo_raw_frame_previous_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 2 [get_debug_ports ila_ad9361_rx/probe4]
connect_debug_port ila_ad9361_rx/probe4 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_frame_previous_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_frame_previous_ref[1]
}]

# probe5: prefifo_raw_data_rise_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 6 [get_debug_ports ila_ad9361_rx/probe5]
connect_debug_port ila_ad9361_rx/probe5 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_rise_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_rise_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_rise_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_rise_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_rise_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_rise_ref[5]
}]

# probe6: prefifo_raw_data_fall_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 6 [get_debug_ports ila_ad9361_rx/probe6]
connect_debug_port ila_ad9361_rx/probe6 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_fall_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_fall_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_fall_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_fall_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_fall_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_raw_data_fall_ref[5]
}]

# probe7: prefifo_official_data_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 48 [get_debug_ports ila_ad9361_rx/probe7]
connect_debug_port ila_ad9361_rx/probe7 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[11]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[12]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[13]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[14]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[15]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[16]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[17]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[18]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[19]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[20]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[21]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[22]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[23]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[24]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[25]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[26]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[27]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[28]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[29]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[30]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[31]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[32]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[33]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[34]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[35]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[36]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[37]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[38]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[39]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[40]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[41]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[42]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[43]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[44]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[45]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[46]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_data_ref[47]
}]

# probe8: prefifo_official_valid_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe8]
connect_debug_port ila_ad9361_rx/probe8 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_valid_ref
}]

# probe9: prefifo_official_status_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe9]
connect_debug_port ila_ad9361_rx/probe9 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_status_ref
}]

# probe10: prefifo_official_rst_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe10]
connect_debug_port ila_ad9361_rx/probe10 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_official_rst_ref
}]

# probe11: prefifo_sample_data_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 64 [get_debug_ports ila_ad9361_rx/probe11]
connect_debug_port ila_ad9361_rx/probe11 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[11]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[12]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[13]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[14]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[15]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[16]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[17]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[18]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[19]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[20]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[21]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[22]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[23]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[24]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[25]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[26]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[27]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[28]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[29]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[30]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[31]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[32]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[33]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[34]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[35]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[36]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[37]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[38]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[39]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[40]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[41]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[42]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[43]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[44]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[45]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[46]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[47]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[48]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[49]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[50]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[51]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[52]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[53]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[54]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[55]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[56]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[57]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[58]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[59]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[60]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[61]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[62]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_data_ref[63]
}]

# probe12: prefifo_sample_valid_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe12]
connect_debug_port ila_ad9361_rx/probe12 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_sample_valid_ref
}]

# probe13: prefifo_pending_data_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 64 [get_debug_ports ila_ad9361_rx/probe13]
connect_debug_port ila_ad9361_rx/probe13 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[11]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[12]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[13]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[14]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[15]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[16]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[17]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[18]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[19]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[20]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[21]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[22]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[23]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[24]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[25]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[26]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[27]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[28]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[29]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[30]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[31]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[32]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[33]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[34]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[35]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[36]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[37]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[38]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[39]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[40]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[41]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[42]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[43]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[44]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[45]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[46]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[47]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[48]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[49]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[50]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[51]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[52]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[53]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[54]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[55]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[56]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[57]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[58]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[59]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[60]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[61]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[62]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_data_ref[63]
}]

# probe14: prefifo_pending_valid_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe14]
connect_debug_port ila_ad9361_rx/probe14 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_valid_ref
}]

# probe15: prefifo_pending_last_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe15]
connect_debug_port ila_ad9361_rx/probe15 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_pending_last_ref
}]

# probe16: prefifo_fifo_source_ready_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe16]
connect_debug_port ila_ad9361_rx/probe16 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_fifo_source_ready_ref
}]

# probe17: prefifo_armed_rx_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe17]
connect_debug_port ila_ad9361_rx/probe17 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_armed_rx_ref
}]

# probe18: prefifo_overflow_rx_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe18]
connect_debug_port ila_ad9361_rx/probe18 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_overflow_rx_ref
}]

# probe19: prefifo_frame_error_rx_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe19]
connect_debug_port ila_ad9361_rx/probe19 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_frame_error_rx_ref
}]

# probe20: prefifo_delay_error_rx_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 1 [get_debug_ports ila_ad9361_rx/probe20]
connect_debug_port ila_ad9361_rx/probe20 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_delay_error_rx_ref
}]

# probe21: prefifo_rx_edge_counter_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 24 [get_debug_ports ila_ad9361_rx/probe21]
connect_debug_port ila_ad9361_rx/probe21 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[11]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[12]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[13]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[14]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[15]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[16]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[17]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[18]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[19]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[20]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[21]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[22]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/prefifo_rx_edge_counter_ref[23]
}]

# probe22: rx1_i_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 12 [get_debug_ports ila_ad9361_rx/probe22]
connect_debug_port ila_ad9361_rx/probe22 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_i_ref[11]
}]

# probe23: rx1_q_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 12 [get_debug_ports ila_ad9361_rx/probe23]
connect_debug_port ila_ad9361_rx/probe23 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx1_q_ref[11]
}]

# probe24: rx2_i_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 12 [get_debug_ports ila_ad9361_rx/probe24]
connect_debug_port ila_ad9361_rx/probe24 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_i_ref[11]
}]

# probe25: rx2_q_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 12 [get_debug_ports ila_ad9361_rx/probe25]
connect_debug_port ila_ad9361_rx/probe25 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx2_q_ref[11]
}]

# probe26: rx_edges_per_ms_ref
create_debug_port ila_ad9361_rx probe
set_property port_width 24 [get_debug_ports ila_ad9361_rx/probe26]
connect_debug_port ila_ad9361_rx/probe26 [get_nets {
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[0]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[1]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[2]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[3]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[4]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[5]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[6]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[7]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[8]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[9]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[10]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[11]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[12]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[13]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[14]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[15]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[16]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[17]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[18]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[19]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[20]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[21]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[22]
    u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst/rx_edges_per_ms_ref[23]
}]
