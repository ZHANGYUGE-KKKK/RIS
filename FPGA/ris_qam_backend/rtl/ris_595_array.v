`timescale 1ns/1ps
`default_nettype none

// Fifty data lanes, ten clock pairs. All internal logic uses clk, never SHCP.
module ris_595_array (
    input wire clk, resetn, start,
    input wire [399:0] frame,
    input wire [49:0] mask,
    input wire [15:0] half_cycles, guard_cycles, latch_cycles, recovery_cycles,
    output wire ready, busy,
    output reg done, fault,
    output wire [3:0] state_out,
    output wire [399:0] image,
    output wire [49:0] data,
    output wire [9:0] shcp, stcp
);
    localparam IDLE=0, LOW_PHASE=1, HIGH_PHASE=2, GUARD=3, LATCH=4, RECOVER=5;
    // Keep the explicit invalid-state detector meaningful after synthesis.
    (* fsm_encoding="none" *) reg [3:0] state;
    reg [15:0] count;
    reg [2:0] bit_index;
    reg [9:0] groups;
    reg shift_level, latch_level;
    wire [9:0] requested_groups;
    wire accept = start && ready;
    wire shift_tick = count == half_cycles-1;
    wire latch_event = state==GUARD && count==guard_cycles-1;
    wire advance = state==HIGH_PHASE && shift_tick && bit_index!=7;
    assign ready = resetn && state==IDLE;
    assign busy = !ready;
    assign state_out = state;
    assign shcp = groups & {10{shift_level}};
    assign stcp = groups & {10{latch_level}};
    genvar g, c;
    generate
        for (g=0; g<10; g=g+1) begin: group_mask
            assign requested_groups[g] = |mask[g*5+:5];
        end
        for (c=0; c<50; c=c+1) begin: chip
            ris_595_byte u_byte (
                .clk(clk), .resetn(resetn),
                .load(accept && requested_groups[c/5]),
                .advance(advance && groups[c/5]),
                .latch(latch_event && groups[c/5]),
                .data_in(frame[c*8+:8]), .ds(data[c]),
                .latched_data(image[c*8+:8])
            );
        end
    endgenerate
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state<=IDLE; count<=0; bit_index<=0; groups<=0;
            shift_level<=0; latch_level<=0; done<=0; fault<=0;
        end else begin
            done<=0;
            case (state)
                IDLE: begin
                    count<=0;
                    if (accept) begin
                        groups<=requested_groups; bit_index<=0; state<=LOW_PHASE;
                    end
                end
                LOW_PHASE: if (shift_tick) begin
                    count<=0; shift_level<=1; state<=HIGH_PHASE;
                end else count<=count+1'b1;
                HIGH_PHASE: if (shift_tick) begin
                    count<=0; shift_level<=0;
                    if (bit_index==7) state<=GUARD;
                    else begin bit_index<=bit_index+1'b1; state<=LOW_PHASE; end
                end else count<=count+1'b1;
                GUARD: if (latch_event) begin
                    count<=0; latch_level<=1; state<=LATCH;
                end else count<=count+1'b1;
                LATCH: if (count==latch_cycles-1) begin
                    count<=0; latch_level<=0; state<=RECOVER;
                end else count<=count+1'b1;
                RECOVER: if (count==recovery_cycles-1) begin
                    count<=0; state<=IDLE; done<=1;
                end else count<=count+1'b1;
                default: begin state<=IDLE; shift_level<=0; latch_level<=0; fault<=1; end
            endcase
        end
    end
endmodule
`default_nettype wire
