//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
//Date        : Fri Nov 13 15:19:24 2026
//Host        : wenhan running 64-bit Ubuntu 26.10
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (DDR3_0_addr,
    DDR3_0_ba,
    DDR3_0_cas_n,
    DDR3_0_ck_n,
    DDR3_0_ck_p,
    DDR3_0_cke,
    DDR3_0_cs_n,
    DDR3_0_dm,
    DDR3_0_dq,
    DDR3_0_dqs_n,
    DDR3_0_dqs_p,
    DDR3_0_odt,
    DDR3_0_ras_n,
    DDR3_0_reset_n,
    DDR3_0_we_n,
    DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    GPIO_PS_tri_io,
    SPI_9361_io0_io,
    SPI_9361_io1_io,
    SPI_9361_sck_io,
    SPI_9361_ss1_o,
    SPI_9361_ss2_o,
    SPI_9361_ss_io,
    key_0,
    out_1_1_0,
    out_1_2_0,
    out_1_3_0,
    out_1_4_0,
    out_1_5_0,
    out_2_1_0,
    out_2_2_0,
    out_2_3_0,
    out_2_4_0,
    out_2_5_0,
    out_3_1_0,
    out_3_2_0,
    out_3_3_0,
    out_3_4_0,
    out_3_5_0,
    out_4_1_0,
    out_4_2_0,
    out_4_3_0,
    out_4_4_0,
    out_4_5_0,
    out_5_1_0,
    out_5_2_0,
    out_5_3_0,
    out_5_4_0,
    out_5_5_0,
    pl_eth_mdio_mdc,
    pl_eth_mdio_mdio_io,
    pl_eth_refclk_clk_n,
    pl_eth_refclk_clk_p,
    pl_eth_sgmii_rxn,
    pl_eth_sgmii_rxp,
    pl_eth_sgmii_txn,
    pl_eth_sgmii_txp,
    rstn,
    rx_clk_n,
    rx_clk_p,
    rx_data_n,
    rx_data_p,
    rx_frame_n,
    rx_frame_p,
    sys_clk_clk_n,
    sys_clk_clk_p);
  output [13:0]DDR3_0_addr;
  output [2:0]DDR3_0_ba;
  output DDR3_0_cas_n;
  output [1:0]DDR3_0_ck_n;
  output [1:0]DDR3_0_ck_p;
  output [1:0]DDR3_0_cke;
  output [1:0]DDR3_0_cs_n;
  output [7:0]DDR3_0_dm;
  inout [63:0]DDR3_0_dq;
  inout [7:0]DDR3_0_dqs_n;
  inout [7:0]DDR3_0_dqs_p;
  output [1:0]DDR3_0_odt;
  output DDR3_0_ras_n;
  output DDR3_0_reset_n;
  output DDR3_0_we_n;
  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;
  inout [2:0]GPIO_PS_tri_io;
  inout SPI_9361_io0_io;
  inout SPI_9361_io1_io;
  inout SPI_9361_sck_io;
  output SPI_9361_ss1_o;
  output SPI_9361_ss2_o;
  inout SPI_9361_ss_io;
  input key_0;
  output out_1_1_0;
  output out_1_2_0;
  output out_1_3_0;
  output out_1_4_0;
  output out_1_5_0;
  output out_2_1_0;
  output out_2_2_0;
  output out_2_3_0;
  output out_2_4_0;
  output out_2_5_0;
  output out_3_1_0;
  output out_3_2_0;
  output out_3_3_0;
  output out_3_4_0;
  output out_3_5_0;
  output out_4_1_0;
  output out_4_2_0;
  output out_4_3_0;
  output out_4_4_0;
  output out_4_5_0;
  output out_5_1_0;
  output out_5_2_0;
  output out_5_3_0;
  output out_5_4_0;
  output out_5_5_0;
  output pl_eth_mdio_mdc;
  inout pl_eth_mdio_mdio_io;
  input pl_eth_refclk_clk_n;
  input pl_eth_refclk_clk_p;
  input pl_eth_sgmii_rxn;
  input pl_eth_sgmii_rxp;
  output pl_eth_sgmii_txn;
  output pl_eth_sgmii_txp;
  input rstn;
  input rx_clk_n;
  input rx_clk_p;
  input [5:0]rx_data_n;
  input [5:0]rx_data_p;
  input rx_frame_n;
  input rx_frame_p;
  input [0:0]sys_clk_clk_n;
  input [0:0]sys_clk_clk_p;

  wire [13:0]DDR3_0_addr;
  wire [2:0]DDR3_0_ba;
  wire DDR3_0_cas_n;
  wire [1:0]DDR3_0_ck_n;
  wire [1:0]DDR3_0_ck_p;
  wire [1:0]DDR3_0_cke;
  wire [1:0]DDR3_0_cs_n;
  wire [7:0]DDR3_0_dm;
  wire [63:0]DDR3_0_dq;
  wire [7:0]DDR3_0_dqs_n;
  wire [7:0]DDR3_0_dqs_p;
  wire [1:0]DDR3_0_odt;
  wire DDR3_0_ras_n;
  wire DDR3_0_reset_n;
  wire DDR3_0_we_n;
  wire [14:0]DDR_addr;
  wire [2:0]DDR_ba;
  wire DDR_cas_n;
  wire DDR_ck_n;
  wire DDR_ck_p;
  wire DDR_cke;
  wire DDR_cs_n;
  wire [3:0]DDR_dm;
  wire [31:0]DDR_dq;
  wire [3:0]DDR_dqs_n;
  wire [3:0]DDR_dqs_p;
  wire DDR_odt;
  wire DDR_ras_n;
  wire DDR_reset_n;
  wire DDR_we_n;
  wire FIXED_IO_ddr_vrn;
  wire FIXED_IO_ddr_vrp;
  wire [53:0]FIXED_IO_mio;
  wire FIXED_IO_ps_clk;
  wire FIXED_IO_ps_porb;
  wire FIXED_IO_ps_srstb;
  wire [0:0]GPIO_PS_tri_i_0;
  wire [1:1]GPIO_PS_tri_i_1;
  wire [2:2]GPIO_PS_tri_i_2;
  wire [0:0]GPIO_PS_tri_io_0;
  wire [1:1]GPIO_PS_tri_io_1;
  wire [2:2]GPIO_PS_tri_io_2;
  wire [0:0]GPIO_PS_tri_o_0;
  wire [1:1]GPIO_PS_tri_o_1;
  wire [2:2]GPIO_PS_tri_o_2;
  wire [0:0]GPIO_PS_tri_t_0;
  wire [1:1]GPIO_PS_tri_t_1;
  wire [2:2]GPIO_PS_tri_t_2;
  wire SPI_9361_io0_i;
  wire SPI_9361_io0_io;
  wire SPI_9361_io0_o;
  wire SPI_9361_io0_t;
  wire SPI_9361_io1_i;
  wire SPI_9361_io1_io;
  wire SPI_9361_io1_o;
  wire SPI_9361_io1_t;
  wire SPI_9361_sck_i;
  wire SPI_9361_sck_io;
  wire SPI_9361_sck_o;
  wire SPI_9361_sck_t;
  wire SPI_9361_ss1_o;
  wire SPI_9361_ss2_o;
  wire SPI_9361_ss_i;
  wire SPI_9361_ss_io;
  wire SPI_9361_ss_o;
  wire SPI_9361_ss_t;
  wire key_0;
  wire out_1_1_0;
  wire out_1_2_0;
  wire out_1_3_0;
  wire out_1_4_0;
  wire out_1_5_0;
  wire out_2_1_0;
  wire out_2_2_0;
  wire out_2_3_0;
  wire out_2_4_0;
  wire out_2_5_0;
  wire out_3_1_0;
  wire out_3_2_0;
  wire out_3_3_0;
  wire out_3_4_0;
  wire out_3_5_0;
  wire out_4_1_0;
  wire out_4_2_0;
  wire out_4_3_0;
  wire out_4_4_0;
  wire out_4_5_0;
  wire out_5_1_0;
  wire out_5_2_0;
  wire out_5_3_0;
  wire out_5_4_0;
  wire out_5_5_0;
  wire pl_eth_mdio_mdc;
  wire pl_eth_mdio_mdio_i;
  wire pl_eth_mdio_mdio_io;
  wire pl_eth_mdio_mdio_o;
  wire pl_eth_mdio_mdio_t;
  wire pl_eth_refclk_clk_n;
  wire pl_eth_refclk_clk_p;
  wire pl_eth_sgmii_rxn;
  wire pl_eth_sgmii_rxp;
  wire pl_eth_sgmii_txn;
  wire pl_eth_sgmii_txp;
  wire rstn;
  wire rx_clk_n;
  wire rx_clk_p;
  wire [5:0]rx_data_n;
  wire [5:0]rx_data_p;
  wire rx_frame_n;
  wire rx_frame_p;
  wire [0:0]sys_clk_clk_n;
  wire [0:0]sys_clk_clk_p;

  IOBUF GPIO_PS_tri_iobuf_0
       (.I(GPIO_PS_tri_o_0),
        .IO(GPIO_PS_tri_io[0]),
        .O(GPIO_PS_tri_i_0),
        .T(GPIO_PS_tri_t_0));
  IOBUF GPIO_PS_tri_iobuf_1
       (.I(GPIO_PS_tri_o_1),
        .IO(GPIO_PS_tri_io[1]),
        .O(GPIO_PS_tri_i_1),
        .T(GPIO_PS_tri_t_1));
  IOBUF GPIO_PS_tri_iobuf_2
       (.I(GPIO_PS_tri_o_2),
        .IO(GPIO_PS_tri_io[2]),
        .O(GPIO_PS_tri_i_2),
        .T(GPIO_PS_tri_t_2));
  IOBUF SPI_9361_io0_iobuf
       (.I(SPI_9361_io0_o),
        .IO(SPI_9361_io0_io),
        .O(SPI_9361_io0_i),
        .T(SPI_9361_io0_t));
  IOBUF SPI_9361_io1_iobuf
       (.I(SPI_9361_io1_o),
        .IO(SPI_9361_io1_io),
        .O(SPI_9361_io1_i),
        .T(SPI_9361_io1_t));
  IOBUF SPI_9361_sck_iobuf
       (.I(SPI_9361_sck_o),
        .IO(SPI_9361_sck_io),
        .O(SPI_9361_sck_i),
        .T(SPI_9361_sck_t));
  IOBUF SPI_9361_ss_iobuf
       (.I(SPI_9361_ss_o),
        .IO(SPI_9361_ss_io),
        .O(SPI_9361_ss_i),
        .T(SPI_9361_ss_t));
  design_1 design_1_i
       (.DDR3_0_addr(DDR3_0_addr),
        .DDR3_0_ba(DDR3_0_ba),
        .DDR3_0_cas_n(DDR3_0_cas_n),
        .DDR3_0_ck_n(DDR3_0_ck_n),
        .DDR3_0_ck_p(DDR3_0_ck_p),
        .DDR3_0_cke(DDR3_0_cke),
        .DDR3_0_cs_n(DDR3_0_cs_n),
        .DDR3_0_dm(DDR3_0_dm),
        .DDR3_0_dq(DDR3_0_dq),
        .DDR3_0_dqs_n(DDR3_0_dqs_n),
        .DDR3_0_dqs_p(DDR3_0_dqs_p),
        .DDR3_0_odt(DDR3_0_odt),
        .DDR3_0_ras_n(DDR3_0_ras_n),
        .DDR3_0_reset_n(DDR3_0_reset_n),
        .DDR3_0_we_n(DDR3_0_we_n),
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .GPIO_PS_tri_i({GPIO_PS_tri_i_2,GPIO_PS_tri_i_1,GPIO_PS_tri_i_0}),
        .GPIO_PS_tri_o({GPIO_PS_tri_o_2,GPIO_PS_tri_o_1,GPIO_PS_tri_o_0}),
        .GPIO_PS_tri_t({GPIO_PS_tri_t_2,GPIO_PS_tri_t_1,GPIO_PS_tri_t_0}),
        .SPI_9361_io0_i(SPI_9361_io0_i),
        .SPI_9361_io0_o(SPI_9361_io0_o),
        .SPI_9361_io0_t(SPI_9361_io0_t),
        .SPI_9361_io1_i(SPI_9361_io1_i),
        .SPI_9361_io1_o(SPI_9361_io1_o),
        .SPI_9361_io1_t(SPI_9361_io1_t),
        .SPI_9361_sck_i(SPI_9361_sck_i),
        .SPI_9361_sck_o(SPI_9361_sck_o),
        .SPI_9361_sck_t(SPI_9361_sck_t),
        .SPI_9361_ss1_o(SPI_9361_ss1_o),
        .SPI_9361_ss2_o(SPI_9361_ss2_o),
        .SPI_9361_ss_i(SPI_9361_ss_i),
        .SPI_9361_ss_o(SPI_9361_ss_o),
        .SPI_9361_ss_t(SPI_9361_ss_t),
        .key_0(key_0),
        .out_1_1_0(out_1_1_0),
        .out_1_2_0(out_1_2_0),
        .out_1_3_0(out_1_3_0),
        .out_1_4_0(out_1_4_0),
        .out_1_5_0(out_1_5_0),
        .out_2_1_0(out_2_1_0),
        .out_2_2_0(out_2_2_0),
        .out_2_3_0(out_2_3_0),
        .out_2_4_0(out_2_4_0),
        .out_2_5_0(out_2_5_0),
        .out_3_1_0(out_3_1_0),
        .out_3_2_0(out_3_2_0),
        .out_3_3_0(out_3_3_0),
        .out_3_4_0(out_3_4_0),
        .out_3_5_0(out_3_5_0),
        .out_4_1_0(out_4_1_0),
        .out_4_2_0(out_4_2_0),
        .out_4_3_0(out_4_3_0),
        .out_4_4_0(out_4_4_0),
        .out_4_5_0(out_4_5_0),
        .out_5_1_0(out_5_1_0),
        .out_5_2_0(out_5_2_0),
        .out_5_3_0(out_5_3_0),
        .out_5_4_0(out_5_4_0),
        .out_5_5_0(out_5_5_0),
        .pl_eth_mdio_mdc(pl_eth_mdio_mdc),
        .pl_eth_mdio_mdio_i(pl_eth_mdio_mdio_i),
        .pl_eth_mdio_mdio_o(pl_eth_mdio_mdio_o),
        .pl_eth_mdio_mdio_t(pl_eth_mdio_mdio_t),
        .pl_eth_refclk_clk_n(pl_eth_refclk_clk_n),
        .pl_eth_refclk_clk_p(pl_eth_refclk_clk_p),
        .pl_eth_sgmii_rxn(pl_eth_sgmii_rxn),
        .pl_eth_sgmii_rxp(pl_eth_sgmii_rxp),
        .pl_eth_sgmii_txn(pl_eth_sgmii_txn),
        .pl_eth_sgmii_txp(pl_eth_sgmii_txp),
        .rstn(rstn),
        .rx_clk_n(rx_clk_n),
        .rx_clk_p(rx_clk_p),
        .rx_data_n(rx_data_n),
        .rx_data_p(rx_data_p),
        .rx_frame_n(rx_frame_n),
        .rx_frame_p(rx_frame_p),
        .sys_clk_clk_n(sys_clk_clk_n),
        .sys_clk_clk_p(sys_clk_clk_p));
  IOBUF pl_eth_mdio_mdio_iobuf
       (.I(pl_eth_mdio_mdio_o),
        .IO(pl_eth_mdio_mdio_io),
        .O(pl_eth_mdio_mdio_i),
        .T(pl_eth_mdio_mdio_t));
endmodule
