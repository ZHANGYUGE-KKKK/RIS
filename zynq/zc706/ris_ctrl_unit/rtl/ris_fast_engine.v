`timescale 1ns/1ps
`default_nettype none

// Uniform 400-output square wave. 300 MHz clock, programmable integer
// half-period of 30..150000000 clocks (5 MHz..1 Hz complete cycles).
// Eight 100 MHz SHCP pulses precede every STCP. No use of OE as a logic zero.
// SHCP D1/D2 form 111000 at 600 Mbit/s: both pulse widths are 5 ns.
module ris_fast_engine (
    input wire clk, resetn,
    input wire request_toggle,
    input wire [3:0] request_mode,
    input wire [27:0] request_ticks,
    output reg acknowledged,
    output reg owned, running, level,
    output reg [3:0] mode,
    output reg [31:0] edges,
    output reg [31:0] edges_gray,
    output wire data, shift_d1, shift_d2, latch
);
    (* ASYNC_REG="TRUE" *) reg [1:0] req_sync;
    reg [3:0] mode_meta, mode_sync;
    reg [27:0] ticks_meta, ticks_sync, reload, remaining;
    reg [4:0] phase;
    reg target, stop_pending, command_token;
    reg [1:0] shift_phase;
    wire shifting=running && phase>=2 && phase<26;
    // Prepare the next uniform byte immediately after the previous latch,
    // leaving >5 ns setup even before the first SHCP of a new burst.
    assign data=running ? !level : level;
    assign shift_d1=shifting && shift_phase!=2;
    assign shift_d2=shifting && shift_phase==0;
    assign latch=running && phase>=27 && phase<30;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            req_sync<=0; mode_meta<=0; mode_sync<=0; acknowledged<=0; owned<=0; running<=0;
            level<=0; mode<=0; edges<=0; edges_gray<=0; phase<=0;
            ticks_meta<=30; ticks_sync<=30; reload<=29; remaining<=29;
            target<=0; stop_pending<=0; command_token<=0; shift_phase<=0;
        end else begin
            req_sync<={req_sync[0],request_toggle};
            mode_meta<=request_mode; mode_sync<=mode_meta;
            // Bundled data is held until the request/ack handshake completes.
            ticks_meta<=request_ticks; ticks_sync<=ticks_meta;
            if (running) begin
                if (phase==0) target<=!level;
                if (phase==1 || !shifting) shift_phase<=0;
                else if (shift_phase==2) shift_phase<=0;
                else shift_phase<=shift_phase+1'b1;
                if (phase==27) begin
                    level<=target; edges<=edges+1'b1;
                    edges_gray<=((edges+1'b1)>>1)^(edges+1'b1);
                end
                // Only the short burst decoder uses phase. The wide divider
                // counts the quiet interval without repeating SHCP/STCP.
                if (remaining==0) begin
                    phase<=0;
                    remaining<=reload;
                end else begin
                    remaining<=remaining-1'b1;
                    if (phase<30) phase<=phase+1'b1;
                end
                // Finish the current latch pulse, then stop promptly even at
                // 1 Hz; do not wait for a long quiet half-cycle to elapse.
                if (stop_pending && phase>=29) begin
                    running<=0; stop_pending<=0; target<=level;
                    acknowledged<=command_token;
                end
            end
            if (req_sync[1]!=command_token) begin
                command_token<=req_sync[1];
                if (mode_sync==0 && running) stop_pending<=1;
                else if (mode_sync==8 && !running) begin
                    owned<=0; mode<=0; acknowledged<=req_sync[1];
                end else if ((mode_sync==1 || mode_sync==3 || mode_sync==5 || mode_sync==9) && !running) begin
                    owned<=1; running<=1; level<=0; target<=0; phase<=0;
                    reload<=ticks_sync-1'b1; remaining<=ticks_sync-1'b1;
                    mode<=mode_sync; edges<=0; edges_gray<=0; shift_phase<=0;
                    stop_pending<=0; acknowledged<=req_sync[1];
                end else acknowledged<=req_sync[1];
            end
        end
    end
endmodule
`default_nettype wire
