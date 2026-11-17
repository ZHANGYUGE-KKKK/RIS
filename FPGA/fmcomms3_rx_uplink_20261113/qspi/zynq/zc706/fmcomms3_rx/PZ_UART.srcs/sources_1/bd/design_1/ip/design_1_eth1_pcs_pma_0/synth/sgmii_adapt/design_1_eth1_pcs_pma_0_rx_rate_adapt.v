//------------------------------------------------------------------------------
// File       : design_1_eth1_pcs_pma_0_rx_rate_adapt.v
// Author     : Xilinx Inc.
//------------------------------------------------------------------------------
// (c) Copyright 2011 Xilinx, Inc. All rights reserved.
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
// 
//------------------------------------------------------------------------------
// Description: This module accepts receiver data from the Ethernet
//              1000BASE-X PCS/PMA or SGMII LogiCORE. At 1 Gbps, this
//              data will be valid on evey clock cycle of the 125MHz
//              reference clock; at 100Mbps, LSB 4 bits are repeated 
//              for five clock periods and then MSB 4 bits will be 
//              for next five clock periods; at 10Mbps, LSB 4 bits will
//              be repeated for a fifty clock period duration and then
//              MSB 4 bits will be repeated for fifty clock period 
//              duration of the 125MHz reference clock.


`timescale 1 ps/1 ps


//------------------------------------------------------------------------------
// The module declaration
//------------------------------------------------------------------------------

module design_1_eth1_pcs_pma_0_rx_rate_adapt
  (
    input            reset,                  // Synchronous reset.
    input            clk125m,                // Reference 125MHz receiver clock.
    input            sgmii_ddr_clk_en,       // Double Clock rate enable pulse for the transmitter logic
    input            speed_is_10_100,        // Select GMII or MII
    input            sgmii_clk_en,           // Clock enable for the receiver logic (125MHz, 25MHz, 2.5MHz).
    input      [7:0] gmii_rxd_in,            // Receive data from client MAC.
    input            gmii_rx_dv_in,          // Receive data valid signal from client MAC.
    input            gmii_rx_er_in,          // Receive error signal from client MAC.
    output reg [7:0] gmii_rxd_out,           // Receive data from client MAC.
    output reg       gmii_rx_dv_out,         // Receive data valid signal from client MAC.
    output reg       gmii_rx_er_out          // Receive error signal from client MAC.
  );

  
   reg [7:0]  gmii_rxd_sel;
   reg        gmii_rx_dv_sel;
   reg        gmii_rx_er_sel;
   reg        toggle;

   initial     //initialize all outputs to 0 at startup
     begin
       gmii_rxd_out = 8'b00000000;
       gmii_rx_dv_out = 1'b0;
       gmii_rx_er_out = 1'b0;
     end

   always @(posedge clk125m)
   begin
       if (reset == 1'b1) begin
           gmii_rxd_sel     <= 8'b0;
           gmii_rx_dv_sel   <= 8'b0;
           gmii_rx_er_sel   <= 1'b0;
       end else begin
           if (sgmii_clk_en == 1'b1) begin
               gmii_rxd_sel     <= gmii_rxd_in;
               gmii_rx_dv_sel   <= gmii_rx_dv_in;
               gmii_rx_er_sel   <= gmii_rx_er_in;
           end
       end
   end
    

 // Sample the correctly aligned data
   always @(posedge clk125m)
   begin
     if (reset == 1'b1) begin
       gmii_rxd_out     <= 8'b0;
       gmii_rx_dv_out   <= 8'b0;
       gmii_rx_er_out   <= 1'b0;
     end
     else begin
       if (speed_is_10_100 == 1'b1)  begin
           if (sgmii_ddr_clk_en == 1'b1) begin
                   gmii_rx_dv_out <= gmii_rx_dv_sel;
                   gmii_rx_er_out <= gmii_rx_er_sel;
               if (toggle == 1'b1) begin
                   gmii_rxd_out   <= gmii_rxd_sel[3:0];
               end else begin
                   gmii_rxd_out   <= gmii_rxd_sel[7:4];
               end
           end
       end else begin
           if (sgmii_clk_en == 1'b1) begin
               gmii_rxd_out   <= gmii_rxd_sel;
               gmii_rx_dv_out <= gmii_rx_dv_sel;
               gmii_rx_er_out <= gmii_rx_er_sel;
           end
       end
       
       if (sgmii_clk_en == 1'b1) begin
           toggle <= 1'b1;
       end else if (sgmii_ddr_clk_en == 1'b1) begin
           toggle <= 1'b0;
       end
     end
   end


endmodule

