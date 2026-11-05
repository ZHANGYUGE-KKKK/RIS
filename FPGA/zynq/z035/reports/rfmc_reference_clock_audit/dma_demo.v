module dma_demo(
// for critical warning
inout [53:0]  MIO,
inout         DDR_VRN,
inout         DDR_VRP,
inout [14:0]  DDR_addr,
inout [ 2:0]  DDR_ba,
inout         DDR_cas_n,
inout         DDR_ck_n,
inout         DDR_ck_p,
inout         DDR_cke,
inout         DDR_cs_n,
inout [ 3:0]  DDR_dm,
inout [31:0]  DDR_dq,
inout [ 3:0]  DDR_dqs_n,
inout [ 3:0]  DDR_dqs_p,
inout         DDR_odt,
inout         DDR_ras_n,
inout         DDR_reset_n,
inout         DDR_we_n,
inout         PS_CLK,
inout         PS_PORB,
inout         PS_SRSTB,
//global
output [3:0]  led,
//inout  [7:0]  user_io,
//ad9361
output        rf1_spi_csn,
output        rf1_spi_clk,
output        rf1_spi_mosi,
input         rf1_spi_miso,
inout         rf1_sync_in,
inout         rf1_en_agc,
inout         rf1_enable,
inout         rf1_resetb,
inout         rf1_txnrx,
input         rf1_clk_out,
output [3:0]  rf1_ctrl_in,
input [7:0]   rf1_ctrl_out,
input         rf1_rx_clk_in_p,
input         rf1_rx_clk_in_n,
input  [5:0]  rf1_rx_data_in_n,
input  [5:0]  rf1_rx_data_in_p,
input         rf1_rx_frame_in_n,
input         rf1_rx_frame_in_p,
output        rf1_tx_clk_out_n,
output        rf1_tx_clk_out_p,
output [5:0]  rf1_tx_data_out_n,
output [5:0]  rf1_tx_data_out_p,
output        rf1_tx_frame_out_n,
output        rf1_tx_frame_out_p,
//fmc9361
output        rf1_cdcm_spi_clk,
output        rf1_cdcm_spi_cs,
output        rf1_cdcm_spi_mosi,
input         rf1_cdcm_spi_miso,
output        rf1_cdcm_sync,
inout         rf1_ref_select,
inout         rf1_ref_select2,
inout         rf1_fdd_tdd_sel,
inout         rf1_trx_sw,
inout         rf1_gpio_scl,
inout         rf1_gpio_sda,
input         rf1_pps_1s,
output        rf1_rxd_gps,
input         rf1_txd_gps

);
/////////////////
wire [ 5:0]   axi_rd_addr;
wire [ 5:0]   axi_wr_addr;
wire [31:0]   axi_rd_data;
wire [31:0]   axi_wr_data;

