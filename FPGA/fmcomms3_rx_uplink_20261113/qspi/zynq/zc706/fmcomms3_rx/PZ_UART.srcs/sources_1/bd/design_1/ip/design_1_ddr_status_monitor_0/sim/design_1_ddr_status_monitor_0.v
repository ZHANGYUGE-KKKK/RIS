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


// IP VLNV: xilinx.com:module_ref:ddr_status_cdc:1.0
// IP Revision: 1

`timescale 1ns/1ps

(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module design_1_ddr_status_monitor_0 (
  clk200,
  in_ui_reset,
  in_resetn,
  in_mmcm_locked,
  in_calib,
  out_ui_reset,
  out_resetn,
  out_mmcm_locked,
  out_calib
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk200, FREQ_HZ 200000000, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_util_ds_buf_0_0_IBUF_OUT, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk200 CLK" *)
input wire clk200;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME in_ui_reset, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 in_ui_reset RST" *)
input wire in_ui_reset;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME in_resetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 in_resetn RST" *)
input wire in_resetn;
input wire in_mmcm_locked;
input wire in_calib;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME out_ui_reset, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 out_ui_reset RST" *)
output wire out_ui_reset;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME out_resetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 out_resetn RST" *)
output wire out_resetn;
output wire out_mmcm_locked;
output wire out_calib;

  ddr_status_cdc inst (
    .clk200(clk200),
    .in_ui_reset(in_ui_reset),
    .in_resetn(in_resetn),
    .in_mmcm_locked(in_mmcm_locked),
    .in_calib(in_calib),
    .out_ui_reset(out_ui_reset),
    .out_resetn(out_resetn),
    .out_mmcm_locked(out_mmcm_locked),
    .out_calib(out_calib)
  );
endmodule
