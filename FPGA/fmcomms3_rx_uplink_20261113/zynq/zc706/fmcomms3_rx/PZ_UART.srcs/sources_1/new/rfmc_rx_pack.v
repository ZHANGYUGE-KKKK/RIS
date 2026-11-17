`timescale 1ns / 1ps

// The ADC cannot pause. Latch overflow whenever the downstream FIFO is full.
module rfmc_rx_pack (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 adc_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXIS, ASSOCIATED_RESET adc_resetn" *)
    input wire adc_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 adc_resetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire adc_resetn,
    input wire adc_valid,
    input wire adc_status,
    input wire delay_ready,
    input wire [11:0] adc_i1, adc_q1, adc_i2, adc_q2,
    output reg overflow,
    output reg frame_error,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output wire [63:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    output wire m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input wire m_axis_tready
);
    // This adapter is a non-throttleable source. Once overflow occurs the
    // capture is invalid; a reset is required before trusting another capture.
    // The elastic slot holds the first stalled beat stable, then drops new ADC
    // samples with an explicit sticky error instead of violating AXIS.
    reg [63:0] data_reg;
    reg valid_reg;
    assign m_axis_tdata = data_reg;
    assign m_axis_tvalid = valid_reg;
    wire [63:0] packed_sample = {
        {4{adc_q2[11]}}, adc_q2, {4{adc_i2[11]}}, adc_i2,
        {4{adc_q1[11]}}, adc_q1, {4{adc_i1[11]}}, adc_i1
    };
    // These registers drive FIFO RAM write enables; reset synchronously to
    // avoid asynchronous changes on RAM control pins.
    always @(posedge adc_clk) begin
        if (!adc_resetn) begin
            data_reg <= 0;
            valid_reg <= 0;
            overflow <= 0;
            frame_error <= 0;
        end else begin
            if (valid_reg && m_axis_tready) valid_reg <= 0;
            if (delay_ready && !adc_status) frame_error <= 1;
            if (adc_valid && delay_ready) begin
                if (!valid_reg || m_axis_tready) begin
                    data_reg <= packed_sample;
                    valid_reg <= 1;
                end else overflow <= 1;
            end
        end
    end
endmodule
