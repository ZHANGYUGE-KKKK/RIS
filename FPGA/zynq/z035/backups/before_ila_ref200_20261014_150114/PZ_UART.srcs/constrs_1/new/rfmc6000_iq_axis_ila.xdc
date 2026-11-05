# RX-domain ILA; implementation-only XDC, processed after receiver CDC.
# No sampling/control logic is changed. Probe inputs use the RX BUFG clock.
# Two common input pipeline stages keep relative probe timing unchanged.
# Observe only ready_pipe[2]; never load intermediate ASYNC_REG stages.
create_debug_core ila_rx_frame ila
set_property -dict {C_DATA_DEPTH 2048 C_INPUT_PIPE_STAGES 2 C_ADV_TRIGGER false C_EN_STRG_QUAL false} [get_debug_cores ila_rx_frame]
set_property port_width 1 [get_debug_ports ila_rx_frame/clk]
connect_debug_port ila_rx_frame/clk [get_nets -of_objects [get_pins {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/i_rx_clk_global/O}]]
# probe0: lane_rise[6]
set_property port_width 1 [get_debug_ports ila_rx_frame/probe0]
connect_debug_port ila_rx_frame/probe0 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[6]}]
create_debug_port ila_rx_frame probe
# probe1: lane_fall[6]
set_property port_width 1 [get_debug_ports ila_rx_frame/probe1]
connect_debug_port ila_rx_frame/probe1 [get_nets -of_objects [get_pins {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/g_rx_lane[6].i_ddr/Q2}]]
create_debug_port ila_rx_frame probe
# probe2: lane_fall_d[6]
set_property port_width 1 [get_debug_ports ila_rx_frame/probe2]
connect_debug_port ila_rx_frame/probe2 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_fall_d[6]}]
create_debug_port ila_rx_frame probe
# probe3: frame_pair[0, 1]
set_property port_width 2 [get_debug_ports ila_rx_frame/probe3]
connect_debug_port ila_rx_frame/probe3 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/frame_pair[0] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/frame_pair[1]}]
create_debug_port ila_rx_frame probe
# probe4: phase[0, 1]
set_property port_width 2 [get_debug_ports ila_rx_frame/probe4]
connect_debug_port ila_rx_frame/probe4 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/phase[0] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/phase[1]}]
create_debug_port ila_rx_frame probe
# probe5: previous_low
set_property port_width 1 [get_debug_ports ila_rx_frame/probe5]
connect_debug_port ila_rx_frame/probe5 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/previous_low}]
create_debug_port ila_rx_frame probe
# probe6: locked_rx
set_property port_width 1 [get_debug_ports ila_rx_frame/probe6]
connect_debug_port ila_rx_frame/probe6 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/locked_rx}]
create_debug_port ila_rx_frame probe
# probe7: frame_error_rx
set_property port_width 1 [get_debug_ports ila_rx_frame/probe7]
connect_debug_port ila_rx_frame/probe7 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/frame_error_rx}]
create_debug_port ila_rx_frame probe
# probe8: sample_valid
set_property port_width 1 [get_debug_ports ila_rx_frame/probe8]
connect_debug_port ila_rx_frame/probe8 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_valid}]
create_debug_port ila_rx_frame probe
# probe9: rx_resetn
set_property port_width 1 [get_debug_ports ila_rx_frame/probe9]
connect_debug_port ila_rx_frame/probe9 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_resetn}]
create_debug_port ila_rx_frame probe
# probe10: ready_pipe[2]
set_property port_width 1 [get_debug_ports ila_rx_frame/probe10]
connect_debug_port ila_rx_frame/probe10 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/ready_pipe[2]}]
create_debug_port ila_rx_frame probe
# probe11: fifo_booted_rx
set_property port_width 1 [get_debug_ports ila_rx_frame/probe11]
connect_debug_port ila_rx_frame/probe11 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/fifo_booted_rx}]
create_debug_port ila_rx_frame probe
# probe12: armed_rx
set_property port_width 1 [get_debug_ports ila_rx_frame/probe12]
connect_debug_port ila_rx_frame/probe12 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/armed_rx}]
create_debug_port ila_rx_frame probe
# probe13: overflow_rx
set_property port_width 1 [get_debug_ports ila_rx_frame/probe13]
connect_debug_port ila_rx_frame/probe13 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/overflow_rx}]
create_debug_port ila_rx_frame probe
# probe14: delay_error_rx
set_property port_width 1 [get_debug_ports ila_rx_frame/probe14]
connect_debug_port ila_rx_frame/probe14 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/delay_error_rx}]
create_debug_port ila_rx_frame probe
# probe15: lane_rise[0, 1, 2, 3, 4, 5]
set_property port_width 6 [get_debug_ports ila_rx_frame/probe15]
connect_debug_port ila_rx_frame/probe15 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[0] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[1] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[2] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[3] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[4] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/lane_rise[5]}]
create_debug_port ila_rx_frame probe
# probe16: lane_fall[0, 1, 2, 3, 4, 5]
set_property port_width 6 [get_debug_ports ila_rx_frame/probe16]
connect_debug_port ila_rx_frame/probe16 [get_nets -of_objects [get_pins {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/g_rx_lane[0].i_ddr/Q2 u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/g_rx_lane[1].i_ddr/Q2 u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/g_rx_lane[2].i_ddr/Q2 u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/g_rx_lane[3].i_ddr/Q2 u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/g_rx_lane[4].i_ddr/Q2 u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/g_rx_lane[5].i_ddr/Q2}]]
create_debug_port ila_rx_frame probe
# probe17: rx_data_pair[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
set_property port_width 12 [get_debug_ports ila_rx_frame/probe17]
connect_debug_port ila_rx_frame/probe17 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[0] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[1] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[2] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[3] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[4] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[5] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[6] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[7] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[8] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[9] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[10] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/rx_data_pair[11]}]
create_debug_port ila_rx_frame probe
# probe18: sample_data[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
set_property port_width 64 [get_debug_ports ila_rx_frame/probe18]
connect_debug_port ila_rx_frame/probe18 [get_nets {u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[0] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[1] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[2] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[3] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[4] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[5] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[6] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[7] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[8] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[9] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[10] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[11] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[12] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[13] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[14] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[15] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[16] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[17] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[18] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[19] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[20] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[21] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[22] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[23] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[24] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[25] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[26] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[27] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[28] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[29] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[30] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[31] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[32] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[33] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[34] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[35] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[36] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[37] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[38] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[39] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[40] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[41] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[42] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[43] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[44] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[45] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[46] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[47] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[48] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[49] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[50] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[51] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[52] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[53] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[54] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[55] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[56] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[57] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[58] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[59] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[60] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[61] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[62] u_design_1_wrapper/design_1_i/rfmc6000_iq_axis_0/inst/sample_data[63]}]
