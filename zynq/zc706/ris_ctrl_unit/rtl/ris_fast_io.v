`timescale 1ns/1ps
`default_nettype none

// Matched to the 100 MHz AXI clock in the ZC706 block design.
// Private bus extension A0..CC. Write A4: 1/3/5=MHz presets, 9=start
// C0 half-period, 0=stop/hold, 8=release after normal mirror alignment.
module ris_fast_io (
    input wire clk, resetn,
    input wire normal_mr_n, normal_oe_n,
    input wire [49:0] normal_data,
    input wire [9:0] normal_shift, normal_latch,
    input wire wr_valid,
    input wire [15:0] wr_addr, rd_addr,
    input wire [31:0] wr_data,
    input wire [3:0] wr_strb,
    output wire [1:0] wr_resp,
    output reg [31:0] rd_data,
    output reg [1:0] rd_resp,
    output wire busy_owned,
    output wire [49:0] data,
    output wire [9:0] shift, latch,
    output wire oe_n
);
    wire fb, fb_buf, raw_fast, fast_clk, locked;
    MMCME2_BASE #(.CLKIN1_PERIOD(10.0), .CLKFBOUT_MULT_F(6.0),
        .DIVCLK_DIVIDE(1), .CLKOUT0_DIVIDE_F(2.0), .STARTUP_WAIT("FALSE")) u_mmcm (
        .CLKIN1(clk), .CLKFBIN(fb_buf), .CLKFBOUT(fb), .CLKOUT0(raw_fast),
        .LOCKED(locked), .PWRDWN(1'b0), .RST(!resetn)
    );
    BUFG u_fb (.I(fb),.O(fb_buf));
    BUFG u_fast_clock (.I(raw_fast),.O(fast_clk));
    wire engine_resetn=resetn && locked && normal_mr_n;
    (* ASYNC_REG="TRUE" *) reg [1:0] reset_sync;
    always @(posedge fast_clk or negedge engine_resetn)
        if (!engine_resetn) reset_sync<=0; else reset_sync<={reset_sync[0],1'b1};
    reg request_toggle;
    reg [3:0] request_mode;
    reg [27:0] configured_ticks, request_ticks;
    wire acknowledged, owned_fast, running_fast, level_fast;
    wire [3:0] mode_fast;
    wire [31:0] edges_fast, gray_fast;
    wire fast_data, shift_d1, shift_d2, fast_latch;
    (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync, owned_sync, running_sync, level_sync;
    (* ASYNC_REG="TRUE" *) reg [31:0] gray_meta, gray_sync;
    (* ASYNC_REG="TRUE" *) reg [1:0] locked_sync;
    wire pending=request_toggle!=ack_sync[1];
    assign busy_owned=owned_sync[1] && running_sync[1];
    wire valid_mode=wr_data==0 || wr_data==8 || wr_data==1 || wr_data==3 || wr_data==5 || wr_data==9;
    wire control_write=wr_addr==16'h00a4 && valid_mode &&
                    (!running_sync[1] || wr_data==0);
    wire ticks_write=wr_addr==16'h00c0 && wr_data>=30 && wr_data<=150000000;
    assign wr_resp=((control_write || ticks_write) && wr_strb==4'hf &&
                    !pending && locked_sync[1] && normal_mr_n &&
                    (control_write || !running_sync[1])) ? 0 : 2;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            locked_sync<=0; request_toggle<=0; request_mode<=8;
            configured_ticks<=30; request_ticks<=30;
            ack_sync<=0; owned_sync<=0; running_sync<=0; level_sync<=0;
            gray_meta<=0; gray_sync<=0;
        end else begin
            locked_sync<={locked_sync[0],locked};
            if (!normal_mr_n || !locked) begin
                request_toggle<=0; request_mode<=8; ack_sync<=0;
                owned_sync<=0; running_sync<=0; level_sync<=0;
                gray_meta<=0; gray_sync<=0;
            end else begin
                ack_sync<={ack_sync[0],acknowledged};
                owned_sync<={owned_sync[0],owned_fast};
                running_sync<={running_sync[0],running_fast};
                level_sync<={level_sync[0],level_fast};
                gray_meta<=gray_fast; gray_sync<=gray_meta;
                if (wr_valid && wr_resp==0) begin
                    if (wr_addr==16'h00c0) configured_ticks<=wr_data[27:0];
                    else begin
                        request_mode<=wr_data[3:0]; request_toggle<=!request_toggle;
                        if (wr_data==1) request_ticks<=150;
                        else if (wr_data==3) request_ticks<=50;
                        else if (wr_data==5) request_ticks<=30;
                        else if (wr_data==9) request_ticks<=configured_ticks;
                    end
                end
            end
        end
    end
    reg [31:0] decoded_edges;
    integer b;
    always @* begin
        decoded_edges[31]=gray_sync[31];
        for (b=30;b>=0;b=b-1) decoded_edges[b]=decoded_edges[b+1]^gray_sync[b];
        rd_resp=0; rd_data=0;
        case (rd_addr)
            16'h00a0: rd_data=32'h46535432; // FST2: programmable divider
            16'h00a4: rd_data={28'b0,request_mode};
            16'h00a8: rd_data={27'b0,pending,level_sync[1],running_sync[1],owned_sync[1],locked_sync[1]};
            16'h00ac: rd_data=running_sync[1] && request_mode!=9 ? {28'b0,request_mode} : 0;
            16'h00b0: rd_data=decoded_edges;
            16'h00b4: rd_data=32'h2a; // presets 1,3,5 MHz
            16'h00b8: rd_data=300; // engine MHz
            16'h00bc: rd_data=100; // SHCP MHz during eight-pulse bursts
            16'h00c0: rd_data={4'b0,configured_ticks};
            16'h00c4: rd_data=running_sync[1] ? {4'b0,request_ticks} : 0;
            16'h00c8: rd_data=30;
            16'h00cc: rd_data=150000000;
            default: rd_resp=3;
        endcase
    end
    ris_fast_engine u_engine (
        .clk(fast_clk),.resetn(reset_sync[1]),.request_toggle(request_toggle),
        .request_mode(request_mode),.request_ticks(request_ticks),.acknowledged(acknowledged),.owned(owned_fast),
        .running(running_fast),.level(level_fast),.mode(mode_fast),.edges(edges_fast),
        .edges_gray(gray_fast),.data(fast_data),.shift_d1(shift_d1),
        .shift_d2(shift_d2),.latch(fast_latch)
    );
    // A fabric output stage isolates the phase decoder and the 100 MHz normal
    // engine from the long routes to the IOBs. All 70 lanes have equal latency.
    reg [49:0] data_pipe;
    reg [9:0] shift_d1_pipe,shift_d2_pipe,latch_pipe;
    always @(posedge fast_clk or negedge reset_sync[1]) begin
        if (!reset_sync[1]) begin
            data_pipe<=0;shift_d1_pipe<=0;shift_d2_pipe<=0;latch_pipe<=0;
        end else begin
            data_pipe<=owned_fast ? {50{fast_data}} : normal_data;
            shift_d1_pipe<=owned_fast ? {10{shift_d1}} : normal_shift;
            shift_d2_pipe<=owned_fast ? {10{shift_d2}} : normal_shift;
            latch_pipe<=owned_fast ? {10{fast_latch}} : normal_latch;
        end
    end
    // Every high-speed signal terminates at an IOB DDR register, never a LUT
    // after ODDR. Normal-mode signals share the same final output registers.
    genvar lane;
    generate for (lane=0;lane<50;lane=lane+1) begin: data_lane
        wire value=data_pipe[lane];
        ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.SRTYPE("ASYNC")) u_data (
            .C(fast_clk),.CE(1'b1),.D1(value),.D2(value),.R(!reset_sync[1]),.S(1'b0),.Q(data[lane]));
    end
    for (lane=0;lane<10;lane=lane+1) begin: clock_lane
        wire d1=shift_d1_pipe[lane];
        wire d2=shift_d2_pipe[lane];
        wire st=latch_pipe[lane];
        ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.SRTYPE("ASYNC")) u_shift (
            .C(fast_clk),.CE(1'b1),.D1(d1),.D2(d2),.R(!reset_sync[1]),.S(1'b0),.Q(shift[lane]));
        ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.SRTYPE("ASYNC")) u_latch (
            .C(fast_clk),.CE(1'b1),.D1(st),.D2(st),.R(!reset_sync[1]),.S(1'b0),.Q(latch[lane]));
    end endgenerate
    assign oe_n=normal_oe_n || !locked_sync[1];
endmodule
`default_nettype wire
