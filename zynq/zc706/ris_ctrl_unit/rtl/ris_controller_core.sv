`timescale 1ns/1ps
`default_nettype none

// Command/mode engine. This peripheral bus is private to ris_axi4_slave.
module ris_controller_core #(
    parameter integer FRAME_SLOTS=256,
    parameter integer CMD_DEPTH=8,
    parameter integer RESULT_DEPTH=32,
    parameter integer BLOCK_DEPTH=16
) (
    input wire clk, resetn,
    input wire wr_valid,
    output wire wr_ready,
    input wire [15:0] wr_addr,
    input wire [31:0] wr_data,
    input wire [3:0] wr_strb,
    output reg [1:0] wr_resp,
    input wire [15:0] rd_addr,
    output reg [31:0] rd_data,
    output reg [1:0] rd_resp,
    output wire [49:0] ris_data,
    output wire [9:0] ris_shcp, ris_stcp,
    output wire ris_mr_n, ris_oe_n
);
    localparam RESET=0, INIT=1, IDLE=2, PREFILL=3, RUN=4,
               PAUSED=5, FINISH_FRAME=6, ERROR=7;
    localparam HOLD=0, SEQUENCE=1, STREAM=2;
    localparam APPLY=8'h01, CLEAR_ALL=8'h02, SET_MODE=8'h10, CONFIG_APPLY=8'h11,
               START=8'h20, PAUSE=8'h21, RESUME=8'h22, STOP_HOLD=8'h23,
               OUTPUT_ENABLE=8'h30, OUTPUT_DISABLE=8'h31,
               PUBLISH_BLOCK=8'h40, FLUSH_DATA=8'h41,
               CLEAR_ERROR=8'h50, SOFT_RESET=8'h7f;
    localparam EXECUTE=0, ISSUE=1, WAIT_TX=2, WAIT_SLOT=3;
    localparam TX_NONE=0, TX_INIT=1, TX_AUTO=2, TX_MANUAL=3;
    localparam DONE=32'h1, REJECTED=32'h2, CANCELLED=32'h3;
    localparam [49:0] ALL_CHIPS={50{1'b1}};
    localparam [49:0] VALID_BYTES={50{1'b1}};
    localparam SLOT_BOUND_WIDTH=(FRAME_SLOTS>1) ? $clog2(FRAME_SLOTS+1) : 1;

    typedef struct packed {
        logic [7:0] op;
        logic [1:0] flags;
        logic [31:0] id, arg0, arg1;
        logic [49:0] mask;
        logic [399:0] payload;
        logic [351:0] config_words;
    } command_t;
    command_t commands [0:CMD_DEPTH-1];
    command_t active;
    reg active_valid;
    reg [1:0] active_phase;
    reg [2:0] active_previous_state;
    reg data_barrier;
    localparam CMD_PTR_WIDTH=(CMD_DEPTH>1) ? $clog2(CMD_DEPTH) : 1;
    localparam RESULT_PTR_WIDTH=(RESULT_DEPTH>1) ? $clog2(RESULT_DEPTH) : 1;
    localparam BLOCK_PTR_WIDTH=(BLOCK_DEPTH>1) ? $clog2(BLOCK_DEPTH) : 1;
    localparam CREDIT_WIDTH=$clog2(RESULT_DEPTH+CMD_DEPTH+8);
    reg [CMD_PTR_WIDTH-1:0] cmd_head,cmd_tail;
    reg [$clog2(CMD_DEPTH+1)-1:0] cmd_count;
    reg [31:0] result_ids [0:RESULT_DEPTH-1];
    reg [31:0] result_codes [0:RESULT_DEPTH-1];
    reg [RESULT_PTR_WIDTH-1:0] result_head,result_tail;
    reg [$clog2(RESULT_DEPTH+1)-1:0] result_count;
    reg event_valid;
    reg [31:0] event_id, event_code;

    reg [31:0] op_shadow, id_shadow, arg0_shadow, arg1_shadow;
    reg [49:0] mask_shadow;
    reg [399:0] frame_shadow;
    reg [351:0] config_shadow, config_active;
    reg [31:0] last_accepted;
    reg [2:0] state, resume_state;
    reg [1:0] mode;
    reg initialized, output_requested, mr_level;
    reg [31:0] error_flags, reset_epoch;
    reg [63:0] frame_count, error_frame;
    reg [31:0] countdown;
    reg cycle_started;
    reg [31:0] seq_cursor;
    reg seq_end_pending;

    // Only writes to FREE slots are permitted; published storage is immutable.
    wire [31:0] memory_bus_data, memory_play_data;
    reg [49:0] slot_written [0:FRAME_SLOTS-1];
    reg [FRAME_SLOTS-1:0] sequence_owned, stream_owned;
    reg [31:0] block_base [0:BLOCK_DEPTH-1];
    reg [31:0] block_length [0:BLOCK_DEPTH-1];
    reg [BLOCK_PTR_WIDTH-1:0] block_head,block_tail;
    reg [$clog2(BLOCK_DEPTH+1)-1:0] block_count;
    reg [31:0] block_offset, stream_frames;
    reg [1:0] prefetch_state;
    reg [3:0] prefetch_word;
    reg [31:0] prefetch_slot;
    reg [399:0] prefetched_frame;

    reg control_valid;
    reg [7:0] control_op;
    reg [31:0] control_id, control_argument;
    reg [2:0] control_previous_state;
    reg reset_pending, reset_completion;
    reg [31:0] reset_id;
    reg displaced_valid;
    reg [31:0] displaced_id;
    reg [2:0] init_phase;
    reg [3:0] init_count;

    wire [31:0] period=config_active[0+:32];
    wire [49:0] dynamic_mask={config_active[64+:18],config_active[32+:32]};
    wire [31:0] sequence_base=config_active[96+:32];
    wire [31:0] sequence_count=config_active[128+:32];
    wire sequence_loop=config_active[160];
    wire [31:0] prefill_frames=config_active[192+:32];
    wire [15:0] half_cycles=config_active[224+:16];
    wire [15:0] guard_cycles=config_active[256+:16];
    wire [15:0] latch_cycles=config_active[288+:16];
    wire [15:0] recovery_cycles=config_active[320+:16];

    function automatic [351:0] default_config;
        reg [351:0] v;
        begin
            v=0; v[0+:32]=1000; v[32+:32]=32'hffffffff;
            v[64+:32]=32'h0003ffff; v[192+:32]=1;
            v[224+:32]=5; v[256+:32]=5; v[288+:32]=5; v[320+:32]=5;
            default_config=v;
        end
    endfunction
    function automatic [31:0] merge_bytes;
        input [31:0] old_value, new_value;
        input [3:0] strobe;
        integer b;
        begin
            merge_bytes=old_value;
            for (b=0;b<4;b=b+1)
                if (strobe[b]) merge_bytes[b*8+:8]=new_value[b*8+:8];
        end
    endfunction
    function automatic config_valid;
        input [351:0] v;
        reg [20:0] minimum_period;
        reg [SLOT_BOUND_WIDTH:0] configured_end;
        begin
            configured_end={1'b0,v[96+:SLOT_BOUND_WIDTH]}+{1'b0,v[128+:SLOT_BOUND_WIDTH]};
            minimum_period=16*{17'b0,v[224+:16]}+{17'b0,v[256+:16]}+
                           {17'b0,v[288+:16]}+{17'b0,v[320+:16]}+8;
            // Thirteen synchronous BRAM words plus prefetch setup/hand-off.
            if (minimum_period<28) minimum_period=28;
            config_valid=(v[82+:14]==0 && v[32+:50]!=0 &&
                v[224+:32]!=0 && v[240+:16]==0 &&
                v[256+:32]!=0 && v[272+:16]==0 &&
                v[288+:32]!=0 && v[304+:16]==0 &&
                v[320+:32]!=0 && v[336+:16]==0 &&
                {1'b0,v[0+:32]}>=minimum_period &&
                v[96+:32]<=FRAME_SLOTS && v[128+:32]<=FRAME_SLOTS && configured_end<=FRAME_SLOTS &&
                v[160+:32]<=1 && v[192+:32]>0 && v[192+:32]<=FRAME_SLOTS);
        end
    endfunction
    task automatic post_result(input [31:0] id, input [31:0] code);
        begin event_valid<=1; event_id<=id; event_code<=code; end
    endtask

    wire tx_ready, tx_busy, tx_done, array_fault;
    reg fatal_fault;
    wire [3:0] tx_state;
    wire [399:0] current_image;
    reg inflight;
    reg [1:0] tx_source;
    reg [31:0] tx_slot;
    reg tx_was_stream, tx_was_last;
    reg manual_finished;
    wire deadline=(!cycle_started || countdown==0);
    wire schedule_allowed=(state==RUN && !reset_pending && !control_valid &&
        !seq_end_pending &&
        (!active_valid || active_phase==WAIT_SLOT || active_phase==EXECUTE));
    wire insertion=active_valid && active_phase==WAIT_SLOT;
    wire init_launch=(state==INIT && init_phase==2 && !inflight && tx_ready);
    wire manual_launch=(active_valid && active_phase==ISSUE && !reset_pending &&
                        !control_valid && !inflight && tx_ready);
    wire automatic_launch=(schedule_allowed && deadline && !inflight && tx_ready &&
                           (insertion || prefetch_state==2));
    wire normal_launch=automatic_launch && !insertion;
    wire array_start=init_launch || manual_launch || automatic_launch;
    wire [49:0] array_mask=init_launch ? ALL_CHIPS :
        ((manual_launch || insertion) ? active.mask : dynamic_mask);
    wire [399:0] requested_frame=init_launch ? 400'b0 :
        ((manual_launch || insertion) ? active.payload : prefetched_frame);
    wire [399:0] array_frame;
    genvar lane;
    generate for (lane=0;lane<50;lane=lane+1) begin: merged_lane
        assign array_frame[lane*8+:8]=array_mask[lane] ?
            requested_frame[lane*8+:8] : current_image[lane*8+:8];
    end endgenerate
    ris_595_array u_array (
        .clk(clk), .resetn(resetn && !reset_pending), .start(array_start),
        .frame(array_frame), .mask(array_mask), .half_cycles(half_cycles),
        .guard_cycles(guard_cycles), .latch_cycles(latch_cycles),
        .recovery_cycles(recovery_cycles), .ready(tx_ready), .busy(tx_busy),
        .done(tx_done), .fault(array_fault), .state_out(tx_state), .image(current_image),
        .data(ris_data), .shcp(ris_shcp), .stcp(ris_stcp)
    );
    assign ris_mr_n=resetn && mr_level && !reset_pending;
    assign ris_oe_n=!(resetn && initialized && output_requested && !reset_pending);

    wire [7:0] submitted_op=op_shadow[7:0];
    wire [CREDIT_WIDTH-1:0] outstanding_credits=result_count+cmd_count+active_valid+
        control_valid+reset_pending+reset_completion+event_valid;
    wire [1:0] submitted_flags=op_shadow[9:8];
    wire normal_command=(submitted_op==APPLY || submitted_op==CLEAR_ALL ||
        submitted_op==CONFIG_APPLY || submitted_op==START ||
        submitted_op==RESUME || submitted_op==FLUSH_DATA);
    wire control_command=(submitted_op==SET_MODE || submitted_op==PAUSE ||
                          submitted_op==STOP_HOLD);
    wire immediate_command=(submitted_op==OUTPUT_ENABLE || submitted_op==OUTPUT_DISABLE ||
                            submitted_op==PUBLISH_BLOCK || submitted_op==CLEAR_ERROR);
    // Explicit parallel reductions avoid synthesis of a 256-stage priority chain
    // from the former procedural "if (...) ready=0" loop. Keep 16-slot group
    // boundaries so implementation cannot merge it back into a serial chain.
    localparam CHECK_GROUPS=(FRAME_SLOTS+15)/16;
    wire [SLOT_BOUND_WIDTH-1:0] publication_base=arg0_shadow[SLOT_BOUND_WIDTH-1:0];
    wire [SLOT_BOUND_WIDTH-1:0] checked_sequence_base=sequence_base[SLOT_BOUND_WIDTH-1:0];
    wire [SLOT_BOUND_WIDTH:0] publication_end={1'b0,publication_base}+
        {1'b0,arg1_shadow[SLOT_BOUND_WIDTH-1:0]};
    wire [SLOT_BOUND_WIDTH:0] sequence_end={1'b0,checked_sequence_base}+
        {1'b0,sequence_count[SLOT_BOUND_WIDTH-1:0]};
    wire [CHECK_GROUPS*16-1:0] publication_bad_slot, sequence_missing_slot;
    (* keep="true" *) wire [CHECK_GROUPS-1:0] publication_bad_group, sequence_missing_group;
    genvar check_slot, check_group;
    generate
        for (check_slot=0;check_slot<CHECK_GROUPS*16;check_slot=check_slot+1) begin: ownership_check
            if (check_slot<FRAME_SLOTS) begin
                assign publication_bad_slot[check_slot]=
                    check_slot>=publication_base && check_slot<publication_end &&
                    (sequence_owned[check_slot] || stream_owned[check_slot] ||
                     slot_written[check_slot]!=VALID_BYTES);
                assign sequence_missing_slot[check_slot]=
                    check_slot>=checked_sequence_base && check_slot<sequence_end && !sequence_owned[check_slot];
            end else begin
                assign publication_bad_slot[check_slot]=1'b0;
                assign sequence_missing_slot[check_slot]=1'b0;
            end
        end
        for (check_group=0;check_group<CHECK_GROUPS;check_group=check_group+1) begin: ownership_reduce
            assign publication_bad_group[check_group]=|publication_bad_slot[check_group*16+:16];
            assign sequence_missing_group[check_group]=|sequence_missing_slot[check_group*16+:16];
        end
    endgenerate
    // Full-width range guards preserve rejection of overflowing/aliased inputs;
    // valid slot arithmetic itself only needs the physical address width.
    wire publication_valid=arg1_shadow>0 && arg1_shadow<=FRAME_SLOTS && arg0_shadow<FRAME_SLOTS &&
        publication_end<=FRAME_SLOTS && !(|publication_bad_group);
    wire sequence_ready=sequence_count>0 && sequence_count<=FRAME_SLOTS && sequence_base<FRAME_SLOTS &&
        sequence_end<=FRAME_SLOTS && !(|sequence_missing_group);
    reg id_duplicate;
    integer i, j;
    always @* begin
        id_duplicate=(active_valid && active.id==id_shadow) ||
            (control_valid && control_id==id_shadow) ||
            ((reset_pending || reset_completion) && reset_id==id_shadow);
        for (integer k=0;k<CMD_DEPTH;k=k+1)
            if (k<cmd_count && commands[(cmd_head+k)%CMD_DEPTH].id==id_shadow)
                id_duplicate=1;
    end
    wire dispatch=(!event_valid && !reset_pending && !control_valid &&
        !reset_completion && !fatal_fault && !active_valid && cmd_count!=0);
    wire cancel_pop=(!event_valid && (reset_pending || control_valid || fatal_fault) &&
                     !active_valid && !displaced_valid && cmd_count!=0 &&
                     (reset_pending || fatal_fault || !inflight));
    wire engine_claim=(!event_valid && (reset_pending ||
        (reset_completion && initialized) ||
        (fatal_fault && (active_valid || control_valid || cmd_count!=0)) ||
        (control_valid && !inflight) ||
        (active_valid && ((active_phase==EXECUTE && !inflight) ||
                          (active_phase==WAIT_TX && manual_finished))) || dispatch));
    assign wr_ready=!event_valid && !engine_claim;
    wire write_fire=wr_valid && wr_ready;
    wire write_ok=write_fire && wr_resp==0;
    wire submit=write_ok && wr_addr==16'h0028;
    wire command_push=submit && normal_command;
    wire command_pop=dispatch || cancel_pop;
    wire result_pop=write_ok && wr_addr==16'h0038;
    wire publish_stream=submit && submitted_op==PUBLISH_BLOCK && submitted_flags==1;
    wire consume_stream=normal_launch && mode==STREAM;
    wire block_pop=consume_stream && block_offset+1==block_length[block_head];
    wire functional_clear=(reset_pending && !event_valid && !displaced_valid &&
                           !active_valid && cmd_count==0);
    wire [31:0] memory_word_address=(wr_addr-16'h1000)>>2;
    wire [31:0] memory_slot=(wr_addr-16'h1000)>>6;
    // Decode each bulk-data write locally. Feeding the complete command-response
    // mux into these enables creates a path from all 256 publication checks to
    // every RAM WE / staging byte, although COMMIT and data addresses are disjoint.
    wire memory_write=write_fire && wr_addr[1:0]==0 &&
        wr_addr>=16'h1000 && wr_addr<16'h1000+FRAME_SLOTS*64 &&
        !data_barrier && !sequence_owned[memory_slot] && !stream_owned[memory_slot];
    wire stage_write=write_fire && wr_addr[1:0]==0 &&
        wr_addr>=16'h0100 && wr_addr<16'h0140;
    wire configuration_write=write_fire && wr_addr[1:0]==0 &&
        wr_addr>=16'h0040 && wr_addr<=16'h0068;
    wire [49:0] written_byte_mask={46'b0,wr_strb} << wr_addr[5:0];
    wire clear_slot_flags=functional_clear || (!event_valid && !reset_pending &&
        !reset_completion && !control_valid && !fatal_fault && active_valid &&
        active_phase==EXECUTE && !inflight && active.op==FLUSH_DATA &&
        (state==IDLE || state==PAUSED));
    genvar slot;
    generate for (slot=0;slot<FRAME_SLOTS;slot=slot+1) begin: valid_slot
        always @(posedge clk or negedge resetn) begin
            if (!resetn) slot_written[slot]<=0;
            else if (clear_slot_flags) slot_written[slot]<=0;
            else if (tx_done && inflight && tx_source==TX_AUTO && tx_was_stream && tx_slot==slot)
                slot_written[slot]<=0;
            else if (memory_write && memory_slot==slot)
                slot_written[slot]<=slot_written[slot] | written_byte_mask;
        end
    end endgenerate
    // Synchronous address reset avoids asynchronous changes on BRAM read pins.
    always @(posedge clk) begin
        if (!resetn) begin prefetch_slot<=0; prefetch_word<=0; end
        else if (!reset_pending && !control_valid) begin
            if (prefetch_state==0 && (state==RUN || state==PREFILL) && !seq_end_pending) begin
                if (mode==SEQUENCE && sequence_owned[seq_cursor]) begin
                    prefetch_slot<=seq_cursor; prefetch_word<=0;
                end else if (mode==STREAM && block_count!=0) begin
                    prefetch_slot<=block_base[block_head]+block_offset; prefetch_word<=0;
                end
            end else if (prefetch_state==1 && prefetch_word!=12)
                prefetch_word<=prefetch_word+1'b1;
        end
    end
    localparam MEMORY_ADDR_WIDTH=$clog2(FRAME_SLOTS*16);
    wire [31:0] bus_word_address=(rd_addr-16'h1000)>>2;
    wire [31:0] play_word_address=prefetch_slot*16+prefetch_word;
    ris_frame_ram #(.WORDS(FRAME_SLOTS*16)) u_frames (
        .clk(clk),.resetn(resetn),.write_enable(memory_write),
        .write_address(memory_word_address[MEMORY_ADDR_WIDTH-1:0]),
        .bus_address(bus_word_address[MEMORY_ADDR_WIDTH-1:0]),
        .play_address(play_word_address[MEMORY_ADDR_WIDTH-1:0]),
        .write_data(wr_data),.write_strobe(wr_strb),
        .bus_data(memory_bus_data),.play_data(memory_play_data)
    );

    always @* begin
        wr_resp=0;
        if (wr_addr[1:0]!=0) wr_resp=2;
        else if (wr_addr>=16'h0100 && wr_addr<16'h0140) begin end
        else if (wr_addr>=16'h1000 && wr_addr<16'h1000+FRAME_SLOTS*64) begin
            if (data_barrier || sequence_owned[memory_slot] || stream_owned[memory_slot]) wr_resp=2;
        end else if (wr_addr>=16'h0040 && wr_addr<=16'h0068) begin end
        else case (wr_addr)
            16'h0010,16'h0014,16'h0018,16'h001c,16'h0020: begin end
            16'h0024: if (|(merge_bytes({14'b0,mask_shadow[49:32]},wr_data,wr_strb)&32'hfffc0000)) wr_resp=2;
            16'h0038: if (wr_strb!=15 || wr_data!=1 || result_count==0) wr_resp=2;
            16'h0028: begin
                if (wr_strb!=15 || wr_data!=1 || op_shadow[31:10]!=0 || id_duplicate ||
                    !(normal_command || control_command || immediate_command || submitted_op==SOFT_RESET)) wr_resp=2;
                if (submitted_op==SOFT_RESET || submitted_op==OUTPUT_DISABLE) begin
                    if (outstanding_credits>=RESULT_DEPTH-1) wr_resp=2;
                end else begin
                    if (outstanding_credits>=RESULT_DEPTH-4) wr_resp=2;
                    if (!initialized || reset_pending || reset_completion) wr_resp=2;
                end
                if (reset_pending || reset_completion) wr_resp=2;
                if (control_valid && submitted_op!=SOFT_RESET && submitted_op!=OUTPUT_DISABLE) wr_resp=2;
                if (submitted_op==APPLY) begin
                    if (submitted_flags>2 || mask_shadow==0) wr_resp=2;
                end else if (submitted_op==PUBLISH_BLOCK) begin
                    if (submitted_flags>1 || !publication_valid || data_barrier ||
                        (submitted_flags==1 && block_count==BLOCK_DEPTH)) wr_resp=2;
                end else if (submitted_flags!=0) wr_resp=2;
                if (normal_command && cmd_count==CMD_DEPTH) wr_resp=2;
                if (normal_command && state==ERROR) wr_resp=2;
                if (control_command && control_valid) wr_resp=2;
                if (submitted_op==SET_MODE && (arg0_shadow>2 || state==ERROR)) wr_resp=2;
                if (submitted_op==PAUSE && state!=RUN && state!=PREFILL) wr_resp=2;
                if (submitted_op==OUTPUT_ENABLE && !initialized) wr_resp=2;
                if (submitted_op==CLEAR_ERROR && inflight) wr_resp=2;
            end
            default: wr_resp=3;
        endcase
    end

    always @* begin
        rd_data=0; rd_resp=0;
        if (rd_addr[1:0]!=0) rd_resp=2;
        else if (rd_addr>=16'h0100 && rd_addr<16'h0140) begin
            if (rd_addr<16'h0130) rd_data=frame_shadow[(rd_addr-16'h0100)*8+:32];
            else if (rd_addr==16'h0130) rd_data={16'b0,frame_shadow[384+:16]};
        end else if (rd_addr>=16'h0140 && rd_addr<16'h0180) begin
            if (rd_addr<16'h0170) rd_data=current_image[(rd_addr-16'h0140)*8+:32];
            else if (rd_addr==16'h0170) rd_data={16'b0,current_image[384+:16]};
        end else if (rd_addr>=16'h1000 && rd_addr<16'h1000+FRAME_SLOTS*64)
            rd_data=memory_bus_data;
        else if (rd_addr>=16'h0040 && rd_addr<=16'h0068)
            rd_data=config_shadow[(rd_addr-16'h0040)*8+:32];
        else case (rd_addr)
            16'h0000: rd_data=32'h52495332;
            16'h0004: rd_data={20'b0,active_valid,prefetch_state==2,result_count!=0,
                cmd_count==CMD_DEPTH,!ris_oe_n,initialized,tx_busy,mode,state};
            16'h0008: rd_data={28'b0,tx_state};
            16'h000c: rd_data=error_flags;
            16'h0010: rd_data=op_shadow;
            16'h0014: rd_data=id_shadow;
            16'h0018: rd_data=arg0_shadow;
            16'h001c: rd_data=arg1_shadow;
            16'h0020: rd_data=mask_shadow[31:0];
            16'h0024: rd_data={14'b0,mask_shadow[49:32]};
            16'h002c: rd_data=last_accepted;
            16'h0030: rd_data=result_count!=0 ? result_ids[result_head] : 0;
            16'h0034: rd_data=result_count!=0 ? result_codes[result_head] : 0;
            16'h003c: begin
                rd_data[7:0]=cmd_count; rd_data[15:8]=result_count; rd_data[23:16]=block_count;
            end
            16'h006c: rd_data=frame_count[31:0];
            16'h0070: rd_data=frame_count[63:32];
            16'h0074: rd_data=error_frame[31:0];
            16'h0078: rd_data=error_frame[63:32];
            16'h007c: rd_data=period;
            16'h0080: rd_data=seq_cursor;
            16'h0084: rd_data=active_valid ? active.id : 0;
            16'h0088: rd_data=stream_frames;
            16'h008c: rd_data=FRAME_SLOTS;
            16'h0090: rd_data=reset_epoch;
            16'h0094: rd_data=dynamic_mask[31:0];
            16'h0098: rd_data={14'b0,dynamic_mask[49:32]};
            default: rd_resp=3;
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cmd_head<=0; cmd_tail<=0; cmd_count<=0; active<='0;
            active_valid<=0; active_phase<=EXECUTE;
            active_previous_state<=IDLE; data_barrier<=0;
            result_head<=0; result_tail<=0; result_count<=0;
            event_valid<=0; event_id<=0; event_code<=0;
            op_shadow<=0; id_shadow<=0; arg0_shadow<=0; arg1_shadow<=0;
            mask_shadow<=0; frame_shadow<=0;
            config_shadow<=default_config(); config_active<=default_config();
            last_accepted<=0; state<=RESET; mode<=HOLD; resume_state<=RUN;
            initialized<=0; output_requested<=0; mr_level<=0;
            error_flags<=0; error_frame<=0; frame_count<=0; reset_epoch<=0;
            countdown<=0; cycle_started<=0; seq_cursor<=0; seq_end_pending<=0;
            sequence_owned<=0; stream_owned<=0;
            block_head<=0; block_tail<=0; block_count<=0; block_offset<=0; stream_frames<=0;
            prefetch_state<=0; prefetched_frame<=0;
            control_valid<=0; control_op<=0; control_id<=0; control_argument<=0;
            control_previous_state<=IDLE; reset_pending<=0; reset_completion<=0;
            reset_id<=0; displaced_valid<=0; displaced_id<=0;
            init_phase<=0; init_count<=0; inflight<=0; tx_source<=TX_NONE;
            tx_slot<=0; tx_was_stream<=0; tx_was_last<=0; manual_finished<=0;
            fatal_fault<=0;
        end else begin
            // A reserved completion credit exists for every accepted command.
            if (event_valid) begin
                result_ids[result_tail]<=event_id; result_codes[result_tail]<=event_code;
                result_tail<=(result_tail==RESULT_DEPTH-1) ? 0 : result_tail+1;
                event_valid<=0;
            end
            if (result_pop) result_head<=(result_head==RESULT_DEPTH-1) ? 0 : result_head+1;
            case ({event_valid,result_pop})
                2'b10: result_count<=result_count+1;
                2'b01: result_count<=result_count-1;
                default: begin end
            endcase
            if (command_push) begin
                commands[cmd_tail]<='{op:submitted_op,flags:submitted_flags,id:id_shadow,
                    arg0:arg0_shadow,arg1:arg1_shadow,mask:mask_shadow,
                    payload:frame_shadow,config_words:config_shadow};
                cmd_tail<=(cmd_tail==CMD_DEPTH-1) ? 0 : cmd_tail+1;
            end
            if (command_pop) cmd_head<=(cmd_head==CMD_DEPTH-1) ? 0 : cmd_head+1;
            case ({command_push,command_pop})
                2'b10: cmd_count<=cmd_count+1;
                2'b01: cmd_count<=cmd_count-1;
                default: begin end
            endcase
            if (publish_stream) begin
                block_base[block_tail]<=arg0_shadow; block_length[block_tail]<=arg1_shadow;
                block_tail<=(block_tail==BLOCK_DEPTH-1) ? 0 : block_tail+1;
            end
            if (consume_stream) begin
                if (block_pop) begin
                    block_head<=(block_head==BLOCK_DEPTH-1) ? 0 : block_head+1;
                    block_offset<=0;
                end else block_offset<=block_offset+1;
            end
            case ({publish_stream,block_pop})
                2'b10: block_count<=block_count+1;
                2'b01: block_count<=block_count-1;
                default: begin end
            endcase
            case ({publish_stream,consume_stream})
                2'b10: stream_frames<=stream_frames+arg1_shadow;
                2'b01: stream_frames<=stream_frames-1;
                2'b11: stream_frames<=stream_frames+arg1_shadow-1;
                default: begin end
            endcase

            if (state==RESET) begin state<=INIT; init_phase<=0; init_count<=0; end
            if (state==INIT && !reset_pending) begin
                case (init_phase)
                    0: if (init_count==4) begin mr_level<=1; init_phase<=1; init_count<=0; end
                       else init_count<=init_count+1'b1;
                    1: if (init_count==4) begin init_phase<=2; init_count<=0; end
                       else init_count<=init_count+1'b1;
                    2: if (init_launch) init_phase<=3;
                    3: if (tx_done && tx_source==TX_INIT) begin
                        initialized<=1; state<=IDLE; init_phase<=0;
                    end
                    default: begin end
                endcase
            end

            // Prefetch the next 50-byte frame while the current frame shifts.
            if (!reset_pending && !control_valid) begin
                if (prefetch_state==0 && (state==RUN || state==PREFILL) && !seq_end_pending) begin
                    if (mode==SEQUENCE && sequence_owned[seq_cursor]) begin
                        prefetch_state<=3;
                    end else if (mode==STREAM && block_count!=0) begin
                        prefetch_state<=3;
                    end
                end else if (prefetch_state==3) begin
                    // One read-address cycle before capturing synchronous BRAM.
                    prefetch_state<=1;
                end else if (prefetch_state==1) begin
                    if (prefetch_word==12) begin
                        prefetched_frame[384+:16]<=memory_play_data[15:0];
                        prefetch_state<=2;
                    end else begin
                        prefetched_frame[prefetch_word*32+:32]<=memory_play_data;
                        prefetch_state<=3;
                    end
                end
            end
            if (state==PREFILL && stream_frames>=prefill_frames && prefetch_state==2) begin
                state<=RUN; cycle_started<=0;
            end
            if (state==RUN && cycle_started && countdown!=0) countdown<=countdown-1;
            if (schedule_allowed && deadline && cycle_started && !automatic_launch) begin
                error_flags[tx_ready && !inflight ? 0 : 1]<=1;
                error_frame<=frame_count+1; state<=ERROR; cycle_started<=0;
            end

            if (array_start) begin
                inflight<=1;
                if (init_launch) tx_source<=TX_INIT;
                else if (manual_launch || insertion) begin
                    tx_source<=TX_MANUAL; active_phase<=WAIT_TX; manual_finished<=0;
                end else begin
                    tx_source<=TX_AUTO; tx_slot<=prefetch_slot;
                    tx_was_stream<=(mode==STREAM);
                    tx_was_last<=(mode==SEQUENCE && !sequence_loop &&
                                  seq_cursor+1==sequence_base+sequence_count);
                    if (mode==SEQUENCE) begin
                        if (seq_cursor+1==sequence_base+sequence_count) begin
                            if (sequence_loop) seq_cursor<=sequence_base;
                            else seq_end_pending<=1;
                        end else seq_cursor<=seq_cursor+1;
                    end
                    prefetch_state<=0;
                end
                if (automatic_launch) begin cycle_started<=1; countdown<=period-1; end
            end
            if (tx_done && inflight) begin
                inflight<=0;
                if (tx_source==TX_MANUAL) begin manual_finished<=1; frame_count<=frame_count+1; end
                if (tx_source==TX_AUTO) begin
                    frame_count<=frame_count+1;
                    if (tx_was_stream) begin
                        stream_owned[tx_slot]<=0;
                    end
                    if (tx_was_last && !control_valid) begin
                        state<=IDLE; cycle_started<=0; seq_end_pending<=0; prefetch_state<=0;
                    end
                end
            end

            // Functional control priority. Publishing and OE requests use the bus
            // fast path below; timing-critical output work does not depend on AXI.
            if (!event_valid) begin
                if (reset_pending) begin
                    if (displaced_valid) begin
                        post_result(displaced_id,CANCELLED); displaced_valid<=0;
                    end else if (active_valid) begin
                        post_result(active.id,CANCELLED); active_valid<=0; manual_finished<=0;
                    end else if (cmd_count!=0) post_result(commands[cmd_head].id,CANCELLED);
                    else begin
                        reset_pending<=0; reset_completion<=1;
                        state<=INIT; mode<=HOLD; initialized<=0; output_requested<=0;
                        mr_level<=0; init_phase<=0; init_count<=0; inflight<=0;
                        config_active<=default_config(); config_shadow<=default_config();
                        data_barrier<=0;
                        fatal_fault<=0;
                        error_flags<=0; error_frame<=0; frame_count<=0;
                        reset_epoch<=reset_epoch+1; cycle_started<=0; seq_end_pending<=0;
                        seq_cursor<=0; prefetch_state<=0;
                        sequence_owned<=0; stream_owned<=0;
                        cmd_head<=0; cmd_tail<=0; cmd_count<=0;
                        block_head<=0; block_tail<=0; block_count<=0; block_offset<=0; stream_frames<=0;
                    end
                end else if (reset_completion && initialized) begin
                    post_result(reset_id,DONE); reset_completion<=0;
                end else if (fatal_fault) begin
                    if (control_valid) begin post_result(control_id,32'h4); control_valid<=0; end
                    else if (active_valid) begin post_result(active.id,32'h4); active_valid<=0; end
                    else if (cmd_count!=0) post_result(commands[cmd_head].id,32'h4);
                end else if (control_valid && !inflight) begin
                    if (active_valid) begin
                        if (active_phase==WAIT_TX && manual_finished) post_result(active.id,DONE);
                        else post_result(active.id,CANCELLED);
                        active_valid<=0; manual_finished<=0;
                    end else if (cmd_count!=0) post_result(commands[cmd_head].id,CANCELLED);
                    else begin
                        control_valid<=0; cycle_started<=0;
                        data_barrier<=0;
                        if (control_op==PAUSE) begin
                            if (seq_end_pending && mode==SEQUENCE && !sequence_loop) begin
                                state<=IDLE; seq_end_pending<=0; prefetch_state<=0;
                            end else begin state<=PAUSED; resume_state<=control_previous_state; end
                        end else begin
                            state<=(control_previous_state==ERROR) ? ERROR : IDLE;
                            prefetch_state<=0; seq_cursor<=sequence_base; seq_end_pending<=0;
                            if (control_op==SET_MODE) mode<=control_argument[1:0];
                        end
                        post_result(control_id,DONE);
                    end
                end else if (active_valid) begin
                    if (active_phase==WAIT_TX && manual_finished) begin
                        post_result(active.id,DONE); active_valid<=0; manual_finished<=0;
                    end else if (active_phase==EXECUTE && !inflight) begin
                        case (active.op)
                            APPLY,CLEAR_ALL: begin
                                if (active.op==CLEAR_ALL || active.flags==1) begin
                                    state<=IDLE; mode<=HOLD; cycle_started<=0;
                                    prefetch_state<=0; seq_end_pending<=0;
                                    active_phase<=ISSUE;
                                    if (active.op==CLEAR_ALL) begin active.mask<=ALL_CHIPS; active.payload<=0; end
                                end else if (active.flags==2 && state==RUN) active_phase<=WAIT_SLOT;
                                else if (active.flags==0 && (state==IDLE || state==PAUSED)) active_phase<=ISSUE;
                                else begin
                                    post_result(active.id,REJECTED); active_valid<=0; error_flags[2]<=1;
                                end
                            end
                            CONFIG_APPLY: begin
                                if (!config_valid(active.config_words) ||
                                    ((active_previous_state==RUN || active_previous_state==PREFILL) &&
                                     active.config_words[96+:256]!=config_active[96+:256])) begin
                                    post_result(active.id,REJECTED); error_flags[2]<=1;
                                    if (state==FINISH_FRAME) state<=active_previous_state;
                                end else begin
                                    config_active<=active.config_words;
                                    if (state==FINISH_FRAME) begin
                                        state<=active_previous_state; cycle_started<=1;
                                        countdown<=active.config_words[0+:32]-1;
                                    end
                                    if (state==IDLE || state==PAUSED) begin
                                        seq_cursor<=active.config_words[96+:32]; prefetch_state<=0;
                                    end
                                    post_result(active.id,DONE);
                                end
                                active_valid<=0;
                            end
                            START: begin
                                if (state!=IDLE || mode==HOLD ||
                                    (mode==SEQUENCE && !sequence_ready)) begin
                                    post_result(active.id,REJECTED); error_flags[2]<=1;
                                end else begin
                                    state<=(mode==STREAM) ? PREFILL : RUN;
                                    cycle_started<=0; seq_cursor<=sequence_base;
                                    seq_end_pending<=0; prefetch_state<=0;
                                    post_result(active.id,DONE);
                                end
                                active_valid<=0;
                            end
                            RESUME: begin
                                if (state!=PAUSED) begin post_result(active.id,REJECTED); error_flags[2]<=1; end
                                else begin
                                    state<=(resume_state==PREFILL) ? PREFILL : RUN;
                                    cycle_started<=0; post_result(active.id,DONE);
                                end
                                active_valid<=0;
                            end
                            FLUSH_DATA: begin
                                data_barrier<=0;
                                if (state!=IDLE && state!=PAUSED) begin
                                    post_result(active.id,REJECTED); error_flags[2]<=1;
                                end else begin
                                    sequence_owned<=0; stream_owned<=0; prefetch_state<=0;
                                    block_head<=0; block_tail<=0; block_count<=0;
                                    block_offset<=0; stream_frames<=0;
                                    post_result(active.id,DONE);
                                end
                                active_valid<=0;
                            end
                            default: begin post_result(active.id,REJECTED); active_valid<=0; end
                        endcase
                    end
                end else if (dispatch) begin
                    active<=commands[cmd_head]; active_valid<=1; active_phase<=EXECUTE;
                    active_previous_state<=state;
                    if ((commands[cmd_head].op==APPLY && commands[cmd_head].flags==1) ||
                        commands[cmd_head].op==CLEAR_ALL ||
                        (commands[cmd_head].op==CONFIG_APPLY &&
                         config_valid(commands[cmd_head].config_words) &&
                         commands[cmd_head].config_words[96+:256]==config_active[96+:256]))
                        if (state==RUN || state==PREFILL) state<=FINISH_FRAME;
                end
            end

            // All bus writes are serialized against completion-producing engine
            // operations. Staging writes can proceed while the array is busy.
            if (write_fire && wr_resp!=0) error_flags[2]<=1;
            if (stage_write) begin
                for (j=0;j<4;j=j+1)
                    if (wr_strb[j] && (wr_addr-16'h0100+j)<50)
                        frame_shadow[(wr_addr-16'h0100+j)*8+:8]<=wr_data[j*8+:8];
            end else if (configuration_write) begin
                config_shadow[(wr_addr-16'h0040)*8+:32]<=merge_bytes(
                    config_shadow[(wr_addr-16'h0040)*8+:32],wr_data,wr_strb);
            end else if (write_ok) begin
                case (wr_addr)
                    16'h0010: op_shadow<=merge_bytes(op_shadow,wr_data,wr_strb);
                    16'h0014: id_shadow<=merge_bytes(id_shadow,wr_data,wr_strb);
                    16'h0018: arg0_shadow<=merge_bytes(arg0_shadow,wr_data,wr_strb);
                    16'h001c: arg1_shadow<=merge_bytes(arg1_shadow,wr_data,wr_strb);
                    16'h0020: mask_shadow[31:0]<=merge_bytes(mask_shadow[31:0],wr_data,wr_strb);
                    16'h0024: mask_shadow[49:32]<=merge_bytes({14'b0,mask_shadow[49:32]},wr_data,wr_strb);
                    default: begin end
                endcase
            end
            if (submit) begin
                last_accepted<=id_shadow;
                if (submitted_op==FLUSH_DATA) data_barrier<=1;
                if (submitted_op==OUTPUT_DISABLE) begin output_requested<=0; post_result(id_shadow,DONE); end
                if (submitted_op==OUTPUT_ENABLE) begin output_requested<=1; post_result(id_shadow,DONE); end
                if (submitted_op==CLEAR_ERROR) begin
                    error_flags<=0;
                    if (state==ERROR) begin state<=IDLE; prefetch_state<=0; cycle_started<=0; end
                    post_result(id_shadow,DONE);
                end
                if (submitted_op==PUBLISH_BLOCK) begin
                    for (i=0;i<FRAME_SLOTS;i=i+1)
                        if (i>=publication_base && i<publication_end) begin
                            if (submitted_flags==0) sequence_owned[i]<=1;
                            else stream_owned[i]<=1;
                        end
                    post_result(id_shadow,DONE);
                end
                if (control_command) begin
                    control_valid<=1; control_op<=submitted_op;
                    control_id<=id_shadow; control_argument<=arg0_shadow;
                    control_previous_state<=state;
                    state<=FINISH_FRAME;
                end
                if (submitted_op==SOFT_RESET) begin
                    reset_pending<=1; reset_id<=id_shadow;
                    output_requested<=0; mr_level<=0; initialized<=0;
                    state<=RESET; inflight<=0;
                    if (control_valid) begin displaced_valid<=1; displaced_id<=control_id; end
                    control_valid<=0;
                end
            end
            if (array_fault && !reset_pending) begin
                fatal_fault<=1; initialized<=0; output_requested<=0;
                error_flags[4]<=1; state<=ERROR; inflight<=0; cycle_started<=0;
            end
        end
    end
endmodule
`default_nettype wire
