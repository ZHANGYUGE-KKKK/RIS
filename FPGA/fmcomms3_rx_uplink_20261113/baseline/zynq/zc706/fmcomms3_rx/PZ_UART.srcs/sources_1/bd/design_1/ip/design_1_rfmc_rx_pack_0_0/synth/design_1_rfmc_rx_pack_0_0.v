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


// IP VLNV: xilinx.com:module_ref:rfmc_rx_pack:1.0
// IP Revision: 1

(* X_CORE_INFO = "rfmc_rx_pack,Vivado 2020.2" *)
(* CHECK_LICENSE_TYPE = "design_1_rfmc_rx_pack_0_0,rfmc_rx_pack,{}" *)
(* CORE_GENERATION_INFO = "design_1_rfmc_rx_pack_0_0,rfmc_rx_pack,{x_ipProduct=Vivado 2020.2,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=rfmc_rx_pack,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module design_1_rfmc_rx_pack_0_0 (
  adc_clk,
  adc_resetn,
  adc_valid,
  adc_status,
  delay_ready,
  adc_i1,
  adc_q1,
  adc_i2,
  adc_q2,
  overflow,
  frame_error,
  m_axis_tdata,
  m_axis_tvalid,
  m_axis_tready
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME adc_clk, ASSOCIATED_RESET adc_resetn, ASSOCIATED_BUSIF M_AXIS, FREQ_HZ 245760000, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_rfmc6000_rx_0_0_data_clk, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 adc_clk CLK" *)
input wire adc_clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME adc_resetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 adc_resetn RST" *)
input wire adc_resetn;
input wire adc_valid;
input wire adc_status;
input wire delay_ready;
input wire [11 : 0] adc_i1;
input wire [11 : 0] adc_q1;
input wire [11 : 0] adc_i2;
input wire [11 : 0] adc_q2;
output wire overflow;
output wire frame_error;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
output wire [63 : 0] m_axis_tdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
output wire m_axis_tvalid;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXIS, TDATA_NUM_BYTES 8, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 245760000, PHASE 0.000, CLK_DOMAIN design_1_rfmc6000_rx_0_0_data_clk, LAYERED_METADATA undef, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
input wire m_axis_tready;

  rfmc_rx_pack inst (
    .adc_clk(adc_clk),
    .adc_resetn(adc_resetn),
    .adc_valid(adc_valid),
    .adc_status(adc_status),
    .delay_ready(delay_ready),
    .adc_i1(adc_i1),
    .adc_q1(adc_q1),
    .adc_i2(adc_i2),
    .adc_q2(adc_q2),
    .overflow(overflow),
    .frame_error(frame_error),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready)
  );
endmodule