wire [48:0]   gpio_tri_i;
wire [48:0]   gpio_tri_o;
wire [48:0]   gpio_tri_t;
system_top system_top_i(
.FIXED_IO_mio     (MIO          ),
.FIXED_IO_ps_clk  (PS_CLK       ),
.FIXED_IO_ps_porb (PS_PORB      ),
.FIXED_IO_ps_srstb(PS_SRSTB     ),
.FIXED_IO_ddr_vrn (DDR_VRN      ),
.FIXED_IO_ddr_vrp (DDR_VRP      ),
.DDR_addr         (DDR_addr     ),
.DDR_ba           (DDR_ba       ),
.DDR_cas_n        (DDR_cas_n    ),
.DDR_ck_n         (DDR_ck_n     ),
.DDR_ck_p         (DDR_ck_p     ),
.DDR_cke          (DDR_cke      ),
.DDR_cs_n         (DDR_cs_n     ),
.DDR_dm           (DDR_dm       ),
.DDR_dq           (DDR_dq       ),
.DDR_dqs_n        (DDR_dqs_n    ),
.DDR_dqs_p        (DDR_dqs_p    ),
.DDR_odt          (DDR_odt      ),
.DDR_ras_n        (DDR_ras_n    ),
.DDR_reset_n      (DDR_reset_n  ),
.DDR_we_n         (DDR_we_n     ),
.GPIO_tri_i       (gpio_tri_i   ),
.GPIO_tri_o       (gpio_tri_o   ),
.GPIO_tri_t       (gpio_tri_t   ),
.SPI0_MISO_I      (spi0_miso    ),
.SPI0_MOSI_I      (spi0_mosi    ),
.SPI0_MOSI_O      (spi0_mosi    ),
.SPI0_SCLK_I      (spi0_sclk    ),
.SPI0_SCLK_O      (spi0_sclk    ),
.SPI0_SS_O        (spi0_ss0     ),
.SPI0_SS1_O       (spi0_ss1     ),
.SPI0_SS2_O       (spi0_ss2     ),
.SPI0_SS_I        (1'b1         ),
.SPI1_MISO_I      (spi1_miso    ),
.SPI1_MOSI_I      (spi1_mosi    ),
.SPI1_MOSI_O      (spi1_mosi    ),
.SPI1_SCLK_I      (spi1_sclk    ),
.SPI1_SCLK_O      (spi1_sclk    ),
.SPI1_SS_O        (spi1_ss0     ),
.SPI1_SS1_O       (spi1_ss1     ),
.SPI1_SS2_O       (spi1_ss2     ),
.SPI1_SS_I        (1'b1         ),
.UART_1_rxd       (rf1_txd_gps  ),
.UART_1_txd       (rf1_rxd_gps  ),
.IIC_1_scl_i      (iic_1_scl_i  ),
.IIC_1_scl_o      (iic_1_scl_o  ),
.IIC_1_scl_t      (iic_1_scl_t  ),
.IIC_1_sda_i      (iic_1_sda_i  ),
.IIC_1_sda_o      (iic_1_sda_o  ),
.IIC_1_sda_t      (iic_1_sda_t  ),
.fclk_200m        (fclk_200m    ),
.clk200           (clk200       ),
.fclk_100m        (fclk_100m    ),
.fclk_reset0_n    (fclk_reset0_n),
//register
.rd_ack           (axi_rd_ack   ),
.rd_addr          (axi_rd_addr  ),
.rd_data          (axi_rd_data  ),
.rd_stb           (axi_rd_stb   ),
.wr_ack           (axi_wr_ack   ),
.wr_addr          (axi_wr_addr  ),
.wr_data          (axi_wr_data  ),
.wr_stb           (axi_wr_stb   )
);
//gpio
ad_iobuf #(.DATA_WIDTH(10)) i_iobuf1 (
.dio_t (gpio_tri_t[9:0]),
.dio_i (gpio_tri_o[9:0]),
.dio_o (gpio_tri_i[9:0]),
.dio_p ({
rf1_cdcm_sync   ,//9
rf1_txnrx       ,//8
rf1_sync_in     ,//7
rf1_en_agc      ,//6
rf1_ref_select2 ,//5
rf1_ref_select  ,//4
rf1_fdd_tdd_sel ,//3
rf1_trx_sw      ,//2
rf1_enable      ,//1
rf1_resetb       //0
}));
//wire [7:0] user_io_t;
//wire [7:0] user_io_o;
//wire [7:0] user_io_i;
//ad_iobuf #(.DATA_WIDTH(8)) user_iobuf (
//.dio_t (user_io_t ),
//.dio_i (user_io_o ),
//.dio_o (user_io_i ),
//.dio_p (user_io   )
//);
ad_iobuf #(.DATA_WIDTH(2)) i2c_iobuf (
.dio_t ({iic_1_scl_t ,iic_1_sda_t }),
.dio_i ({iic_1_scl_o ,iic_1_sda_o }),
.dio_o ({iic_1_scl_i ,iic_1_sda_i }),
.dio_p ({rf1_gpio_scl,rf1_gpio_sda})
);
//spi_warper
assign rf1_spi_csn        =spi0_ss0;
assign rf1_spi_clk        =spi0_sclk;
assign rf1_spi_mosi       =spi0_mosi;
assign spi0_miso          =rf1_spi_miso;

