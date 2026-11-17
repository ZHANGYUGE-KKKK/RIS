`timescale 1ns / 1ps

// Capture at the MIG UI clock. Control GPIO must be stable before ARM rises.
// One 64-bit beat always contains I1,Q1,I2,Q2 (single RX pads channel 2).
module rfmc_capture_axis #(
    parameter integer BLOCK_WORDS = 524288
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS:M_AXIS, ASSOCIATED_RESET aresetn" *)
    input wire aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire aresetn,
    input wire [31:0] control,
    input wire [31:0] sample_count,
    input wire mig_ready,
    input wire rx_overflow, rx_frame_error, rx_delay_ready,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 status_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET status_resetn" *)
    input wire status_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 status_resetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire status_resetn,
    output wire [31:0] status,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TDATA" *)
    input wire [63:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TVALID" *)
    input wire s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TREADY" *)
    output wire s_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output wire [63:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *)
    output wire [7:0] m_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    output wire m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input wire m_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *)
    output wire m_axis_tlast
);
    (* ASYNC_REG = "TRUE" *) reg [31:0] ctrl_meta, ctrl_sync;
    (* ASYNC_REG = "TRUE" *) reg [31:0] count_meta, count_sync;
    (* ASYNC_REG = "TRUE" *) reg [2:0] rx_meta, rx_sync;
    reg arm_d;
    reg active, submitted, bad_arm, test_mode;
    reg [31:0] remaining, block_index, test_index;
    // Status reports source submission; DMA completion must be checked too.
    wire [7:0] status_ui = {bad_arm, test_mode, rx_sync[2], rx_sync[1],
                            rx_sync[0], mig_ready, submitted, active};
    (* ASYNC_REG = "TRUE" *) reg [7:0] status_meta, status_sync;
    always @(posedge status_clk or negedge status_resetn) begin
        if (!status_resetn) begin status_meta <= 0; status_sync <= 0; end
        else begin status_meta <= status_ui; status_sync <= status_meta; end
    end
    assign status = {24'b0, status_sync};
    assign m_axis_tdata = test_mode ? {test_index ^ 32'h5a5a5a5a, test_index}
                                   : s_axis_tdata;
    assign m_axis_tkeep = 8'hff;
    assign m_axis_tvalid = active && (test_mode || s_axis_tvalid);
    assign m_axis_tlast = active && ((remaining == 1) ||
                                    (block_index == BLOCK_WORDS-1));
    // Drain the live RX FIFO while idle or while testing the memory path.
    assign s_axis_tready = (!active || test_mode) ? 1'b1 : m_axis_tready;
    // active/test_mode drive the FIFO RAM read enable. Keep their reset
    // assertion synchronous to this clock as well as their release.
    always @(posedge aclk) begin
        if (!aresetn) begin
            ctrl_meta <= 0; ctrl_sync <= 0;
            count_meta <= 0; count_sync <= 0;
            rx_meta <= 0; rx_sync <= 0;
            arm_d <= 0; active <= 0; submitted <= 0;
            bad_arm <= 0; test_mode <= 0;
            remaining <= 0; block_index <= 0; test_index <= 0;
        end else begin
            ctrl_meta <= control; ctrl_sync <= ctrl_meta;
            count_meta <= sample_count; count_sync <= count_meta;
            rx_meta <= {rx_delay_ready, rx_frame_error, rx_overflow};
            rx_sync <= rx_meta;
            arm_d <= ctrl_sync[0];
            if (ctrl_sync[0] && !arm_d) begin
                // Reject retriggering and requests exceeding the 1 GiB buffer.
                if (active || !mig_ready || count_sync == 0 ||
                    count_sync > 32'd134217728 ||
                    (!ctrl_sync[1] && (!rx_sync[2] || rx_sync[1:0] != 0)))
                    bad_arm <= 1;
                else begin
                    active <= 1;
                    submitted <= 0; bad_arm <= 0;
                    test_mode <= ctrl_sync[1];
                    remaining <= count_sync;
                    block_index <= 0; test_index <= 0;
                end
            end
            if (m_axis_tvalid && m_axis_tready) begin
                test_index <= test_index + 1;
                remaining <= remaining - 1;
                if (block_index == BLOCK_WORDS-1) block_index <= 0;
                else block_index <= block_index + 1;
                if (remaining == 1) begin
                    active <= 0;
                    submitted <= 1;
                end
            end
        end
    end
endmodule
