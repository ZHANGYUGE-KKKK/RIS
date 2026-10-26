`timescale 1ns / 1ps
`default_nettype none

// Single-chip controller. A request is accepted only at start && ready.
// Caller supplies a one-cycle start; busy requests are ignored, not queued.
module ris_595_single #(
    parameter integer HALF_PERIOD_CYCLES = 5
) (
    input  wire       clk,
    input  wire       resetn,
    input  wire       start,
    input  wire [7:0] data_in,
    input  wire       output_enable,
    output wire       ready,
    output wire       busy,
    output wire       done,
    output reg        valid,
    output wire [7:0] latched_data,
    output wire       ds,
    output wire       shcp,
    output wire       stcp,
    output wire       mr_n,
    output wire       oe_n
);
    wire load, advance, latch;
    ris_595_timing #(.HALF_PERIOD_CYCLES(HALF_PERIOD_CYCLES)) u_timing (
        .clk(clk), .resetn(resetn), .start(start),
        .ready(ready), .busy(busy), .done(done),
        .load(load), .advance(advance), .latch(latch),
        .shcp(shcp), .stcp(stcp), .mr_n(mr_n)
    );
    ris_595_byte u_byte (
        .clk(clk), .resetn(resetn), .load(load), .advance(advance),
        .latch(latch), .data_in(data_in), .ds(ds), .latched_data(latched_data)
    );

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            valid <= 1'b0;
        else if (done)
            // Only enable Q after the first latch pulse AND recovery interval.
            valid <= 1'b1;
    end
    assign oe_n = !(resetn && valid && output_enable);
endmodule

`default_nettype wire
