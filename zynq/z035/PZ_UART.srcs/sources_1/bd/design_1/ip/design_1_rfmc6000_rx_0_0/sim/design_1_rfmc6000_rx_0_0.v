// (c) Copyright 1995-2026 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:module_ref:rfmc6000_rx:1.0
// IP Revision: 1

`timescale 1ns/1ps

(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module design_1_rfmc6000_rx_0_0 (
  rx_clk_p,
  rx_clk_n,
  rx_frame_in_p,
  rx_frame_in_n,
  rx_data_in_p,
  rx_data_in_n,
  clk200,
  rstn,
  control,
  data_clk,
  rx_resetn,
  delay_ready,
  adc_valid,
  adc_status,
  adc_data_i1,
  adc_data_q1,
  adc_data_i2,
  adc_data_q2
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rx_clk_p, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_rx_clk_p_0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 rx_clk_p CLK" *)
input wire rx_clk_p;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rx_clk_n, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_rx_clk_n_0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 rx_clk_n CLK" *)
input wire rx_clk_n;
input wire rx_frame_in_p;
input wire rx_frame_in_n;
input wire [5 : 0] rx_data_in_p;
input wire [5 : 0] rx_data_in_n;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk200, FREQ_HZ 200000000, ASSOCIATED_RESET rstn, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_IBUF_DS_N_0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk200 CLK" *)
input wire clk200;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rstn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rstn RST" *)
input wire rstn;
input wire [31 : 0] control;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME data_clk, FREQ_HZ 245760000, ASSOCIATED_RESET rx_resetn, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_rfmc6000_rx_0_0_data_clk, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 data_clk CLK" *)
output wire data_clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rx_resetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rx_resetn RST" *)
output wire rx_resetn;
output wire delay_ready;
output wire adc_valid;
output wire adc_status;
output wire [11 : 0] adc_data_i1;
output wire [11 : 0] adc_data_q1;
output wire [11 : 0] adc_data_i2;
output wire [11 : 0] adc_data_q2;

  rfmc6000_rx inst (
    .rx_clk_p(rx_clk_p),
    .rx_clk_n(rx_clk_n),
    .rx_frame_in_p(rx_frame_in_p),
    .rx_frame_in_n(rx_frame_in_n),
    .rx_data_in_p(rx_data_in_p),
    .rx_data_in_n(rx_data_in_n),
    .clk200(clk200),
    .rstn(rstn),
    .control(control),
    .data_clk(data_clk),
    .rx_resetn(rx_resetn),
    .delay_ready(delay_ready),
    .adc_valid(adc_valid),
    .adc_status(adc_status),
    .adc_data_i1(adc_data_i1),
    .adc_data_q1(adc_data_q1),
    .adc_data_i2(adc_data_i2),
    .adc_data_q2(adc_data_q2)
  );
endmodule
