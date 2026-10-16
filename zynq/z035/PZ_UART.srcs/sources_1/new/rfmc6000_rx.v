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
`timescale 1ns / 1ps

// RX-only derivative of the supplied ADI/RFMC6000 7-series device interface.
// Frame decoding expects the standard LVDS DDR 1R/2R format in that example.
module rfmc6000_rx (
    input wire rx_clk_p, rx_clk_n,
    input wire rx_frame_in_p, rx_frame_in_n,
    input wire [5:0] rx_data_in_p, rx_data_in_n,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk200 CLK" *)
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 200000000, ASSOCIATED_RESET rstn" *)
    input wire clk200,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rstn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire rstn,
    input wire [31:0] control,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 data_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 245760000, ASSOCIATED_RESET rx_resetn" *)
    output wire data_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rx_resetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    output wire rx_resetn,
    output wire delay_ready,
    output wire adc_valid, adc_status,
    output reg [11:0] adc_data_i1, adc_data_q1, adc_data_i2, adc_data_q2
);
    wire rx_clk_ibuf;
    IBUFDS rx_clk_buf (.I(rx_clk_p), .IB(rx_clk_n), .O(rx_clk_ibuf));
    BUFG rx_clk_global (.I(rx_clk_ibuf), .O(data_clk));
    wire idelay_ready_ref;
    reg [5:0] reset_wait;
    (* ASYNC_REG = "TRUE" *) reg [31:0] ctrl_meta, ctrl_sync;
    reg [4:0] tap_d;
    wire idelay_reset = !rstn || !(&reset_wait);
    wire [4:0] idly_d = ctrl_sync[12:8];
    wire [6:0] idly_en = {7{(tap_d != idly_d) && !idelay_reset}};
    always @(posedge clk200 or negedge rstn) begin
        if (!rstn) begin
            reset_wait <= 0; ctrl_meta <= 0; ctrl_sync <= 0; tap_d <= 0;
        end else begin
            if (!(&reset_wait)) reset_wait <= reset_wait + 1;
            ctrl_meta <= control; ctrl_sync <= ctrl_meta; tap_d <= idly_d;
        end
    end
    (* ASYNC_REG = "TRUE" *) reg [1:0] rx_reset_pipe;
    (* ASYNC_REG = "TRUE" *) reg mode_meta, adc_r1_mode;
    reg [3:0] warmup;
    reg adc_valid_reg, adc_status_reg;
    // CONTROL[3] resets RX alignment/FIFO/sticky errors without restarting MIG.
    wire rx_reset_asyncn = rstn && idelay_ready_ref && !ctrl_sync[3];
    always @(posedge data_clk or negedge rx_reset_asyncn) begin
        if (!rx_reset_asyncn) begin
            rx_reset_pipe <= 0; mode_meta <= 0; adc_r1_mode <= 0; warmup <= 0;
        end else begin
            rx_reset_pipe <= {rx_reset_pipe[0], 1'b1};
            mode_meta <= control[2]; adc_r1_mode <= mode_meta;
            if (!rx_reset_pipe[1]) warmup <= 0;
            else if (!(&warmup)) warmup <= warmup + 1;
        end
    end
    assign rx_resetn = rx_reset_pipe[1];
    assign delay_ready = rx_resetn && (&warmup);
    assign adc_valid = adc_valid_reg && delay_ready;
    assign adc_status = !delay_ready || adc_status_reg;
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
// internal signals
wire    [ 3:0]  rx_frame_s;
wire    [ 5:0]  rx_data_ibuf_s;
wire    [ 5:0]  rx_data_idelay;
wire    [ 5:0]  rx_data_p_s;
wire    [ 5:0]  rx_data_n_s;
wire            rx_frame_ibuf_s;
wire            rx_frame_idelay;
wire            rx_frame_p_s;
wire            rx_frame_n_s;
genvar          l_inst;

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
        adc_valid_reg   <=rx_valid_r1;
        adc_data_i1 <=rx_data_i_r1;
        adc_data_q1 <=rx_data_q_r1;
        adc_data_i2 <=12'd0;
        adc_data_q2 <=12'd0;
        adc_status_reg  <=~rx_error_r1;
      end
    else
      begin
        adc_valid_reg   <=rx_valid_r2;
        adc_data_i1 <=rx_data_i1_r2;
        adc_data_q1 <=rx_data_q1_r2;
        adc_data_i2 <=rx_data_i2_r2;
        adc_data_q2 <=rx_data_q2_r2;
        adc_status_reg  <=~rx_error_r2;
      end
  end

// receive data interface, ibuf  -> iddr
(* IODELAY_GROUP = "RFMC_RX_DELAY" *) IDELAYCTRL IDELAYCTRL1 (
.RDY    (idelay_ready_ref),// 1-bit output: Ready output
.REFCLK (clk200   ),// 1-bit input: Reference clock input
.RST    (idelay_reset) // 1-bit input: Active high reset input
);
generate
for (l_inst=0;l_inst<=5;l_inst=l_inst+1)
begin:g_rx_data
IBUFDS i_rx_data_ibuf(.I(rx_data_in_p[l_inst]),.IB(rx_data_in_n[l_inst]),.O(rx_data_ibuf_s[l_inst]));
(* IODELAY_GROUP = "RFMC_RX_DELAY" *) IDELAYE2 #(
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
.CINVCTRL     (1'b0                  ),// 1-bit input: Dynamic clock inversion input
.CNTVALUEIN   (idly_d                 ),// 5-bit input: Counter value input
.DATAIN       (1'b0                  ),// 1-bit input: Internal delay data input
.IDATAIN      (rx_data_ibuf_s[l_inst] ),// 1-bit input: Data input from the I/O
.INC          (1'b0                   ),// 1-bit input: Increment / Decrement tap delay input
.LD           (idly_en[l_inst]        ),// 1-bit input: Load IDELAY_VALUE input
.LDPIPEEN     (1'b0                  ),// 1-bit input: Enable PIPELINE register to load data input
.REGRST       (1'b0                   ) // 1-bit input: Active-high reset tap-delay input
);
IDDR #(
.DDR_CLK_EDGE ("SAME_EDGE_PIPELINED"    ),
.INIT_Q1      (1'b0                     ),
.INIT_Q2      (1'b0                     ),
.SRTYPE       ("ASYNC"                  ))
i_rx_data_iddr  ( 
.CE           (1'b1                     ),
.R            (~rx_resetn               ),
.S            (1'b0                     ),
.C            (data_clk                 ),
.D            (rx_data_idelay[l_inst]   ),
.Q1           (rx_data_p_s[l_inst]      ),
.Q2           (rx_data_n_s[l_inst]      ));
end endgenerate
// receive frame interface, ibuf  -> iddr
IBUFDS i_rx_frame_ibuf (.I(rx_frame_in_p),.IB(rx_frame_in_n),.O(rx_frame_ibuf_s));
(* IODELAY_GROUP = "RFMC_RX_DELAY" *) IDELAYE2 #(
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
.CINVCTRL     (1'b0            ),// 1-bit input: Dynamic clock inversion input
.CNTVALUEIN   (idly_d           ),// 5-bit input: Counter value input
.DATAIN       (1'b0            ),// 1-bit input: Internal delay data input
.IDATAIN      (rx_frame_ibuf_s  ),// 1-bit input: Data input from the I/O
.INC          (1'b0             ),// 1-bit input: Increment / Decrement tap delay input
.LD           (idly_en[6]       ),// 1-bit input: Load IDELAY_VALUE input
.LDPIPEEN     (1'b0            ),// 1-bit input: Enable PIPELINE register to load data input
.REGRST       (1'b0             ) // 1-bit input: Active-high reset tap-delay input
);
IDDR #(
.DDR_CLK_EDGE   ("SAME_EDGE_PIPELINED"  ),
.INIT_Q1        (1'b0                   ),
.INIT_Q2        (1'b0                   ),
.SRTYPE         ("ASYNC"                ))
i_rx_frame_iddr ( 
.CE             (1'b1                   ),
.R              (~rx_resetn             ),
.S              (1'b0                   ),
.C              (data_clk               ),
.D              (rx_frame_idelay        ),
.Q1             (rx_frame_p_s           ),
.Q2             (rx_frame_n_s           ));

endmodule
