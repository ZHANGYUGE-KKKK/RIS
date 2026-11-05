`timescale 1ns/1ps
`default_nettype none

// QAM1: dictionary + RLE events + 256 symbol descriptors + byte payload.
// All uploads/configuration are frozen from START acceptance through RELEASE.
// Bundled-data CDC: command/config/table contents settle before the two-flop
// request synchronizer, and remain immutable until the fast-domain ACK/status.
module ris_qam_player (
    input wire clk, resetn, fast_clk, fast_resetn, allow_start,
    input wire wr_valid,
    input wire [15:0] wr_addr, rd_addr,
    input wire [31:0] wr_data,
    input wire [3:0] wr_strb,
    output wire [1:0] wr_resp,
    output reg [31:0] rd_data,
    output reg [1:0] rd_resp,
    output wire blocked, busy_bus,
    output reg owned, running,
    output wire [49:0] data,
    output wire shift_d1, shift_d2, latch
);
    localparam MIN_TICKS=60; // 200 ns per slot; eight 100 MHz SHCP pulses.
    localparam IDLE=0, VD_WAIT=1, VD_CHECK=2, VE_WAIT=3, VE_CHECK=4,
               FP_WAIT=5, FP_CHECK=6, FD_WAIT=7, FD_CHECK=8,
               FE_WAIT=9, FE_CHECK=10, FF_WAIT=11, FF_CHECK=12, READY=13, VD_W2=14, VD_W3=15, VE_W2=16, VE_W3=17,
               FP_W2=18, FD_W2=19, FE_W2=20, FF_W2=21;
    reg mode64;
    reg request_toggle;
    reg [3:0] command;
    reg [31:0] slot_ticks, repeats;
    reg [15:0] period_slots;
    reg [11:0] frame_count;
    reg [3:0] frame_bank;
    reg [15:0] event_count;
    reg [8:0] symbol_count;
    reg [12:0] payload_count;
    (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync, owned_sync, running_sync, busy_sync;
    (* ASYNC_REG="TRUE" *) reg [7:0] error_meta, error_sync;
    reg acknowledged, busy;
    reg [7:0] error_code;
    reg [399:0] held_frame;
    wire pending=request_toggle!=ack_sync[1];
    assign blocked=pending || owned_sync[1] || busy_sync[1];
    assign busy_bus=pending || busy_sync[1] || running_sync[1];
    wire writable=!blocked;
    wire config_ok=(wr_addr==16'h0208 && ((mode64 && wr_data==1) || wr_data>=MIN_TICKS) && wr_data<=1000000) ||
                   (wr_addr==16'h020c && wr_data>=1 && wr_data<=1000000) ||
                   (wr_addr==16'h0210 && wr_data>=1 && wr_data<=65535);
    wire mode_ok=wr_addr==16'h0250 && (wr_data==0 || wr_data==64);
    wire upload_ok=(wr_addr==16'h0240 && frame_count<2048 &&
                        (frame_bank!=12 || wr_data[31:16]==0)) ||
                   (wr_addr==16'h0244 && event_count<32768) ||
                   (wr_addr==16'h0248 && symbol_count<256) ||
                   (wr_addr==16'h024c && payload_count<4096 && wr_data<256);
    wire start_ok=(wr_data==1 || wr_data==2) && writable && allow_start &&
                  frame_count!=0 && frame_bank==0 && event_count!=0 &&
                  symbol_count==256 && payload_count!=0 && (mode64 ? slot_ticks==1 : slot_ticks>=MIN_TICKS);
    wire command_ok=wr_addr==16'h0204 && !pending &&
                   (start_ok || wr_data==0 ||
                    (wr_data==8 && !busy_sync[1] && !running_sync[1]) ||
                    (wr_data==16 && writable));
    assign wr_resp=resetn && wr_strb==15 &&
                    (command_ok || (writable && (config_ok || upload_ok || mode_ok))) ? 0 : 2;
    wire fire=wr_valid && wr_resp==0;

    // True dual-clock synchronous memories. Thirteen 32-bit frame banks avoid
    // read/modify/write logic and provide the entire 400-bit vector in one read.
    reg [10:0] frame_address;
    wire [415:0] frame_read;
    reg [14:0] event_address;
    reg [7:0] symbol_address;
    reg [11:0] payload_address;
    reg [31:0] event_read, symbol_read, event_raw, symbol_raw;
    reg [7:0] payload_read,payload_raw;
    (* ram_style="block" *) reg [31:0] event_ram[0:32767];
    (* ram_style="block" *) reg [31:0] symbol_ram[0:255];
    (* ram_style="block" *) reg [7:0] payload_ram[0:4095];
    reg frame_we,event_we,symbol_we,payload_we;
    reg [10:0] frame_wa;
    reg [3:0] frame_wbank;
    reg [14:0] event_wa;
    reg [7:0] symbol_wa;
    reg [11:0] payload_wa;
    reg [31:0] upload_data;
    // Registered write controls keep asynchronous-reset bus logic off BRAM pins.
    always @(posedge clk) begin
        frame_we<=resetn && fire && wr_addr==16'h0240;
        event_we<=resetn && fire && wr_addr==16'h0244;
        symbol_we<=resetn && fire && wr_addr==16'h0248;
        payload_we<=resetn && fire && wr_addr==16'h024c;
        frame_wa<=frame_count[10:0];frame_wbank<=frame_bank;
        event_wa<=event_count[14:0];symbol_wa<=symbol_count[7:0];
        payload_wa<=payload_count[11:0];upload_data<=wr_data;
        if(event_we) event_ram[event_wa]<=upload_data;
        if(symbol_we) symbol_ram[symbol_wa]<=upload_data;
        if(payload_we) payload_ram[payload_wa]<=upload_data[7:0];
    end
    always @(posedge fast_clk) begin
        event_raw<=event_ram[event_address];event_read<=event_raw;
        symbol_raw<=symbol_ram[symbol_address];symbol_read<=symbol_raw;
        payload_raw<=payload_ram[payload_address];payload_read<=payload_raw;
    end
    genvar bank;
    generate for(bank=0;bank<13;bank=bank+1) begin: frames
        (* ram_style="block" *) reg [31:0] ram[0:2047];
        reg [31:0] value,raw;
        always @(posedge clk)
            if(frame_we && frame_wbank==bank) ram[frame_wa]<=upload_data;
        always @(posedge fast_clk) begin raw<=ram[frame_address];value<=raw;end
        assign frame_read[bank*32+:32]=value;
    end endgenerate

    always @(posedge clk or negedge resetn) begin
        if(!resetn) begin
            mode64<=0;request_toggle<=0;command<=0;slot_ticks<=MIN_TICKS;repeats<=3;period_slots<=256;
            frame_count<=0;frame_bank<=0;event_count<=0;symbol_count<=0;payload_count<=0;
            ack_sync<=0;owned_sync<=0;running_sync<=0;busy_sync<=0;error_meta<=0;error_sync<=0;
        end else begin
            ack_sync<={ack_sync[0],acknowledged};owned_sync<={owned_sync[0],owned};
            running_sync<={running_sync[0],running};busy_sync<={busy_sync[0],busy};
            error_meta<=error_code;error_sync<=error_meta;
            if(fire) case(wr_addr)
                16'h0204: if(wr_data==16) begin
                    mode64<=0;slot_ticks<=MIN_TICKS;
                    frame_count<=0;frame_bank<=0;event_count<=0;symbol_count<=0;payload_count<=0;
                end else begin command<=wr_data[3:0];request_toggle<=!request_toggle;end
                16'h0250: mode64<=wr_data==64;
                16'h0208: slot_ticks<=wr_data;
                16'h020c: repeats<=wr_data;
                16'h0210: period_slots<=wr_data[15:0];
                16'h0240: if(frame_bank==12) begin frame_bank<=0;frame_count<=frame_count+1'b1;end
                            else frame_bank<=frame_bank+1'b1;
                16'h0244: event_count<=event_count+1'b1;
                16'h0248: symbol_count<=symbol_count+1'b1;
                16'h024c: payload_count<=payload_count+1'b1;
                default: begin end
            endcase
        end
    end

    reg [399:0] held_meta,held_snapshot;
    always @(posedge clk) begin held_meta<=held_frame;held_snapshot<=held_meta;end
    // held_frame is stable after STOP/one-shot completion and before RELEASE.
    // Software must poll running/busy/pending=0 before reading its 13 words.
    always @* begin
        rd_data=0;rd_resp=0;
        case(rd_addr)
            16'h0200: rd_data=32'h51414d31;
            16'h0204: rd_data={28'b0,command};
            16'h0208: rd_data=slot_ticks;
            16'h020c: rd_data=repeats;
            16'h0210: rd_data={16'b0,period_slots};
            16'h0214: rd_data={27'b0,(error_sync!=0),pending,busy_sync[1],running_sync[1],owned_sync[1]};
            16'h0218: rd_data={24'b0,error_sync};
            16'h021c: rd_data=MIN_TICKS;
            16'h0220: rd_data={16'b0,frame_bank,frame_count};
            16'h0224: rd_data={16'b0,event_count};
            16'h0228: rd_data={23'b0,symbol_count};
            16'h022c: rd_data={19'b0,payload_count};
            16'h0230: rd_data=2048;
            16'h0234: rd_data=32768;
            16'h0238: rd_data=4096;
            16'h023c: rd_data=300000000;
            16'h0250: rd_data=mode64 ? 64 : 256;
            16'h0254: rd_data=32'h51413634; // QA64 additive timing capability
            16'h0258: rd_data=29;
            default: if(rd_addr>=16'h0280 && rd_addr<=16'h02b0 && rd_addr[1:0]==0) begin
                if(rd_addr==16'h02b0) rd_data={16'b0,held_snapshot[399:384]};
                else rd_data=held_snapshot[(rd_addr-16'h0280)*8+:32];
            end else rd_resp=3;
        endcase
    end

    (* ASYNC_REG="TRUE" *) reg [1:0] request_sync;
    reg [4:0] state;
    reg mode64_meta,mode64_fast;
    reg loop_mode, stop_pending, launching, next_valid, next_last;
    reg [7:0] validate_symbol;
    reg [15:0] validate_left;
    reg [16:0] validate_sum;
    reg [16:0] descriptor_end,event_sum;
    reg event_bad;
    reg [19:0] ticks_meta,ticks_fast,repeats_meta,repeats_fast;
    reg [15:0] slots_meta,slots_fast,event_count_meta,event_count_fast;
    reg [11:0] frame_count_meta,frame_count_fast;
    reg [12:0] payload_count_meta,payload_count_fast;
    // Data snapshots follow the same two-flop guard as the command toggle.
    // Configuration and upload counts cannot change while the player is busy.
    always @(posedge fast_clk) begin
        mode64_meta<=mode64;mode64_fast<=mode64_meta;
        ticks_meta<=slot_ticks;ticks_fast<=ticks_meta;
        repeats_meta<=repeats;repeats_fast<=repeats_meta;
        slots_meta<=period_slots;slots_fast<=slots_meta;
        event_count_meta<=event_count;event_count_fast<=event_count_meta;
        frame_count_meta<=frame_count;frame_count_fast<=frame_count_meta;
        payload_count_meta<=payload_count;payload_count_fast<=payload_count_meta;
        descriptor_end<={1'b0,symbol_read[15:0]}+{1'b0,symbol_read[31:16]};
        event_sum<=validate_sum+event_read[31:16];
        event_bad<=event_read[15:0]>=frame_count_fast || event_read[31:16]==0 || (mode64_fast && event_read[31:16]<29);
    end
    reg [15:0] current_index, current_first;
    reg [16:0] current_end;
    reg [19:0] current_repeat;
    reg [11:0] current_payload;
    reg [15:0] next_index,next_first,next_slots;
    reg [16:0] next_end;
    reg [19:0] next_repeat;
    reg [11:0] next_payload;
    reg [399:0] current_frame,next_frame;
    reg [19:0] ticks_left;
    reg [15:0] slots_left;
    reg [5:0] phase;
    reg [1:0] bit_phase;
    reg [2:0] bit_index;
    wire shifting=owned && running && phase>=2 && phase<26;
    assign shift_d1=shifting && bit_phase!=2;
    assign shift_d2=shifting && bit_phase==0;
    assign latch=owned && running && phase>=27 && phase<30;
    genvar lane;
    generate for(lane=0;lane<50;lane=lane+1) begin: lanes
        assign data[lane]=running ? current_frame[lane*8+bit_index] : held_frame[lane*8];
    end endgenerate

    // Issue the next fetch as soon as a vector starts shifting. Its worst-case
    // payload->descriptor->event->frame path is 12 cycles, below MIN_TICKS.
    task prefetch;
        input [15:0] index,first;
        input [16:0] ending;
        input [19:0] rep;
        input [11:0] pos;
        begin
            next_valid<=0;next_last<=0;
            next_first<=first;next_end<=ending;next_repeat<=rep;next_payload<=pos;
            if({1'b0,index}+1<ending) begin
                next_index<=index+1'b1;event_address<=index[14:0]+1'b1;state<=FE_WAIT;
            end else if(rep+1<repeats_fast) begin
                next_index<=first;next_repeat<=rep+1'b1;event_address<=first[14:0];state<=FE_WAIT;
            end else if({1'b0,pos}+1<payload_count_fast || loop_mode) begin
                if({1'b0,pos}+1<payload_count_fast) begin
                    next_payload<=pos+1'b1;payload_address<=pos+1'b1;
                end else begin next_payload<=0;payload_address<=0;end
                next_repeat<=0;state<=FP_WAIT;
            end else begin next_last<=1;next_valid<=1;state<=READY;end
        end
    endtask

    always @(posedge fast_clk) begin
        if(!fast_resetn) begin
            request_sync<=0;acknowledged<=0;owned<=0;running<=0;busy<=0;error_code<=0;
            state<=IDLE;loop_mode<=0;stop_pending<=0;launching<=0;next_valid<=0;next_last<=0;
            frame_address<=0;event_address<=0;symbol_address<=0;payload_address<=0;
            validate_symbol<=0;validate_left<=0;validate_sum<=0;
            current_index<=0;current_first<=0;current_end<=0;current_repeat<=0;current_payload<=0;
            next_index<=0;next_first<=0;next_end<=0;next_repeat<=0;next_payload<=0;next_slots<=0;
            held_frame<=0;current_frame<=0;next_frame<=0;ticks_left<=0;slots_left<=0;
            phase<=30;bit_phase<=0;bit_index<=7;
        end else begin
            request_sync<={request_sync[0],request_toggle};
            if(request_sync[1]!=acknowledged) begin
                acknowledged<=request_sync[1];
                if(command==0) begin
                    if(running) stop_pending<=1;
                    else begin busy<=0;state<=IDLE;end
                end else if(command==8 && !running) begin owned<=0;busy<=0;state<=IDLE;end
                else if((command==1 || command==2) && !owned && !busy) begin
                    busy<=1;error_code<=0;stop_pending<=0;loop_mode<=command==2;
                    symbol_address<=0;validate_symbol<=0;state<=VD_WAIT;
                end
            end else begin
                case(state)
                    VD_WAIT: state<=VD_W2;
                    VD_W2: state<=VD_W3;VD_W3: state<=VD_CHECK;
                    VD_CHECK: begin
                        if(symbol_read[31:16]==0 ||
                           descriptor_end>{1'b0,event_count_fast}) begin
                            error_code<=1;busy<=0;state<=IDLE;
                        end else begin
                            validate_left<=symbol_read[31:16];validate_sum<=0;
                            event_address<=symbol_read[14:0];state<=VE_WAIT;
                        end
                    end
                    VE_WAIT: state<=VE_W2;
                    VE_W2: state<=VE_W3;VE_W3: state<=VE_CHECK;
                    VE_CHECK: begin
                        if(event_bad) begin
                            error_code<=2;busy<=0;state<=IDLE;
                        end else if(event_sum>slots_fast ||
                                    (validate_left==1 && event_sum!=slots_fast)) begin
                            error_code<=3;busy<=0;state<=IDLE;
                        end else if(validate_left!=1) begin
                            validate_sum<=event_sum;validate_left<=validate_left-1'b1;
                            event_address<=event_address+1'b1;state<=VE_WAIT;
                        end else if(validate_symbol!=255) begin
                            validate_symbol<=validate_symbol+1'b1;symbol_address<=validate_symbol+1'b1;
                            state<=VD_WAIT;
                        end else begin
                            launching<=1;next_payload<=0;next_repeat<=0;payload_address<=0;state<=FP_WAIT;
                        end
                    end
                    FP_WAIT: state<=FP_W2;FP_W2: state<=FP_CHECK;
                    FP_CHECK: begin symbol_address<=payload_read;state<=FD_WAIT;end
                    FD_WAIT: state<=FD_W2;FD_W2: state<=FD_CHECK;
                    FD_CHECK: begin
                        next_first<=symbol_read[15:0];next_index<=symbol_read[15:0];
                        next_end<={1'b0,symbol_read[15:0]}+{1'b0,symbol_read[31:16]};
                        event_address<=symbol_read[14:0];state<=FE_WAIT;
                    end
                    FE_WAIT: state<=FE_W2;FE_W2: state<=FE_CHECK;
                    FE_CHECK: begin
                        next_slots<=event_read[31:16];frame_address<=event_read[10:0];state<=FF_WAIT;
                    end
                    FF_WAIT: state<=FF_W2;FF_W2: state<=FF_CHECK;
                    FF_CHECK: begin
                        next_frame<=frame_read[399:0];next_valid<=1;next_last<=0;state<=READY;
                        if(launching) begin
                            launching<=0;owned<=1;running<=1;busy<=0;phase<=0;bit_phase<=0;bit_index<=7;
                            current_frame<=frame_read[399:0];slots_left<=next_slots-1'b1;ticks_left<=ticks_fast-1'b1;
                            current_index<=next_index;current_first<=next_first;current_end<=next_end;
                            current_repeat<=next_repeat;current_payload<=next_payload;
                            prefetch(next_index,next_first,next_end,next_repeat,next_payload);
                        end
                    end
                    default: begin end
                endcase
            end
            if(running) begin
                    if(phase<30) phase<=phase+1'b1;
                    if(phase>=2 && phase<26) begin
                        // Advance DS while SHCP is low, a full fast clock
                        // before the next rising edge after the matched IOB
                        // pipeline. Advancing at phase 2 would give zero setup.
                        if(bit_phase==1 && bit_index!=0)bit_index<=bit_index-1'b1;
                        if(bit_phase==2) begin bit_phase<=0;end
                        else bit_phase<=bit_phase+1'b1;
                    end
                    if(phase==27) held_frame<=current_frame;
                    if((stop_pending || (request_sync[1]!=acknowledged && command==0)) && phase>=(mode64_fast ? 28 : 30)) begin
                        running<=0;stop_pending<=0;state<=IDLE;next_valid<=0;
                    end else if(ticks_left!=0) ticks_left<=ticks_left-1'b1;
                    else if(slots_left!=0) begin slots_left<=slots_left-1'b1;ticks_left<=ticks_fast-1'b1;end
                    else if(!next_valid) begin
                        error_code<=4;running<=0;state<=IDLE; // Never stretch a missed event.
                    end else if(next_last) begin running<=0;state<=IDLE;end
                    else begin
                        phase<=0;bit_phase<=0;bit_index<=7;current_frame<=next_frame;
                        ticks_left<=ticks_fast-1'b1;slots_left<=next_slots-1'b1;
                        current_index<=next_index;current_first<=next_first;current_end<=next_end;
                        current_repeat<=next_repeat;current_payload<=next_payload;
                        prefetch(next_index,next_first,next_end,next_repeat,next_payload);
                    end
            end
        end
    end
endmodule
`default_nettype wire
