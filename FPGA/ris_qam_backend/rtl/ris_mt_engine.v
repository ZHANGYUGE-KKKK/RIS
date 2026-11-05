`timescale 1ns/1ps
`default_nettype none
// Uniform MT segment player. RAM is written only while neither engine owns
// the pins. Configuration is bundled with the request/ack toggle handshake.
// Each RAM word is {level, duration[30:0]}; a segment lasts >=30 clocks.
module ris_mt_engine (
    input wire clk, resetn, request_toggle,
    input wire [3:0] request_mode,
    input wire [11:0] configured_count,
    input wire [10:0] configured_loop_start,
    input wire [30:0] configured_delay,
    output reg [10:0] ram_address,
    input wire [31:0] ram_data,
    output reg acknowledged, owned, running, level,
    output reg [31:0] edges_gray,
    output wire data, shift_d1, shift_d2, latch
);
    (* ASYNC_REG="TRUE" *) reg [1:0] req_sync;
    reg token, stop_pending, looping, active;
    reg [3:0] mode_meta, mode_sync;
    reg [11:0] count_meta, count_sync, count;
    reg [10:0] loop_meta, loop_sync, loop_start, index, last_index;
    reg [10:0] following, after_following;
    reg is_last;
    reg [30:0] delay_meta, delay_sync, delay_left, remaining;
    reg [31:0] current_word, next_word, edges;
    reg [3:0] setup;
    reg [4:0] phase;
    reg [1:0] shift_phase;
    wire shifting=active && running && phase>=2 && phase<26;
    assign data=active && running ? current_word[31] : level;
    assign shift_d1=shifting && shift_phase!=2;
    assign shift_d2=shifting && shift_phase==0;
    assign latch=active && running && phase>=27 && phase<30;

    always @(posedge clk) begin
        if (!resetn) begin
            req_sync<=0; token<=0; acknowledged<=0; owned<=0; running<=0;
            level<=0; edges<=0; edges_gray<=0; stop_pending<=0; looping<=0;
            mode_meta<=0;mode_sync<=0;count_meta<=0;count_sync<=0;count<=0;
            loop_meta<=0;loop_sync<=0;loop_start<=0;index<=0;last_index<=0;
            following<=0;after_following<=0;is_last<=0;
            delay_meta<=0;delay_sync<=0;delay_left<=0;remaining<=0;
            current_word<=30;next_word<=30;setup<=0;phase<=0;shift_phase<=0;
            ram_address<=0;active<=0;
        end else begin
            req_sync<={req_sync[0],request_toggle};
            mode_meta<=request_mode;mode_sync<=mode_meta;
            count_meta<=configured_count;count_sync<=count_meta;
            loop_meta<=configured_loop_start;loop_sync<=loop_meta;
            delay_meta<=configured_delay;delay_sync<=delay_meta;
            // Prepare addresses over spare burst clocks, rather than chaining
            // two add/compare/mux operations on the 300 MHz segment boundary.
            is_last<=index==last_index;
            following<=is_last ? loop_start : index+11'd1;
            after_following<=following==last_index ? loop_start : following+11'd1;
            if (running) begin
                if (setup!=0) begin
                    setup<=setup-1'b1;
                    if (setup==4) begin
                        current_word<=ram_data;
                        ram_address<=count>1 ? 11'd1 : loop_start;
                    end
                    if (setup==1) begin
                        next_word<=ram_data;
                        if (delay_left==0) begin
                            active<=1; phase<=0;remaining<=current_word[30:0]-1'b1;
                        end
                    end
                end else if (!active) begin
                    if (delay_left<=1) begin
                        delay_left<=0;active<=1;phase<=0;
                        remaining<=current_word[30:0]-1'b1;
                    end else delay_left<=delay_left-1'b1;
                end else begin
                    if (phase==1 || !shifting) shift_phase<=0;
                    else if (shift_phase==2) shift_phase<=0;
                    else shift_phase<=shift_phase+1'b1;
                    if (phase==4) next_word<=ram_data;
                    if (phase==27) begin
                        level<=current_word[31];
                        if (level!=current_word[31]) begin
                            edges<=edges+1'b1;
                            edges_gray<=((edges+1'b1)>>1)^(edges+1'b1);
                        end
                    end
                    if (remaining==0) begin
                        if (!looping && is_last) begin
                            running<=0;active<=0;
                        end else begin
                            current_word<=next_word;remaining<=next_word[30:0]-1'b1;
                            index<=following;ram_address<=after_following;phase<=0;
                        end
                    end else begin
                        remaining<=remaining-1'b1;
                        if (phase<30) phase<=phase+1'b1;
                    end
                end
                if (stop_pending && (!active || phase>=29)) begin
                    running<=0;active<=0;stop_pending<=0;acknowledged<=token;
                end
            end
            if (req_sync[1]!=token) begin
                token<=req_sync[1];
                if (mode_sync==0 && running) stop_pending<=1;
                else if (mode_sync==8 && !running) begin
                    owned<=0;acknowledged<=req_sync[1];
                end else if ((mode_sync==10 || mode_sync==11) && !running) begin
                    owned<=1;running<=1;active<=0;level<=0;index<=0;
                    count<=count_sync;last_index<=count_sync-1'b1;loop_start<=loop_sync;delay_left<=delay_sync;
                    looping<=mode_sync==11;setup<=7;ram_address<=0;
                    edges<=0;edges_gray<=0;stop_pending<=0;phase<=0;shift_phase<=0;
                    acknowledged<=req_sync[1];
                end else acknowledged<=req_sync[1];
            end
        end
    end
endmodule
`default_nettype wire
