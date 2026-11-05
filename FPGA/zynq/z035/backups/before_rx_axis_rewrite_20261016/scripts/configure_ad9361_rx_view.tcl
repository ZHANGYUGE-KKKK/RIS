# Run after display_hw_ila_data for ila_ad9361_rx, in the Vivado GUI.
# Rebuild the current hardware waveform view instead of reusing legacy names.
set adi_view_cfg [current_wave_config]
set adi_view_prefix u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst
catch {remove_wave -of $adi_view_cfg *}
foreach {adi_view_label adi_view_signal adi_view_radix} {
    RECORD_VALID prefifo_valid_ref bin
    IQ_VALID prefifo_official_valid_ref bin
    RX1_I rx1_i_ref dec
    RX1_Q rx1_q_ref dec
    RX2_I rx2_i_ref dec
    RX2_Q rx2_q_ref dec
    FRAME_DDR prefifo_raw_frame_ref bin
    FRAME_PREVIOUS prefifo_raw_frame_previous_ref bin
    ADI_STATUS prefifo_official_status_ref bin
    CORE_RESET prefifo_official_rst_ref bin
    RX_RISE prefifo_raw_data_rise_ref hex
    RX_FALL prefifo_raw_data_fall_ref hex
    RX_COUNTER prefifo_rx_edge_counter_ref hex
    RECORD_INDEX prefifo_index_ref unsigned
    RECORD_BANK prefifo_batch_ref unsigned
    RX_EDGES_PER_MS rx_edges_per_ms_ref unsigned
    AXIS_IQ prefifo_sample_data_ref hex
    AXIS_VALID prefifo_sample_valid_ref bin
    FIFO_READY prefifo_fifo_source_ready_ref bin
    ARM prefifo_armed_rx_ref bin
    OVERFLOW prefifo_overflow_rx_ref bin
    FRAME_ERROR prefifo_frame_error_rx_ref bin
    DELAY_ERROR prefifo_delay_error_rx_ref bin
} {
    add_wave -into $adi_view_cfg -radix $adi_view_radix -name $adi_view_label $adi_view_prefix/$adi_view_signal
}
save_wave_config
puts AD9361_RX_VIEW_CONFIGURED
