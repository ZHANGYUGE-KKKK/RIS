// ***************************************************************************
// ***************************************************************************
// Copyright (C) 2014-2024 Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/main/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

// Receive-only extraction of ADI axi_ad9361_lvds_if, commit
// 4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91. The supported configuration is
// USE_SSI_CLK=1, CLK_DESKEW=0: DATA_CLK directly clocks every receive stage.
// Keep the SAME_EDGE pairing, frame cases and output latency unchanged.
module ad9361_rx_lvds_if #(
  parameter FPGA_TECHNOLOGY = 1,
  parameter IO_DELAY_GROUP = "AD9361_RX_DELAY",
  parameter DELAY_REFCLK_FREQUENCY = 200
) (
  input rx_clk_in_p,
  input rx_clk_in_n,
  input rx_frame_in_p,
  input rx_frame_in_n,
  input [5:0] rx_data_in_p,
  input [5:0] rx_data_in_n,
  output l_clk,
  input adc_r1_mode,
  output adc_valid,
  output [47:0] adc_data,
  output adc_status,
  input up_clk,
  input [6:0] up_adc_dld,
  input [34:0] up_adc_dwdata,
  output [34:0] up_adc_drdata,
  input delay_clk,
  input delay_rst,
  output delay_locked,
  output [1:0] debug_frame,
  output [1:0] debug_frame_previous,
  output [5:0] debug_data_rise,
  output [5:0] debug_data_fall
);
  // 1. Physical clock and all seven LVDS lanes use the upstream primitives.
  // Q1/Q2 are a SAME_EDGE pair; do not delay only one of the two outputs.
  wire [5:0] rx_data_1_s;
  wire [5:0] rx_data_0_s;
  wire [1:0] rx_frame_s;
  wire locked_s;
  ad_data_clk i_clk (
    .rst(1'b0), .locked(),
    .clk_in_p(rx_clk_in_p), .clk_in_n(rx_clk_in_n), .clk(l_clk));

  genvar i;
  generate for (i=0; i<6; i=i+1) begin: g_rx_data
    ad_data_in #(
      .FPGA_TECHNOLOGY(FPGA_TECHNOLOGY), .IDDR_CLK_EDGE("SAME_EDGE"),
      .IODELAY_CTRL(0), .IODELAY_GROUP(IO_DELAY_GROUP),
      .REFCLK_FREQUENCY(DELAY_REFCLK_FREQUENCY)
    ) i_rx_data (
      .rx_clk(l_clk),
      .rx_data_in_p(rx_data_in_p[i]), .rx_data_in_n(rx_data_in_n[i]),
      .rx_data_p(rx_data_1_s[i]), .rx_data_n(rx_data_0_s[i]),
      .up_clk(up_clk), .up_dld(up_adc_dld[i]),
      .up_dwdata(up_adc_dwdata[i*5+:5]), .up_drdata(up_adc_drdata[i*5+:5]),
      .delay_clk(delay_clk), .delay_rst(delay_rst), .delay_locked());
  end endgenerate

  // One IDELAYCTRL is shared by FRAME and all six data lanes in this group.
  ad_data_in #(
    .FPGA_TECHNOLOGY(FPGA_TECHNOLOGY), .IDDR_CLK_EDGE("SAME_EDGE"),
    .IODELAY_CTRL(1), .IODELAY_GROUP(IO_DELAY_GROUP),
    .REFCLK_FREQUENCY(DELAY_REFCLK_FREQUENCY)
  ) i_rx_frame (
    .rx_clk(l_clk),
    .rx_data_in_p(rx_frame_in_p), .rx_data_in_n(rx_frame_in_n),
    .rx_data_p(rx_frame_s[1]), .rx_data_n(rx_frame_s[0]),
    .up_clk(up_clk), .up_dld(up_adc_dld[6]),
    .up_dwdata(up_adc_dwdata[34:30]), .up_drdata(up_adc_drdata[34:30]),
    .delay_clk(delay_clk), .delay_rst(delay_rst), .delay_locked(locked_s));
  assign delay_locked = locked_s;

  // 2. Register mode, IDELAY readiness and the previous complete DDR pair.
  // Like upstream, the sampling pipeline runs during ADC-core reset. Only
  // configuration/startup initialization is used here; the downstream ADI
  // receiver owns its reset and suppresses output until it is released.
  reg rx_r1_mode = 0;
  reg rx_locked_m1 = 0, rx_locked = 0;
  reg [1:0] rx_frame = 0;
  reg [5:0] rx_data_1 = 0, rx_data_0 = 0;
  always @(posedge l_clk) begin
    rx_r1_mode <= adc_r1_mode;
    rx_locked_m1 <= locked_s;
    rx_locked <= rx_locked_m1;
    rx_frame <= rx_frame_s;
    rx_data_1 <= rx_data_1_s;
    rx_data_0 <= rx_data_0_s;
  end

  // 3. Upstream delineation, with no new acceptance or resynchronization rule.
  // For 2R2T, FRAME=11 spans RX1 MSB/LSB then FRAME=00 spans RX2 MSB/LSB.
  // Emit one {Q2,I2,Q1,I1} tuple after the second RX2 pair.
  reg adc_valid_p = 0;
  reg [47:0] adc_data_p = 0;
  reg adc_status_p = 0;
  wire rx_error = ^rx_frame;
  always @(posedge l_clk) begin
    case ({rx_r1_mode, rx_frame_s, rx_frame})
      5'b01111: begin
        adc_valid_p <= 1'b0;
        adc_data_p[23:12] <= {rx_data_1, rx_data_1_s};
        adc_data_p[11:0] <= {rx_data_0, rx_data_0_s};
      end
      5'b00000: begin
        adc_valid_p <= 1'b1;
        adc_data_p[47:36] <= {rx_data_1, rx_data_1_s};
        adc_data_p[35:24] <= {rx_data_0, rx_data_0_s};
      end
      5'b10011: begin
        adc_valid_p <= 1'b1;
        adc_data_p[47:24] <= 24'd0;
        adc_data_p[23:12] <= {rx_data_1, rx_data_1_s};
        adc_data_p[11:0] <= {rx_data_0, rx_data_0_s};
      end
      default: adc_valid_p <= 1'b0;
    endcase
    adc_status_p <= ~rx_error & rx_locked;
  end

  // 4. Preserve the upstream native-clock output register and its latency.
  reg adc_valid_int = 0;
  reg [47:0] adc_data_int = 0;
  reg adc_status_int = 0;
  always @(posedge l_clk) begin
    adc_valid_int <= adc_valid_p;
    adc_data_int <= adc_data_p;
    adc_status_int <= adc_status_p;
  end
  assign adc_valid = adc_valid_int;
  assign adc_data = adc_data_int;
  assign adc_status = adc_status_int;

  // Read-only taps. They do not qualify data or change sampling latency.
  assign debug_frame = rx_frame_s;
  assign debug_frame_previous = rx_frame;
  assign debug_data_rise = rx_data_1_s;
  assign debug_data_fall = rx_data_0_s;
endmodule
