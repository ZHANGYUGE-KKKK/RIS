`timescale 1ns / 1ps
`default_nettype none

// One 74LVC8T595 data lane. All events are enables in the clk domain.
// A group of five lanes must use the SAME load/advance/latch events.
module ris_595_byte (
    input  wire       clk,
    input  wire       resetn,
    input  wire       load,
    input  wire       advance,
    input  wire       latch,
    input  wire [7:0] data_in,
    output wire       ds,
    output reg  [7:0] latched_data
);
    reg [7:0] shift_data;
    reg [7:0] pending_data;

    // MSB first: after eight SHCP rising edges, data_in[0] reaches Q0.
    assign ds = shift_data[7];

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            shift_data   <= 8'h00;
            pending_data <= 8'h00;
            latched_data <= 8'h00;
        end else begin
            if (load) begin
                shift_data   <= data_in;
                pending_data <= data_in;
            end else if (advance) begin
                // Advance on SHCP falling edges, preserving DS hold time.
                shift_data <= {shift_data[6:0], 1'b0};
            end
            if (latch)
                // Command mirror only; there is no physical Q readback.
                latched_data <= pending_data;
        end
    end
endmodule

`default_nettype wire
