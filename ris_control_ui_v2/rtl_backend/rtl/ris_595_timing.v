`timescale 1ns / 1ps
`default_nettype none

// Shared scheduler: registered SHCP/STCP outputs, no derived internal clocks.
// HALF_PERIOD_CYCLES must be >= 1. Board default: 100 MHz / (2*5) = 10 MHz.
module ris_595_timing #(
    parameter integer HALF_PERIOD_CYCLES = 5
) (
    input  wire clk,
    input  wire resetn,
    input  wire start,
    output wire ready,
    output wire busy,
    output reg  done,
    output wire load,
    output wire advance,
    output wire latch,
    output reg  shcp,
    output reg  stcp,
    output reg  mr_n
);
    localparam integer COUNT_WIDTH = (HALF_PERIOD_CYCLES > 1) ?
                                     $clog2(HALF_PERIOD_CYCLES) : 1;
    localparam [3:0] RESET_HOLD = 0, RESET_RECOVER = 1, IDLE = 2,
                     SHIFT_LOW = 3, SHIFT_HIGH = 4, LATCH_WAIT = 5,
                     LATCH_HIGH = 6, LATCH_RECOVER = 7;
    reg [3:0] state;
    reg [COUNT_WIDTH-1:0] count;
    reg [2:0] bit_index;
    wire tick = (count == HALF_PERIOD_CYCLES - 1);

    assign ready   = resetn && (state == IDLE);
    assign busy    = !ready;
    assign load    = ready && start;
    assign advance = resetn && (state == SHIFT_HIGH) && tick && (bit_index != 7);
    assign latch   = resetn && (state == LATCH_WAIT) && tick;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state     <= RESET_HOLD;
            count     <= 0;
            bit_index <= 0;
            shcp      <= 1'b0;
            stcp      <= 1'b0;
            mr_n      <= 1'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;
            if ((state == IDLE) || tick)
                count <= 0;
            else
                count <= count + 1'b1;

            case (state)
                RESET_HOLD: if (tick) begin
                    mr_n  <= 1'b1;
                    state <= RESET_RECOVER;
                end
                RESET_RECOVER: if (tick) state <= IDLE;
                IDLE: if (start) begin
                    bit_index <= 0;
                    state     <= SHIFT_LOW;
                end
                SHIFT_LOW: if (tick) begin
                    shcp  <= 1'b1;
                    state <= SHIFT_HIGH;
                end
                SHIFT_HIGH: if (tick) begin
                    shcp <= 1'b0;
                    if (bit_index == 7) begin
                        state <= LATCH_WAIT;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                        state     <= SHIFT_LOW;
                    end
                end
                LATCH_WAIT: if (tick) begin
                    stcp  <= 1'b1;
                    state <= LATCH_HIGH;
                end
                LATCH_HIGH: if (tick) begin
                    stcp  <= 1'b0;
                    state <= LATCH_RECOVER;
                end
                LATCH_RECOVER: if (tick) begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
                default: begin
                    state <= RESET_HOLD;
                    count <= 0;
                    shcp  <= 1'b0;
                    stcp  <= 1'b0;
                    mr_n  <= 1'b0;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
