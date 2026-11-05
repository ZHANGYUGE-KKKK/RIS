// ***************************************************************************
// ***************************************************************************
// Copyright 2011(c) Analog Devices, Inc.
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//    
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************
`timescale 1ns/100ps

module axi_ad9361_dev_if_idelay (
// physical interface (receive)
input rx_frame_in_p,
input rx_frame_in_n,
input [5:0] rx_data_in_p,
input [5:0] rx_data_in_n,
// physical interface (transmit)
output tx_clk_out_p,
output tx_clk_out_n,
output tx_frame_out_p,
output tx_frame_out_n,
output [5:0] tx_data_out_p,
output [5:0] tx_data_out_n,
// internal clock
input data_clk,
input clk200,
input rstn,
// receive data path interface
output reg adc_valid,
output reg [11:0] adc_data_i1,
output reg [11:0] adc_data_q1,
output reg [11:0] adc_data_i2,
output reg [11:0] adc_data_q2,
output reg adc_status,
input adc_r1_mode,
// transmit data path interface
input dac_valid,
input [11:0] dac_data_i1,
input [11:0] dac_data_q1,
input [11:0] dac_data_i2,
input [11:0] dac_data_q2,
input dac_r1_mode,
output [63:0] chip_data,
// idelay
input [6:0] idly_en,
input [4:0] idly_d
);
// internal registers
reg [ 5:0]  rx_data_n     = 'd0;
reg         rx_frame_n    = 'd0;
reg [11:0]  rx_data       = 'd0;
reg [ 1:0]  rx_frame      = 'd0;
reg [11:0]  rx_data_d     = 'd0;
reg [ 1:0]  rx_frame_d    = 'd0;
reg         rx_error_r1   = 'd0;
reg         rx_valid_r1   = 'd0;
reg [11:0]  rx_data_i_r1  = 'd0;
reg [11:0]  rx_data_q_r1  = 'd0;
reg         rx_error_r2   = 'd0;
reg         rx_valid_r2   = 'd0;
reg [11:0]  rx_data_i1_r2 = 'd0;
reg [11:0]  rx_data_q1_r2 = 'd0;
reg [11:0]  rx_data_i2_r2 = 'd0;
reg [11:0]  rx_data_q2_r2 = 'd0;
reg [ 2:0]  tx_data_cnt   = 'd0;
reg [11:0]  tx_data_i1_d  = 'd0;
reg [11:0]  tx_data_q1_d  = 'd0;
reg [11:0]  tx_data_i2_d  = 'd0;
reg [11:0]  tx_data_q2_d  = 'd0;
reg         tx_frame      = 'd0;
reg [ 5:0]  tx_data_p     = 'd0;
reg [ 5:0]  tx_data_n     = 'd0;
// internal signals
wire    [ 3:0]  rx_frame_s;
wire    [ 3:0]  tx_data_sel_s;
wire    [ 5:0]  rx_data_ibuf_s;
wire    [ 5:0]  rx_data_idelay;
wire    [ 5:0]  rx_data_p_s;
wire    [ 5:0]  rx_data_n_s;
wire            rx_frame_ibuf_s;
wire            rx_frame_idelay;
wire            rx_frame_p_s;
wire            rx_frame_n_s;
wire    [ 5:0]  tx_data_oddr_s;
wire            tx_frame_oddr_s;
wire            tx_clk_oddr_s;
genvar          l_inst;

//assign chip_data={
//16'd0,
//rx_error_r2,  //47
//rx_valid_r2,  //46
//rx_data_p_s,  //45:40
//rx_data_n,    //39:34
//rx_data,      //33:22
//rx_data_d,    //21:10
//
//rx_frame_p_s, //9
//rx_frame_n,   //8
//rx_frame,     //7:6
//rx_frame_d,   //5:4
//rx_frame_s    //3:0
//};
assign chip_data={
10'd0,
rx_error_r2,  //53
rx_valid_r2,  //52
rx_frame_s ,  //51:48
adc_data_i1,  //47:36
adc_data_q1,  //35:24
adc_data_i2,  //23:12
adc_data_q2   //11:0

};
//receive data path interface
assign rx_frame_s = {rx_frame_d, rx_frame};
always @(posedge data_clk)
  begin
    rx_data_n   <=rx_data_n_s;
    rx_frame_n  <=rx_frame_n_s;
    rx_data     <={rx_data_n,rx_data_p_s};
    rx_frame    <={rx_frame_n,rx_frame_p_s};
    rx_data_d   <=rx_data;
    rx_frame_d  <=rx_frame;
  end
//receive data path for single rf, frame is expected to qualify i/q msb only
always @(posedge data_clk)
  begin
    rx_error_r1<=((rx_frame_s==4'b1100)||(rx_frame_s==4'b0011))?1'b0:1'b1;
    rx_valid_r1<=(rx_frame_s==4'b1100)?1'b1:1'b0;
    if (rx_frame_s==4'b1100)
      begin
        rx_data_i_r1<={rx_data_d[11:6],rx_data[11:6]};
        rx_data_q_r1<={rx_data_d[ 5:0],rx_data[ 5:0]};
      end
  end
//receive data path for dual rf, frame is expected to qualify i/q msb and lsb for rf-1 only
always @(posedge data_clk)
  begin
    rx_error_r2<=((rx_frame_s==4'b1111)||(rx_frame_s==4'b1100)||(rx_frame_s==4'b0000)||(rx_frame_s== 4'b0011))?1'b0:1'b1;
    rx_valid_r2<=(rx_frame_s==4'b0000)?1'b1:1'b0;
    if(rx_frame_s==4'b1111)
      begin
        rx_data_i1_r2<={rx_data_d[11:6],rx_data[11:6]};
        rx_data_q1_r2<={rx_data_d[ 5:0],rx_data[ 5:0]};
      end
    if(rx_frame_s==4'b0000)
      begin
        rx_data_i2_r2<={rx_data_d[11:6],rx_data[11:6]};
        rx_data_q2_r2<={rx_data_d[ 5:0],rx_data[ 5:0]};
      end
  end
//receive data path mux
always @(posedge data_clk)
  begin
    if(adc_r1_mode==1'b1)
      begin
        adc_valid   <=rx_valid_r1;
        adc_data_i1 <=rx_data_i_r1;
        adc_data_q1 <=rx_data_q_r1;
        adc_data_i2 <=12'd0;
        adc_data_q2 <=12'd0;
        adc_status  <=~rx_error_r1;
      end
    else
      begin
        adc_valid   <=rx_valid_r2;
        adc_data_i1 <=rx_data_i1_r2;
        adc_data_q1 <=rx_data_q1_r2;
        adc_data_i2 <=rx_data_i2_r2;
        adc_data_q2 <=rx_data_q2_r2;
        adc_status  <=~rx_error_r2;
      end
  end

// transmit data path mux (reverse of what receive does above)
// the count simply selets the data muxing on the ddr outputs
//------------------data format 1t--------------------------
//valid :~~~ ___ ~~~ ___ ~~~ ___ ~~~ ___                  //
//datai :i1      i1      i1      i1                       //
//dataq :q1      q1      q1      q1                       //
//cnt   :    100 101 100 101 100 101 100                  //
//------------------data format 2t--------------------------
//valid :~~~ ___ ___ ___ ~~~ ___ ___ ___ ~~~ ___ ___ ___  //
//datai :i1              i1              i1               //
//dataq :q1              q1              q1               //
//datai :i2              i2              i2               //
//dataq :q2              q2              q2               //
//cnt   :    100 101 110 111 100 101 110 111 100 101 110  //
//----------------------------------------------------------
assign tx_data_sel_s={tx_data_cnt[2],dac_r1_mode,tx_data_cnt[1:0]};
always @(posedge data_clk)
  begin
    if (dac_valid)
      begin
        tx_data_cnt<=3'b100;
        tx_data_i1_d<=dac_data_i1;
        tx_data_q1_d<=dac_data_q1;
        tx_data_i2_d<=dac_data_i2;
        tx_data_q2_d<=dac_data_q2;
       end
    else if(tx_data_cnt[2]==1'b1)
      tx_data_cnt<=tx_data_cnt+1'b1;
    case (tx_data_sel_s)
      4'b1101:
        begin
          tx_frame  <=1'b0;
          tx_data_p <=tx_data_i1_d[ 5:0];
          tx_data_n <=tx_data_q1_d[ 5:0];
        end
      4'b1100:
        begin
          tx_frame  <=1'b1;
          tx_data_p <=tx_data_i1_d[11:6];
          tx_data_n <=tx_data_q1_d[11:6];
        end
      4'b1011:
        begin
          tx_frame  <=1'b0;
          tx_data_p <=tx_data_i2_d[ 5:0];
          tx_data_n <=tx_data_q2_d[ 5:0];
        end
      4'b1010:
        begin
          tx_frame  <=1'b0;
          tx_data_p <=tx_data_i2_d[11:6];
          tx_data_n <=tx_data_q2_d[11:6];
        end
      4'b1001:
        begin
          tx_frame  <=1'b1;
          tx_data_p <=tx_data_i1_d[ 5:0];
          tx_data_n <=tx_data_q1_d[ 5:0];
        end
      4'b1000:
        begin
          tx_frame  <=1'b1;
          tx_data_p <=tx_data_i1_d[11:6];
          tx_data_n <=tx_data_q1_d[11:6];
        end
      default:
        begin
          tx_frame  <=1'b0;
          tx_data_p <=6'd0;
          tx_data_n <=6'd0;
        end
    endcase
  end
// receive data interface, ibuf  -> iddr
IDELAYCTRL IDELAYCTRL1 (
.RDY    (RDY      ),// 1-bit output: Ready output
.REFCLK (clk200   ),// 1-bit input: Reference clock input
.RST    (~rstn    ) // 1-bit input: Active high reset input
);
generate
for (l_inst=0;l_inst<=5;l_inst=l_inst+1)
begin:g_rx_data
IBUFDS i_rx_data_ibuf(.I(rx_data_in_p[l_inst]),.IB(rx_data_in_n[l_inst]),.O(rx_data_ibuf_s[l_inst]));
IDELAYE2 #(
.CINVCTRL_SEL         ("FALSE"    ),// Enable dynamic clock inversion (FALSE, TRUE)
.DELAY_SRC            ("IDATAIN"  ),// Delay input (IDATAIN, DATAIN)
.HIGH_PERFORMANCE_MODE("FALSE"    ),// Reduced jitter ("TRUE"), Reduced power ("FALSE")
.IDELAY_TYPE          ("VAR_LOAD" ),// FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
.IDELAY_VALUE         (0          ),// Input delay tap setting (0-31)
.PIPE_SEL             ("FALSE"    ),// Select pipelined mode, FALSE, TRUE
.REFCLK_FREQUENCY     (200.0      ),// IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
.SIGNAL_PATTERN       ("DATA"     ) // DATA, CLOCK input signal
)
IDELAYE2_D (
.CNTVALUEOUT  (                       ),// 5-bit output: Counter value output
.DATAOUT      (rx_data_idelay[l_inst] ),// 1-bit output: Delayed data output
.C            (clk200                 ),// 1-bit input: Clock input
.CE           (1'b0                   ),// 1-bit input: Active high enable increment/decrement input
.CINVCTRL     (                       ),// 1-bit input: Dynamic clock inversion input
.CNTVALUEIN   (idly_d                 ),// 5-bit input: Counter value input
.DATAIN       (                       ),// 1-bit input: Internal delay data input
.IDATAIN      (rx_data_ibuf_s[l_inst] ),// 1-bit input: Data input from the I/O
.INC          (1'b0                   ),// 1-bit input: Increment / Decrement tap delay input
.LD           (idly_en[l_inst]        ),// 1-bit input: Load IDELAY_VALUE input
.LDPIPEEN     (                       ),// 1-bit input: Enable PIPELINE register to load data input
.REGRST       (1'b0                   ) // 1-bit input: Active-high reset tap-delay input
);
IDDR #(
.DDR_CLK_EDGE ("SAME_EDGE_PIPELINED"    ),
.INIT_Q1      (1'b0                     ),
.INIT_Q2      (1'b0                     ),
.SRTYPE       ("ASYNC"                  ))
i_rx_data_iddr  ( 
.CE           (1'b1                     ),
.R            (1'b0                     ),
.S            (1'b0                     ),
.C            (data_clk                 ),
.D            (rx_data_idelay[l_inst]   ),
.Q1           (rx_data_p_s[l_inst]      ),
.Q2           (rx_data_n_s[l_inst]      ));
end endgenerate
// receive frame interface, ibuf  -> iddr
IBUFDS i_rx_frame_ibuf (.I(rx_frame_in_p),.IB(rx_frame_in_n),.O(rx_frame_ibuf_s));
IDELAYE2 #(
.CINVCTRL_SEL         ("FALSE"    ),// Enable dynamic clock inversion (FALSE, TRUE)
.DELAY_SRC            ("IDATAIN"  ),// Delay input (IDATAIN, DATAIN)
.HIGH_PERFORMANCE_MODE("FALSE"    ),// Reduced jitter ("TRUE"), Reduced power ("FALSE")
.IDELAY_TYPE          ("VAR_LOAD" ),// FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
.IDELAY_VALUE         (0          ),// Input delay tap setting (0-31)
.PIPE_SEL             ("FALSE"    ),// Select pipelined mode, FALSE, TRUE
.REFCLK_FREQUENCY     (200.0      ),// IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
.SIGNAL_PATTERN       ("DATA"     ) // DATA, CLOCK input signal
)
IDELAYE2_F (
.CNTVALUEOUT  (                 ),// 5-bit output: Counter value output
.DATAOUT      (rx_frame_idelay  ),// 1-bit output: Delayed data output
.C            (clk200           ),// 1-bit input: Clock input
.CE           (1'b0             ),// 1-bit input: Active high enable increment/decrement input
.CINVCTRL     (                 ),// 1-bit input: Dynamic clock inversion input
.CNTVALUEIN   (idly_d           ),// 5-bit input: Counter value input
.DATAIN       (                 ),// 1-bit input: Internal delay data input
.IDATAIN      (rx_frame_ibuf_s  ),// 1-bit input: Data input from the I/O
.INC          (1'b0             ),// 1-bit input: Increment / Decrement tap delay input
.LD           (idly_en[6]       ),// 1-bit input: Load IDELAY_VALUE input
.LDPIPEEN     (                 ),// 1-bit input: Enable PIPELINE register to load data input
.REGRST       (1'b0             ) // 1-bit input: Active-high reset tap-delay input
);
IDDR #(
.DDR_CLK_EDGE   ("SAME_EDGE_PIPELINED"  ),
.INIT_Q1        (1'b0                   ),
.INIT_Q2        (1'b0                   ),
.SRTYPE         ("ASYNC"                ))
i_rx_frame_iddr ( 
.CE             (1'b1                   ),
.R              (1'b0                   ),
.S              (1'b0                   ),
.C              (data_clk               ),
.D              (rx_frame_idelay        ),
.Q1             (rx_frame_p_s           ),
.Q2             (rx_frame_n_s           ));
// transmit data interface, oddr -> obuf
generate
for (l_inst=0;l_inst<=5;l_inst=l_inst+1)
begin: g_tx_data
ODDR #(
.DDR_CLK_EDGE   ("SAME_EDGE"            ),
.INIT           (1'b0                   ),
.SRTYPE         ("ASYNC"                ))
i_tx_data_oddr  (   
.CE             (1'b1                   ),
.R              (1'b0                   ),
.S              (1'b0                   ),
.C              (data_clk               ),
.D1             (tx_data_p[l_inst]      ),
.D2             (tx_data_n[l_inst]      ),
.Q              (tx_data_oddr_s[l_inst] ));
OBUFDS i_tx_data_obuf (.I(tx_data_oddr_s[l_inst]),.O(tx_data_out_p[l_inst]),.OB(tx_data_out_n[l_inst]));
end endgenerate
// transmit frame interface, oddr -> obuf
ODDR #(
.DDR_CLK_EDGE   ("SAME_EDGE"            ),
.INIT           (1'b0                   ),
.SRTYPE         ("ASYNC"                ))
i_tx_frame_oddr (
.CE             (1'b1                   ),
.R              (1'b0                   ),
.S              (1'b0                   ),
.C              (data_clk               ),
.D1             (tx_frame               ),
.D2             (tx_frame               ),
.Q              (tx_frame_oddr_s        ));
OBUFDS i_tx_frame_obuf (.I(tx_frame_oddr_s),.O(tx_frame_out_p),.OB(tx_frame_out_n));
// transmit clock interface, oddr -> obuf
ODDR #(
.DDR_CLK_EDGE   ("SAME_EDGE"            ),
.INIT           (1'b0                   ),
.SRTYPE         ("ASYNC"                ))
i_tx_clk_oddr   (
.CE             (1'b1                   ),
.R              (1'b0                   ),
.S              (1'b0                   ),
.C              (data_clk               ),
.D1             (1'b0                   ),
.D2             (1'b1                   ),
.Q              (tx_clk_oddr_s          ));
OBUFDS i_tx_clk_obuf (.I(tx_clk_oddr_s),.O(tx_clk_out_p),.OB(tx_clk_out_n));
endmodule
