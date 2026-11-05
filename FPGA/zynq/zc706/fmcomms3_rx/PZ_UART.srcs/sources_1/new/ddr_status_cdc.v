// Diagnostic level flags only: retain a live 200MHz ILA even before MIG UI
// starts. Each flag crosses independently; this is not a coherent data bus.
module ddr_status_cdc (
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk200 CLK", X_INTERFACE_PARAMETER="FREQ_HZ 200000000" *)
    input wire clk200,
    input wire in_ui_reset, in_resetn, in_mmcm_locked, in_calib,
    output wire out_ui_reset, out_resetn, out_mmcm_locked, out_calib
);
    wire [3:0] observed;
    xpm_cdc_array_single #(
        .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(0),
        .SRC_INPUT_REG(0), .WIDTH(4)
    ) u_flags (
        .src_clk(1'b0),
        .src_in({in_calib,in_mmcm_locked,in_resetn,in_ui_reset}),
        .dest_clk(clk200), .dest_out(observed)
    );
    assign {out_calib,out_mmcm_locked,out_resetn,out_ui_reset}=observed;
endmodule
