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


// IP VLNV: xilinx.com:module_ref:key_ctrl_55:1.0
// IP Revision: 1

(* X_CORE_INFO = "key_ctrl_55,Vivado 2020.2" *)
(* CHECK_LICENSE_TYPE = "design_1_key_ctrl_55_0_0,key_ctrl_55,{}" *)
(* CORE_GENERATION_INFO = "design_1_key_ctrl_55_0_0,key_ctrl_55,{x_ipProduct=Vivado 2020.2,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=key_ctrl_55,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,CLK_FREQ_HZ=100000000,DEBOUNCE_MS=20}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module design_1_key_ctrl_55_0_0 (
  clk,
  rst_n,
  key,
  gpio_cfg,
  out_1_1,
  out_1_2,
  out_1_3,
  out_1_4,
  out_1_5,
  out_2_1,
  out_2_2,
  out_2_3,
  out_2_4,
  out_2_5,
  out_3_1,
  out_3_2,
  out_3_3,
  out_3_4,
  out_3_5,
  out_4_1,
  out_4_2,
  out_4_3,
  out_4_4,
  out_4_5,
  out_5_1,
  out_5_2,
  out_5_3,
  out_5_4,
  out_5_5
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_processing_system7_0_2_FCLK_CLK0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
input wire clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
input wire rst_n;
input wire key;
input wire [31 : 0] gpio_cfg;
output wire out_1_1;
output wire out_1_2;
output wire out_1_3;
output wire out_1_4;
output wire out_1_5;
output wire out_2_1;
output wire out_2_2;
output wire out_2_3;
output wire out_2_4;
output wire out_2_5;
output wire out_3_1;
output wire out_3_2;
output wire out_3_3;
output wire out_3_4;
output wire out_3_5;
output wire out_4_1;
output wire out_4_2;
output wire out_4_3;
output wire out_4_4;
output wire out_4_5;
output wire out_5_1;
output wire out_5_2;
output wire out_5_3;
output wire out_5_4;
output wire out_5_5;

  key_ctrl_55 #(
    .CLK_FREQ_HZ(100000000),
    .DEBOUNCE_MS(20)
  ) inst (
    .clk(clk),
    .rst_n(rst_n),
    .key(key),
    .gpio_cfg(gpio_cfg),
    .out_1_1(out_1_1),
    .out_1_2(out_1_2),
    .out_1_3(out_1_3),
    .out_1_4(out_1_4),
    .out_1_5(out_1_5),
    .out_2_1(out_2_1),
    .out_2_2(out_2_2),
    .out_2_3(out_2_3),
    .out_2_4(out_2_4),
    .out_2_5(out_2_5),
    .out_3_1(out_3_1),
    .out_3_2(out_3_2),
    .out_3_3(out_3_3),
    .out_3_4(out_3_4),
    .out_3_5(out_3_5),
    .out_4_1(out_4_1),
    .out_4_2(out_4_2),
    .out_4_3(out_4_3),
    .out_4_4(out_4_4),
    .out_4_5(out_4_5),
    .out_5_1(out_5_1),
    .out_5_2(out_5_2),
    .out_5_3(out_5_3),
    .out_5_4(out_5_4),
    .out_5_5(out_5_5)
  );
endmodule
