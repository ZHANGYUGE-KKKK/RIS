# Run after display_hw_ila_data for ila_ad9361_rx, in the Vivado GUI.
# The rewritten receiver ILA samples the live AXIS interface at 100 MHz.
# AXIS_IQ lanes: [15:0]=I1, [31:16]=Q1, [47:32]=I2, [63:48]=Q2,
# each signed 12-bit sample sign-extended to 16 bits.
# FLAGS bits: 0 ARM command, 1 TVALID, 2 TREADY, 3 TLAST,
# 4 receiver ready, 5 FRAME locked, 6 capture active, 7 overflow,
# 8 FRAME error, 9 delay error. Data transfers only with bits 1 and 2 high.
# Counters are independent Gray-synchronized diagnostics, not sample tags.
# RAW_RX bit48 qualifies a coherent RX-domain record in bits47:0:
# [47:32] DATA_CLK counter bits15:0, [31:26] counter bits21:16, [25] delay ready,
# [24] FRAME fault, [23] tuple valid, [22] FRAME locked, [21:14] FRAME
# history, [13:7] early DDR data/frame, [6:0] late DDR data/frame.
# RAW_RX remains observable with ARM=0 for physical-interface diagnostics.
set adi_view_cfg [current_wave_config]
set adi_view_prefix u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst
catch {remove_wave -of $adi_view_cfg *}
foreach {adi_view_label adi_view_signal adi_view_radix} {
    AXIS_IQ debug_axis_data hex
    FLAGS debug_axis_flags bin
    DECODED_TUPLES debug_sample_count unsigned
    DATA_CLK_CYCLES debug_clock_count unsigned
    RAW_RX debug_raw_rx hex
} {
    add_wave -into $adi_view_cfg -radix $adi_view_radix -name $adi_view_label $adi_view_prefix/$adi_view_signal
}
save_wave_config
puts AD9361_RX_VIEW_CONFIGURED