assign spi1_miso         =rf1_cdcm_spi_miso;
assign rf1_cdcm_spi_clk  =spi1_sclk;
assign rf1_cdcm_spi_mosi =spi1_mosi;
assign rf1_cdcm_spi_cs   =spi1_ss0;
//register define
wire [31:0] sdr_info={16'h1000,16'd420};
wire        mtime_start;
wire        adc_status;
wire [11:0] phase;
wire [6:0]  idly_en;
wire [4:0]  idly_d;
wire [ 1:0] pps_select;
wire [31:0] clock_1pps;
wire [3:0]  rf_mode;
axi_lite_drv axi_lite_drv(
.axi_gp_clk       (fclk_100m    ),//global
.axi_rst_n        (fclk_reset0_n),
.axi_wr_addr      (axi_wr_addr  ),//axi lite wr
.axi_wr_data      (axi_wr_data  ),
.axi_wr_stb       (axi_wr_stb   ),
.axi_wr_ack       (axi_wr_ack   ),
.axi_rd_addr      (axi_rd_addr  ),//axi lite rd
.axi_rd_data      (axi_rd_data  ),
.axi_rd_ack       (axi_rd_ack   ),
.axi_rd_stb       (axi_rd_stb   ),
.mtime_start      (mtime_start  ),//register out
.rf_mode          (rf_mode      ),
.phase            (phase        ),
.idly_en          (idly_en      ),
.idly_d           (idly_d       ),
.pps_select       (pps_select   ),
.clock_1pps       (clock_1pps   ),
.rf1_ctrl_in      (rf1_ctrl_in  ),
.user_io_t        (user_io_t    ),
.user_io_o        (user_io_o    ),
.sdr_info         (sdr_info     ),//register in
.adc_status       (adc_status   ),
.rf1_ctrl_out     (rf1_ctrl_out ),
.user_io_i        (user_io_i    )
);
//pll
IBUFDS IBUFDS1(.I(rf1_rx_clk_in_p),.IB(rf1_rx_clk_in_n),.O(data_clk_s1));
BUFG BUFG1(.I(data_clk_s1),.O(data_clk1));
//pps led control
pps_internal pps_internal(
.mclk       (data_clk1    ),
.rst        (fclk_reset0_n),
.sample_1pps(clock_1pps   ),
.pps_1s     (pps_1s_int   )
);
assign trig_out=(pps_select==2'd0)?pps_1s_int:rf1_pps_1s;
reg pps_rr1,pps_rr2;
always @(posedge data_clk1)
  begin
    pps_rr2<=pps_rr1;
    case(pps_select)
      2'd0:pps_rr1<=pps_1s_int;
      default:pps_rr1<=rf1_pps_1s;
    endcase
  end
pps_led_ctrl pps_led_ctrl(
.mclk   (data_clk1    ),
.rst    (fclk_reset0_n),
.pps_r1 (pps_rr1      ),
.pps_r2 (pps_rr2      ),
.led_1s (led_1s       )
);
//DDS
reg phase_en1;
reg [1:0] cnt1;
reg [11:0] phase1;
always @ (posedge data_clk1 or negedge mtime_start)
if(!mtime_start)
  begin
    cnt1<=2'd0;
    phase1<=12'd0;phase_en1<=1'b0;
  end
else
  begin
    cnt1<=cnt1+1'b1;
    if(cnt1==2'd0)
      begin phase_en1<=1'b1;phase1<=phase1+phase;end
    else phase_en1<=1'b0;
  end
wire [31:0] m_tdata1;
dds1 dds1 (
.aclk                 (data_clk1  ),// input wire aclk
.s_axis_phase_tvalid  (phase_en1  ),// input wire s_axis_phase_tvalid
.s_axis_phase_tdata   (phase1     ),// input wire [15 : 0] s_axis_phase_tdata
.m_axis_data_tvalid   (dds_en1    ),// output wire m_axis_data_tvalid
.m_axis_data_tdata    (m_tdata1   ) // output wire [31 : 0] m_axis_data_tdata
);
reg dac_valid;
reg [11:0] dac_data_i1;
reg [11:0] dac_data_q1;
reg [11:0] dac_data_i2;
reg [11:0] dac_data_q2;
wire adc_valid;
wire [11:0] adc_data_i1,adc_data_q1;
wire [11:0] adc_data_i2,adc_data_q2;
always @ (posedge data_clk1 or negedge mtime_start)
if(!mtime_start)
  begin
    dac_valid  <=phase_en1;
    dac_data_i1<=12'd0;
    dac_data_q1<=12'd0;
    dac_data_i2<=12'd0;
    dac_data_q2<=12'd0;
  end
else
  begin
    case(rf_mode)
      4'd0 :begin
              dac_valid  <=phase_en1;
              dac_data_i1<=12'd0;
              dac_data_q1<=12'd0;
              dac_data_i2<=12'd0;
              dac_data_q2<=12'd0;
            end
      4'd1 :begin
              dac_valid  <=phase_en1;
              dac_data_i1<=m_tdata1[11:0];
              dac_data_q1<=m_tdata1[27:16];
              dac_data_i2<=m_tdata1[11:0];
              dac_data_q2<=m_tdata1[27:16];
            end
      4'd2 :begin
              dac_valid  <=adc_valid;
              dac_data_i1<=adc_data_i1;
              dac_data_q1<=adc_data_q1;
              dac_data_i2<=adc_data_i2;
              dac_data_q2<=adc_data_q2;
            end
      4'd3 :begin
              dac_valid  <=adc_valid;
              dac_data_i1<=adc_data_i2;
              dac_data_q1<=adc_data_q2;
              dac_data_i2<=adc_data_i1;
              dac_data_q2<=adc_data_q1;
            end
      4'd4 :begin
              dac_valid  <=phase_en1;
              dac_data_i1<=m_tdata1[11:0];
              dac_data_q1<=m_tdata1[27:16];
              dac_data_i2<=12'd0;
              dac_data_q2<=12'd0;
            end
      4'd5 :begin
              dac_valid  <=phase_en1;
              dac_data_i1<=12'd0;
              dac_data_q1<=12'd0;
              dac_data_i2<=m_tdata1[11:0];
              dac_data_q2<=m_tdata1[27:16];
            end
      default:
            begin
              dac_valid  <=phase_en1;
              dac_data_i1<=12'd0;
              dac_data_q1<=12'd0;
              dac_data_i2<=12'd0;
              dac_data_q2<=12'd0;
            end
    endcase
  end
//RF1
wire dac_r1_mode=1'b0;
wire adc_r1_mode=1'b0;
wire [63:0] chip_data;
axi_ad9361_dev_if_idelay axi_ad9361_rf1 (
.rx_frame_in_p  (rf1_rx_frame_in_p  ),
.rx_frame_in_n  (rf1_rx_frame_in_n  ),
.rx_data_in_p   (rf1_rx_data_in_p   ),
.rx_data_in_n   (rf1_rx_data_in_n   ),
.tx_clk_out_p   (rf1_tx_clk_out_p   ),
.tx_clk_out_n   (rf1_tx_clk_out_n   ),
.tx_frame_out_p (rf1_tx_frame_out_p ),
.tx_frame_out_n (rf1_tx_frame_out_n ),
.tx_data_out_p  (rf1_tx_data_out_p  ),
.tx_data_out_n  (rf1_tx_data_out_n  ),
.data_clk       (data_clk1          ),
.clk200         (clk200             ),
.rstn           (fclk_reset0_n      ),
.adc_valid      (adc_valid          ),
.adc_data_i1    (adc_data_i1        ),
.adc_data_q1    (adc_data_q1        ),
.adc_data_i2    (adc_data_i2        ),
.adc_data_q2    (adc_data_q2        ),
.adc_status     (adc_status         ),
.adc_r1_mode    (adc_r1_mode        ),
.dac_valid      (dac_valid          ),
.dac_data_i1    (dac_data_i1        ),
.dac_data_q1    (dac_data_q1        ),
.dac_data_i2    (dac_data_i2        ),
.dac_data_q2    (dac_data_q2        ),
.dac_r1_mode    (dac_r1_mode        ),
.chip_data      (chip_data          ),
.idly_en        (idly_en            ),
.idly_d         (idly_d             )
);
//led
assign led[0]=gpio_tri_o[35];
assign led[1]=gpio_tri_o[36];
assign led[2]=adc_status;
assign led[3]=led_1s;
//chipscope
ila_0 ila_0 (
.clk(data_clk1),
.probe0({
adc_valid   ,//1
adc_data_i1 ,//12
adc_data_q1 ,//12
adc_data_i2 ,//12
adc_data_q2 ,//12
adc_status  ,//1
dac_valid   ,//1
dac_data_i1 ,//12
dac_data_q1 ,//12
dac_data_i2 ,//12
dac_data_q2  //12
}));
endmodule
