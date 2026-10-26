`timescale 1ns/1ps
`default_nettype none

// AXI4, one outstanding write and one outstanding read, independent channels.
// Aligned 32-bit FIXED/INCR transfers. Other transfer shapes return SLVERR.
// Unsupported bursts are drained without peripheral side effects.
module ris_axi4_slave #(
    parameter integer ID_WIDTH=12,
    parameter integer FRAME_SLOTS=256
) (
    input wire clk, resetn,
    input wire [ID_WIDTH-1:0] awid,
    input wire [31:0] awaddr,
    input wire [7:0] awlen,
    input wire [2:0] awsize,
    input wire [1:0] awburst,
    input wire awlock, awvalid, output wire awready,
    input wire [31:0] wdata, input wire [3:0] wstrb,
    input wire wlast, wvalid, output wire wready,
    output reg [ID_WIDTH-1:0] bid, output reg [1:0] bresp,
    output reg bvalid, input wire bready,
    input wire [ID_WIDTH-1:0] arid,
    input wire [31:0] araddr,
    input wire [7:0] arlen,
    input wire [2:0] arsize,
    input wire [1:0] arburst,
    input wire arlock, arvalid, output wire arready,
    output reg [ID_WIDTH-1:0] rid, output reg [31:0] rdata,
    output reg [1:0] rresp, output reg rlast, rvalid, input wire rready,
    output wire wr_valid, input wire wr_ready,
    output wire [15:0] wr_addr, output wire [31:0] wr_data,
    output wire [3:0] wr_strb, input wire [1:0] wr_resp,
    output wire [15:0] rd_addr, input wire [31:0] rd_data,
    input wire [1:0] rd_resp
);
    reg write_active, read_active, write_bad, read_bad;
    reg read_wait;
    reg [31:0] wa, ra;
    reg [7:0] wn, rn;
    reg [1:0] wb, rb;
    reg [ID_WIDTH-1:0] wi, ri;
    reg [1:0] accumulated_response;
    function valid_shape;
        input [31:0] address;
        input [7:0] length;
        input [2:0] size;
        input [1:0] burst;
        input is_read;
        reg [32:0] last_address;
        reg [15:0] first_offset, last_offset;
        begin
            last_address={1'b0,address};
            if (burst==1) last_address=last_address+({25'b0,length}<<2);
            first_offset=address[15:0]; last_offset=last_address[15:0];
            valid_shape=(size==2 && address[1:0]==0 && burst<=1 &&
                         last_address[32:12]=={1'b0,address[31:12]});
            if (length!=0) begin
                // Burst side effects are restricted to the data windows.
                valid_shape=valid_shape && (
                    (first_offset>=16'h0100 && last_offset<16'h0140) ||
                    (is_read && first_offset>=16'h0140 && last_offset<16'h0180) ||
                    (first_offset>=16'h1000 &&
                     last_offset<16'h1000+FRAME_SLOTS*64));
            end
        end
    endfunction
    assign awready=!write_active && !bvalid;
    assign arready=!read_active && !rvalid;
    wire last_matches=(wlast==(wn==0));
    assign wr_valid=write_active && wvalid && !write_bad && last_matches;
    assign wready=write_active && ((write_bad || !last_matches) ? 1'b1 : wr_ready);
    assign wr_addr=wa[15:0];
    assign wr_data=wdata;
    assign wr_strb=wstrb;
    assign rd_addr=ra[15:0];
    // BRAM address pins must not change asynchronously when reset is asserted.
    // VALID/state flops below retain asynchronous reset for AXI compliance.
    always @(posedge clk) begin
        if (!resetn) begin wa<=0; ra<=0; end
        else begin
            if (awvalid && awready) wa<=awaddr;
            else if (wvalid && wready && wn!=0 && !wlast && wb==1) wa<=wa+4;
            if (arvalid && arready) ra<=araddr;
            else if (rvalid && rready && rn!=0 && rb==1) ra<=ra+4;
        end
    end
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            write_active<=0; read_active<=0; write_bad<=0; read_bad<=0;
            read_wait<=0;
            wn<=0; rn<=0; wb<=0; rb<=0; wi<=0; ri<=0;
            accumulated_response<=0; bid<=0; bresp<=0; bvalid<=0;
            rid<=0; rdata<=0; rresp<=0; rlast<=0; rvalid<=0;
        end else begin
            if (bvalid && bready) bvalid<=0;
            if (awvalid && awready) begin
                write_active<=1; wn<=awlen; wb<=awburst; wi<=awid;
                write_bad<=awlock || !valid_shape(awaddr,awlen,awsize,awburst,0);
                accumulated_response<=0;
            end
            if (wvalid && wready) begin
                if (write_bad || !last_matches || wr_resp!=0)
                    accumulated_response<=write_bad || !last_matches ? 2'b10 : wr_resp;
                if (wn==0 || wlast) begin
                    write_active<=0; bvalid<=1; bid<=wi;
                    if (write_bad || !last_matches) bresp<=2'b10;
                    else if (wr_resp!=0) bresp<=wr_resp;
                    else bresp<=accumulated_response;
                end else begin
                    wn<=wn-1'b1;
                end
            end
            if (arvalid && arready) begin
                read_active<=1; rn<=arlen; rb<=arburst; ri<=arid;
                read_wait<=1;
                read_bad<=arlock || !valid_shape(araddr,arlen,arsize,arburst,1);
            end
            if (rvalid && rready) begin
                rvalid<=0;
                read_wait<=1;
                if (rn==0) read_active<=0;
                else rn<=rn-1'b1;
            end else if (read_active && !rvalid) begin
                // Allow the selected address to reach synchronous frame BRAM.
                if (read_wait) read_wait<=0;
                else begin
                    rvalid<=1; rid<=ri; rlast<=(rn==0);
                    rdata<=read_bad ? 0 : rd_data;
                    rresp<=read_bad ? 2'b10 : rd_resp;
                end
            end
        end
    end
endmodule
`default_nettype wire
