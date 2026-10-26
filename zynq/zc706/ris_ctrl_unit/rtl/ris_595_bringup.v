`timescale 1ns / 1ps
`default_nettype none

// PS GPIO frontend for first-chip bring-up on the populated 50-chip board.
// command: [7:0] byte, [8] start rising edge, [9] output enable, [10] reset.
// All groups receive the same clocks; DATA_U02..50 are explicitly zero.
module ris_595_bringup #(
    parameter integer HALF_PERIOD_CYCLES = 5
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_RESET resetn" *)
    input  wire        clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        resetn,
    input  wire [31:0] command,
    output wire [31:0] status,
    output wire [49:0] ris_data,
    output wire [9:0]  ris_shcp,
    output wire [9:0]  ris_stcp,
    output wire        ris_mr_n,
    output wire        ris_oe_n
);
    wire unit_resetn = resetn && !command[10];
    reg start_delayed;
    wire start = command[8] && !start_delayed;
    wire ready, busy, done, valid, ds, shcp, stcp;
    wire [7:0] latched_data;
    reg rejected;
    reg [15:0] completed;

    // Follow START through soft reset; releasing reset cannot invent a request.
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            start_delayed <= 1'b0;
        else
            start_delayed <= command[8];
    end
    always @(posedge clk or negedge unit_resetn) begin
        if (!unit_resetn) begin
            rejected  <= 1'b0;
            completed <= 0;
        end else begin
            if (start && !ready) rejected <= 1'b1;
            if (done) completed <= completed + 1'b1;
        end
    end

    ris_595_single #(.HALF_PERIOD_CYCLES(HALF_PERIOD_CYCLES)) u_single (
        .clk(clk), .resetn(unit_resetn), .start(start), .data_in(command[7:0]),
        .output_enable(command[9]), .ready(ready), .busy(busy), .done(done),
        .valid(valid), .latched_data(latched_data),
        .ds(ds), .shcp(shcp), .stcp(stcp), .mr_n(ris_mr_n), .oe_n(ris_oe_n)
    );
    assign ris_data = {49'b0, ds};
    assign ris_shcp = {10{shcp}};
    assign ris_stcp = {10{stcp}};
    // [0] ready [1] busy [2] valid [3] enabled [4] sticky rejected
    // [15:8] last latched byte; [31:16] completed operations, modulo 65536.
    assign status = {completed, latched_data, 3'b0, rejected,
                     !ris_oe_n, valid, busy, ready};
endmodule

`default_nettype wire
