`timescale 1ns/1ps
`default_nettype none

// AXI4 memory-mapped RIS peripheral. Address offsets are relative to its BD base.
module ris_controller_axi #(
    parameter integer ID_WIDTH=12, FRAME_SLOTS=256, CMD_DEPTH=8, FAST_TOGGLE_ENABLE=0,
    parameter integer RESULT_DEPTH=32, BLOCK_DEPTH=16
) (
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 s_axi_aclk CLK",
       X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn" *)
    input wire s_axi_aclk,
    (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 s_axi_aresetn RST",
       X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *)
    input wire s_axi_aresetn,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWID" *)
    (* X_INTERFACE_PARAMETER="PROTOCOL AXI4, DATA_WIDTH 32, ADDR_WIDTH 32, ID_WIDTH 12, MAX_BURST_LENGTH 256, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, SUPPORTS_NARROW_BURST 0" *)
    input wire [ID_WIDTH-1:0] s_axi_awid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input wire [31:0] s_axi_awaddr,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWLEN" *)
    input wire [7:0] s_axi_awlen,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWSIZE" *)
    input wire [2:0] s_axi_awsize,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWBURST" *)
    input wire [1:0] s_axi_awburst,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWLOCK" *)
    input wire  s_axi_awlock,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWCACHE" *)
    input wire [3:0] s_axi_awcache,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input wire [2:0] s_axi_awprot,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWQOS" *)
    input wire [3:0] s_axi_awqos,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input wire  s_axi_awvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire  s_axi_awready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input wire [3:0] s_axi_wstrb,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WLAST" *)
    input wire  s_axi_wlast,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input wire  s_axi_wvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire  s_axi_wready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BID" *)
    output wire [ID_WIDTH-1:0] s_axi_bid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire  s_axi_bvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input wire  s_axi_bready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARID" *)
    input wire [ID_WIDTH-1:0] s_axi_arid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input wire [31:0] s_axi_araddr,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARLEN" *)
    input wire [7:0] s_axi_arlen,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARSIZE" *)
    input wire [2:0] s_axi_arsize,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARBURST" *)
    input wire [1:0] s_axi_arburst,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARLOCK" *)
    input wire  s_axi_arlock,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARCACHE" *)
    input wire [3:0] s_axi_arcache,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input wire [2:0] s_axi_arprot,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARQOS" *)
    input wire [3:0] s_axi_arqos,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input wire  s_axi_arvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire  s_axi_arready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RID" *)
    output wire [ID_WIDTH-1:0] s_axi_rid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RLAST" *)
    output wire  s_axi_rlast,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire  s_axi_rvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input wire  s_axi_rready,
    output wire [49:0] ris_data,
    output wire [9:0] ris_shcp, ris_stcp,
    output wire ris_mr_n, ris_oe_n
);
    wire wr_valid,wr_ready;
    wire [15:0] wr_addr,rd_addr;
    wire [31:0] wr_data,rd_data;
    wire [3:0] wr_strb;
    wire [1:0] wr_resp,rd_resp;
    wire core_wr_ready;
    wire [1:0] core_wr_resp,core_rd_resp;
    wire [31:0] core_rd_data;
    wire [49:0] normal_data;
    wire [9:0] normal_shift,normal_latch;
    wire normal_mr_n,normal_oe_n;
    wire fast_write=FAST_TOGGLE_ENABLE && wr_addr>=16'h00a0 && wr_addr<16'h00d0;
    wire fast_read=FAST_TOGGLE_ENABLE && rd_addr>=16'h00a0 && rd_addr<16'h00d0;
    wire [1:0] fast_wr_resp,fast_rd_resp;
    wire [31:0] fast_rd_data;
    assign wr_ready=fast_write ? 1'b1 : core_wr_ready;
    assign wr_resp=fast_write ? fast_wr_resp : core_wr_resp;
    assign rd_resp=fast_read ? fast_rd_resp : core_rd_resp;
    assign rd_data=fast_read ? fast_rd_data : core_rd_data;
    ris_axi4_slave #(.ID_WIDTH(ID_WIDTH),.FRAME_SLOTS(FRAME_SLOTS)) u_axi (
        .clk(s_axi_aclk),.resetn(s_axi_aresetn),
        .awid(s_axi_awid),
        .awaddr(s_axi_awaddr),
        .awlen(s_axi_awlen),
        .awsize(s_axi_awsize),
        .awburst(s_axi_awburst),
        .awlock(s_axi_awlock),
        .awvalid(s_axi_awvalid),
        .awready(s_axi_awready),
        .wdata(s_axi_wdata),
        .wstrb(s_axi_wstrb),
        .wlast(s_axi_wlast),
        .wvalid(s_axi_wvalid),
        .wready(s_axi_wready),
        .bid(s_axi_bid),
        .bresp(s_axi_bresp),
        .bvalid(s_axi_bvalid),
        .bready(s_axi_bready),
        .arid(s_axi_arid),
        .araddr(s_axi_araddr),
        .arlen(s_axi_arlen),
        .arsize(s_axi_arsize),
        .arburst(s_axi_arburst),
        .arlock(s_axi_arlock),
        .arvalid(s_axi_arvalid),
        .arready(s_axi_arready),
        .rid(s_axi_rid),
        .rdata(s_axi_rdata),
        .rresp(s_axi_rresp),
        .rlast(s_axi_rlast),
        .rvalid(s_axi_rvalid),
        .rready(s_axi_rready),
        .wr_valid(wr_valid),.wr_ready(wr_ready),.wr_addr(wr_addr),
        .wr_data(wr_data),.wr_strb(wr_strb),.wr_resp(wr_resp),
        .rd_addr(rd_addr),.rd_data(rd_data),.rd_resp(rd_resp)
    );
    ris_controller_core #(.FRAME_SLOTS(FRAME_SLOTS),.CMD_DEPTH(CMD_DEPTH),
        .RESULT_DEPTH(RESULT_DEPTH),.BLOCK_DEPTH(BLOCK_DEPTH)) u_core (
        .clk(s_axi_aclk),.resetn(s_axi_aresetn),
        .wr_valid(wr_valid && !fast_write),.wr_ready(core_wr_ready),.wr_addr(wr_addr),
        .wr_data(wr_data),.wr_strb(wr_strb),.wr_resp(core_wr_resp),
        .rd_addr(rd_addr),.rd_data(core_rd_data),.rd_resp(core_rd_resp),
        .ris_data(normal_data),.ris_shcp(normal_shift),.ris_stcp(normal_latch),
        .ris_mr_n(normal_mr_n),.ris_oe_n(normal_oe_n)
    );
    assign ris_mr_n=normal_mr_n;
    generate if (FAST_TOGGLE_ENABLE) begin: fast_io
        ris_fast_io u_fast (
            .clk(s_axi_aclk),.resetn(s_axi_aresetn),.normal_mr_n(normal_mr_n),
            .normal_oe_n(normal_oe_n),.normal_data(normal_data),
            .normal_shift(normal_shift),.normal_latch(normal_latch),
            .wr_valid(wr_valid && fast_write),.wr_addr(wr_addr),.rd_addr(rd_addr),
            .wr_data(wr_data),.wr_strb(wr_strb),.wr_resp(fast_wr_resp),
            .rd_data(fast_rd_data),.rd_resp(fast_rd_resp),.busy_owned(),
            .data(ris_data),.shift(ris_shcp),.latch(ris_stcp),.oe_n(ris_oe_n));
    end else begin: normal_io
        assign fast_wr_resp=2; assign fast_rd_resp=3; assign fast_rd_data=0;
        assign ris_data=normal_data; assign ris_shcp=normal_shift;
        assign ris_stcp=normal_latch; assign ris_oe_n=normal_oe_n;
    end endgenerate
endmodule
`default_nettype wire
