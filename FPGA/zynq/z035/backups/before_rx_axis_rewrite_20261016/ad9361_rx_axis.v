`timescale 1ns / 1ps
// ADI receive-only integration, source commit in adi_hdl/SOURCE_MANIFEST.json.
// Official LVDS IF + ADC/PN/register logic; raw 12-bit IQ is sign extended
// into AXIS {Q2,I2,Q1,I1}. No DC filtering or IQ correction is synthesized.
// S_AXI shares PS 100 MHz m_axis_aclk. ref_clk200 is IDELAY/ILA only.
// frame_locked reports ADI interface status, NOT a PN/data integrity verdict.
module ad9361_rx_axis #(
    parameter integer FIFO_DEPTH = 4096,
    parameter integer PACKET_SAMPLES = 4096,
    parameter IO_DELAY_GROUP = "AD9361_RX_DELAY"
) (
    input wire rx_clk_p,
    input wire rx_clk_n,
    input wire rx_frame_p,
    input wire rx_frame_n,
    input wire [5:0] rx_data_p,
    input wire [5:0] rx_data_n,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ref_clk200 CLK" *)
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 200000000" *)
    input wire ref_clk200,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 m_axis_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 100000000, ASSOCIATED_BUSIF M_AXIS:S_AXI, ASSOCIATED_RESET aresetn" *)
    input wire m_axis_aclk,
    input wire capture_arm,
    output wire rx_ready,
    output wire frame_locked,
    output wire capture_active,
    output wire overflow,
    output wire frame_error,
    output wire delay_error,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output wire [63:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *)
    output wire [7:0] m_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *)
    output wire m_axis_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    output wire m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input wire m_axis_tready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input wire s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 16" *)
    input wire [15:0] s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input wire [2:0] s_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input wire s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input wire [3:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input wire s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input wire s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input wire [15:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input wire [2:0] s_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input wire s_axi_rready
);
    localparam integer PACKET_COUNT_WIDTH =
        (PACKET_SAMPLES <= 1) ? 1 : $clog2(PACKET_SAMPLES);
    reg overflow_rx = 0;
    wire rx_clk, official_rst, mmcm_rst, delay_rst;
    wire delay_ready_ref, official_valid, official_status;
    wire [47:0] official_data;
    wire [1:0] raw_frame, raw_frame_previous;
    wire [5:0] raw_data_rise, raw_data_fall;
    wire adc_r1_mode;
    // Kept as an official register-map output. ADI's native LVDS path does
    // not consume this legacy edge-select bit; phase tuning uses IDELAY/SPI.
    wire adc_ddr_edgesel;
    wire [12:0] adc_dld;
    wire [64:0] adc_dwdata, adc_drdata;
    assign adc_drdata[64:35] = 0;
    wire up_wreq, up_wack, up_rreq, up_rack;
    wire [13:0] up_waddr, up_raddr;
    wire [31:0] up_wdata, up_rdata;
    wire rx_up_rack;
    wire [31:0] rx_up_rdata;
    wire [23:0] adc_samples_axis, rx_edges_axis;
    reg diag_up_rack = 0;
    reg [31:0] diag_up_rdata = 0;
    assign up_rack = rx_up_rack | diag_up_rack;
    assign up_rdata = rx_up_rdata | diag_up_rdata;
    // Adapter diagnostics outside the official register map. These counters
    // prevent a stopped/no-valid stream from appearing to pass a PN check.
    always @(posedge m_axis_aclk or negedge aresetn) begin
        if (!aresetn) begin diag_up_rack <= 0; diag_up_rdata <= 0; end
        else begin
            diag_up_rack <= up_rreq && (up_raddr[13:2] == 12'h100);
            diag_up_rdata <= 0;
            if (up_rreq && (up_raddr[13:2] == 12'h100)) begin
                case (up_raddr[1:0])
                    0: diag_up_rdata <= {8'd0,adc_samples_axis};
                    1: diag_up_rdata <= {8'd0,rx_edges_axis};
                    2: diag_up_rdata <= 32'h41445258;
                    default: diag_up_rdata <= 0;
                endcase
            end
        end
    end
    wire [3:0] channel_enable, channel_valid;
    wire [15:0] channel_i1, channel_q1, channel_i2, channel_q2;
    wire [31:0] unused_gpio;
    // Stage 1: ADI's native-clock receive path, isolated from TX/TDD/DRP.
    ad9361_rx_lvds_if #(
        .FPGA_TECHNOLOGY(1), .IO_DELAY_GROUP(IO_DELAY_GROUP),
        .DELAY_REFCLK_FREQUENCY(200)
    ) i_dev_if (
        .rx_clk_in_p(rx_clk_p), .rx_clk_in_n(rx_clk_n),
        .rx_frame_in_p(rx_frame_p), .rx_frame_in_n(rx_frame_n),
        .rx_data_in_p(rx_data_p), .rx_data_in_n(rx_data_n),
        .l_clk(rx_clk),
        .adc_valid(official_valid), .adc_data(official_data),
        .adc_status(official_status), .adc_r1_mode(adc_r1_mode),
        .up_clk(m_axis_aclk),
        .up_adc_dld(adc_dld[6:0]), .up_adc_dwdata(adc_dwdata[34:0]),
        .up_adc_drdata(adc_drdata[34:0]),
        .delay_clk(ref_clk200), .delay_rst(delay_rst), .delay_locked(delay_ready_ref),
        .debug_frame(raw_frame), .debug_frame_previous(raw_frame_previous),
        .debug_data_rise(raw_data_rise), .debug_data_fall(raw_data_fall));
    axi_ad9361_rx #(
        .ID(0), .FPGA_TECHNOLOGY(1), .MODE_1R1T(0), .CMOS_OR_LVDS_N(0),
        .PPS_RECEIVER_ENABLE(0), .INIT_DELAY(0), .USERPORTS_DISABLE(1),
        .DATAFORMAT_DISABLE(1), .DCFILTER_DISABLE(1), .IQCORRECTION_DISABLE(1)
    ) i_rx (
        .mmcm_rst(mmcm_rst), .adc_rst(official_rst), .adc_clk(rx_clk),
        .adc_valid(official_valid), .adc_data(official_data),
        .adc_status(official_status), .adc_r1_mode(adc_r1_mode),
        .adc_ddr_edgesel(adc_ddr_edgesel), .dac_data(48'd0),
        .up_dld(adc_dld), .up_dwdata(adc_dwdata), .up_drdata(adc_drdata),
        .delay_clk(ref_clk200), .delay_rst(delay_rst), .delay_locked(delay_ready_ref),
        .adc_enable_i0(channel_enable[0]), .adc_valid_i0(channel_valid[0]), .adc_data_i0(channel_i1),
        .adc_enable_q0(channel_enable[1]), .adc_valid_q0(channel_valid[1]), .adc_data_q0(channel_q1),
        .adc_enable_i1(channel_enable[2]), .adc_valid_i1(channel_valid[2]), .adc_data_i1(channel_i2),
        .adc_enable_q1(channel_enable[3]), .adc_valid_q1(channel_valid[3]), .adc_data_q1(channel_q2),
        .adc_dovf(overflow_rx), .up_adc_gpio_in(32'd0), .up_adc_gpio_out(unused_gpio),
        .up_pps_rcounter(32'd0), .up_pps_status(1'b1), .up_pps_irq_mask(),
        .up_rstn(aresetn), .up_clk(m_axis_aclk),
        .up_wreq(up_wreq), .up_waddr(up_waddr), .up_wdata(up_wdata), .up_wack(up_wack),
        .up_rreq(up_rreq), .up_raddr(up_raddr), .up_rdata(rx_up_rdata), .up_rack(rx_up_rack),
        .up_drp_sel(), .up_drp_wr(), .up_drp_addr(), .up_drp_wdata(),
        .up_drp_rdata(32'd0), .up_drp_ready(1'b0), .up_drp_locked(1'b1));
    up_axi i_up_axi (
        .up_rstn(aresetn), .up_clk(m_axis_aclk),
        .up_axi_awvalid(s_axi_awvalid),
        .up_axi_awaddr(s_axi_awaddr),
        .up_axi_awready(s_axi_awready),
        .up_axi_wvalid(s_axi_wvalid),
        .up_axi_wdata(s_axi_wdata),
        .up_axi_wstrb(s_axi_wstrb),
        .up_axi_wready(s_axi_wready),
        .up_axi_bvalid(s_axi_bvalid),
        .up_axi_bresp(s_axi_bresp),
        .up_axi_bready(s_axi_bready),
        .up_axi_arvalid(s_axi_arvalid),
        .up_axi_araddr(s_axi_araddr),
        .up_axi_arready(s_axi_arready),
        .up_axi_rvalid(s_axi_rvalid),
        .up_axi_rdata(s_axi_rdata),
        .up_axi_rresp(s_axi_rresp),
        .up_axi_rready(s_axi_rready),
        .up_wreq(up_wreq), .up_waddr(up_waddr), .up_wdata(up_wdata), .up_wack(up_wack),
        .up_rreq(up_rreq), .up_raddr(up_raddr), .up_rdata(up_rdata), .up_rack(up_rack));

    // Reset assertion is asynchronous; release is local to each clock.
    (* ASYNC_REG = "TRUE" *) reg [2:0] rx_reset_pipe = 3'b000;
    (* ASYNC_REG = "TRUE" *) reg [2:0] axis_reset_pipe = 3'b000;
    (* ASYNC_REG = "TRUE" *) reg [2:0] ref_reset_pipe = 3'b000;
    always @(posedge rx_clk or negedge aresetn)
        if (!aresetn) rx_reset_pipe <= 0;
        else rx_reset_pipe <= {rx_reset_pipe[1:0], 1'b1};
    always @(posedge m_axis_aclk or negedge aresetn)
        if (!aresetn) axis_reset_pipe <= 0;
        else axis_reset_pipe <= {axis_reset_pipe[1:0], 1'b1};
    always @(posedge ref_clk200 or negedge aresetn)
        if (!aresetn) ref_reset_pipe <= 0;
        else ref_reset_pipe <= {ref_reset_pipe[1:0], 1'b1};
    (* MARK_DEBUG = "TRUE" *) wire rx_resetn = rx_reset_pipe[2] && !official_rst;
    wire axis_resetn = axis_reset_pipe[2];
    wire ref_resetn = ref_reset_pipe[2];

    wire delay_configured_ref = delay_ready_ref;
    (* ASYNC_REG = "TRUE", MARK_DEBUG = "TRUE" *) reg [2:0] ready_pipe = 0;
    (* ASYNC_REG = "TRUE" *) reg [2:0] arm_pipe = 0;
    reg arm_axis = 0;
    always @(posedge m_axis_aclk or negedge axis_resetn)
        if (!axis_resetn) arm_axis <= 0;
        else arm_axis <= capture_arm;
    always @(posedge rx_clk or negedge rx_resetn) begin
        if (!rx_resetn) begin ready_pipe <= 0; arm_pipe <= 0; end
        else begin
            ready_pipe <= {ready_pipe[1:0], delay_configured_ref};
            arm_pipe <= {arm_pipe[1:0], arm_axis};
        end
    end
    wire [63:0] sample_data = {
        {4{channel_q2[11]}},channel_q2[11:0], {4{channel_i2[11]}},channel_i2[11:0],
        {4{channel_q1[11]}},channel_q1[11:0], {4{channel_i1[11]}},channel_i1[11:0]};
    wire sample_valid = (&channel_valid) && (&channel_enable) && !official_rst;
    wire locked_rx = official_status && !official_rst;
    reg frame_error_rx = 0, delay_error_rx = 0;
    reg fifo_booted_rx = 0, armed_rx = 0;
    wire fifo_source_ready;
    wire failed_rx = overflow_rx || frame_error_rx || delay_error_rx;
    // Adapter fault policy applies after ARM; the ADI deframer stays intact.
    always @(posedge rx_clk or negedge rx_resetn) begin
        if (!rx_resetn) begin frame_error_rx <= 0; delay_error_rx <= 0; end
        else if (armed_rx) begin
            if (!ready_pipe[2]) delay_error_rx <= 1'b1;
            if (!official_status) frame_error_rx <= 1'b1;
        end
    end

    // An elastic slot keeps FIFO input stable during backpressure. If another
    // complete sample arrives before it drains, stop and latch overflow.
    (* MARK_DEBUG = "TRUE" *) reg [63:0] pending_data = 0;
    (* MARK_DEBUG = "TRUE" *) reg pending_valid = 0, pending_last = 0;
    reg [PACKET_COUNT_WIDTH-1:0] packet_index = 0;
    // Registers feeding FIFO RAM write enables reset synchronously. The FIFO
    // itself and output-domain reset guard hide stale data during reset.
    always @(posedge rx_clk) begin
        if (!rx_resetn) begin
            fifo_booted_rx <= 0; armed_rx <= 0; overflow_rx <= 0;
            pending_data <= 0; pending_valid <= 0; pending_last <= 0;
            packet_index <= 0;
        end else begin
            if (ready_pipe[2] && fifo_source_ready) fifo_booted_rx <= 1'b1;
            if (fifo_booted_rx && arm_pipe[2] && !failed_rx) armed_rx <= 1'b1;
            if (pending_valid && fifo_source_ready) pending_valid <= 0;
            if (sample_valid && armed_rx && !failed_rx) begin
                if (!pending_valid || fifo_source_ready) begin
                    pending_data <= sample_data; pending_valid <= 1'b1;
                    pending_last <= (packet_index == PACKET_SAMPLES - 1);
                    if (packet_index == PACKET_SAMPLES - 1) packet_index <= 0;
                    else packet_index <= packet_index + 1'b1;
                end else overflow_rx <= 1'b1;
            end
        end
    end

    wire [63:0] fifo_data;
    wire [7:0] fifo_keep;
    wire fifo_valid, fifo_last;
    reg [6:0] status_rx = 0;
    wire [6:0] status_sync;
    reg axis_allow = 0;
    // Do not drive RAM read enables directly from asynchronously reset flags.
    always @(posedge m_axis_aclk)
        if (!axis_resetn) axis_allow <= 0;
        else axis_allow <= status_sync[0];
    // This macro transfers the complete beat and TLAST as one FIFO word.
    // Its Gray pointers/CDC constraints/reset logic are provided by Xilinx.
    xpm_fifo_axis #(
        .CLOCKING_MODE("independent_clock"), .FIFO_MEMORY_TYPE("block"),
        .PACKET_FIFO("false"), .FIFO_DEPTH(FIFO_DEPTH), .TDATA_WIDTH(64),
        .TID_WIDTH(1), .TDEST_WIDTH(1), .TUSER_WIDTH(1),
        .CDC_SYNC_STAGES(3), .USE_ADV_FEATURES("1000"),
        // Vivado 2020.2's optional FIFO SVA includes a one-cycle check of
        // asynchronously synchronized read pointers. Use the vendor default;
        // the testbench separately checks safe enables and data continuity.
        .SIM_ASSERT_CHK(0)
    ) i_cdc_fifo (
        .s_aclk(rx_clk), .m_aclk(m_axis_aclk), .s_aresetn(rx_resetn),
        .s_axis_tvalid(pending_valid), .s_axis_tready(fifo_source_ready),
        .s_axis_tdata(pending_data), .s_axis_tkeep(8'hff),
        .s_axis_tstrb(8'hff), .s_axis_tlast(pending_last),
        .s_axis_tid(1'b0), .s_axis_tdest(1'b0), .s_axis_tuser(1'b0),
        .m_axis_tdata(fifo_data), .m_axis_tkeep(fifo_keep),
        .m_axis_tstrb(), .m_axis_tlast(fifo_last),
        .m_axis_tvalid(fifo_valid),
        .m_axis_tready(m_axis_tready && axis_allow),
        .m_axis_tid(), .m_axis_tdest(), .m_axis_tuser(),
        .prog_full_axis(), .wr_data_count_axis(), .almost_full_axis(),
        .prog_empty_axis(), .rd_data_count_axis(), .almost_empty_axis(),
        .injectsbiterr_axis(1'b0), .injectdbiterr_axis(1'b0),
        .sbiterr_axis(), .dbiterr_axis());

    reg [23:0] rx_edge_counter = 0;
    reg [23:0] adc_sample_counter = 0;
    always @(posedge rx_clk or negedge rx_reset_pipe[2])
        if (!rx_reset_pipe[2]) adc_sample_counter <= 0;
        else if (official_valid && !official_rst) adc_sample_counter <= adc_sample_counter + 1'b1;
    xpm_cdc_gray #(.WIDTH(24),.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),
        .REG_OUTPUT(1),.SIM_ASSERT_CHK(0)) i_adc_sample_count_cdc (
        .src_clk(rx_clk),.src_in_bin(adc_sample_counter),
        .dest_clk(m_axis_aclk),.dest_out_bin(adc_samples_axis));
    xpm_cdc_gray #(.WIDTH(24),.DEST_SYNC_FF(3),.INIT_SYNC_FF(1),
        .REG_OUTPUT(1),.SIM_ASSERT_CHK(0)) i_rx_edge_count_axis_cdc (
        .src_clk(rx_clk),.src_in_bin(rx_edge_counter),
        .dest_clk(m_axis_aclk),.dest_out_bin(rx_edges_axis));

    always @(posedge rx_clk or negedge rx_reset_pipe[2])
        if (!rx_reset_pipe[2]) rx_edge_counter <= 0;
        else rx_edge_counter <= rx_edge_counter + 1'b1;
    // Keep recorder ownership independent of ADI core reset/tap tuning so
    // a core reset cannot release a frozen bank while REF is reading it.
    wire dbg_monitor_valid = rx_reset_pipe[2];
    // Pre-FIFO ILA uses ref_clk200. A private 64-word dual-clock recorder
    // preserves consecutive RX cycles. Freeze the whole bank before crossing
    // ownership; REF reads only while frozen, RX resumes only after REF ACK
    // returns low. This recorder never backpressures the functional IQ path.
    localparam integer PREFIFO_TRACE_WIDTH = 227;
    wire [PREFIFO_TRACE_WIDTH-1:0] prefifo_capture_word = {
        raw_frame,
        raw_frame_previous,
        raw_data_rise,
        raw_data_fall,
        official_data,
        official_valid,
        official_status,
        official_rst,
        sample_data,
        sample_valid,
        pending_data,
        pending_valid,
        pending_last,
        fifo_source_ready,
        armed_rx,
        overflow_rx,
        frame_error_rx,
        delay_error_rx,
        rx_edge_counter};
    reg [5:0] prefifo_write_index = 0;
    reg prefifo_full_rx = 0;
    reg prefifo_ack_ref = 0;
    reg prefifo_request_rx = 0;
    wire prefifo_full_ref, prefifo_ack_rx;
    // RAM addresses/enables use synchronous resets. Resetting the RX clock
    // domain also masks an old ownership flag while RX is stopped.
    reg prefifo_rx_allow = 0, prefifo_ref_allow = 0;
    always @(posedge rx_clk) prefifo_rx_allow <= dbg_monitor_valid;
    always @(posedge ref_clk200) prefifo_ref_allow <= ref_resetn;
    // Register the ownership request before its synchronizer. Its reset may
    // assert with RX stopped, while all RAM control registers remain purely
    // synchronous. REF therefore never samples combinational reset masking.
    always @(posedge rx_clk or negedge rx_reset_pipe[2])
        if (!rx_reset_pipe[2]) prefifo_request_rx <= 0;
        else prefifo_request_rx <= prefifo_full_rx;
    xpm_cdc_single #(.DEST_SYNC_FF(3), .INIT_SYNC_FF(1),
        .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0)) i_prefifo_full_cdc (
        .src_clk(rx_clk), .src_in(prefifo_request_rx),
        .dest_clk(ref_clk200), .dest_out(prefifo_full_ref));
    xpm_cdc_single #(.DEST_SYNC_FF(3), .INIT_SYNC_FF(1),
        .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0)) i_prefifo_ack_cdc (
        .src_clk(ref_clk200), .src_in(prefifo_ack_ref),
        .dest_clk(rx_clk), .dest_out(prefifo_ack_rx));
    wire prefifo_write = prefifo_rx_allow &&
        !prefifo_full_rx && !prefifo_ack_rx;
    always @(posedge rx_clk) begin
        if (!rx_reset_pipe[2]) begin
            prefifo_write_index <= 0; prefifo_full_rx <= 0;
        end else if (prefifo_full_rx) begin
            if (prefifo_ack_rx) begin
                prefifo_full_rx <= 0; prefifo_write_index <= 0;
            end
        end else if (!dbg_monitor_valid) begin
            // Discard a partial record while the RX monitor is in reset.
            prefifo_write_index <= 0;
        end else if (prefifo_write) begin
            if (&prefifo_write_index) prefifo_full_rx <= 1'b1;
            else prefifo_write_index <= prefifo_write_index + 1'b1;
        end
    end
    reg [1:0] prefifo_read_state = 0;
    reg [5:0] prefifo_read_index = 0;
    wire prefifo_read = prefifo_ref_allow && (prefifo_read_state == 1);
    wire [PREFIFO_TRACE_WIDTH-1:0] prefifo_read_word;
    (* MARK_DEBUG = "TRUE" *) reg prefifo_valid_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [5:0] prefifo_index_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [15:0] prefifo_batch_ref = 0;
    always @(posedge ref_clk200) begin
        if (!ref_resetn) begin
            prefifo_read_state <= 0; prefifo_read_index <= 0;
            prefifo_ack_ref <= 0; prefifo_valid_ref <= 0;
            prefifo_index_ref <= 0; prefifo_batch_ref <= 0;
        end else begin
            // Matches the RAM's one-cycle registered B-port read latency.
            prefifo_valid_ref <= prefifo_read;
            if (prefifo_read) prefifo_index_ref <= prefifo_read_index;
            case (prefifo_read_state)
                0: if (prefifo_full_ref) begin
                    prefifo_read_index <= 0; prefifo_read_state <= 1;
                    prefifo_batch_ref <= prefifo_batch_ref + 1'b1;
                end
                1: if (&prefifo_read_index) prefifo_read_state <= 2;
                   else prefifo_read_index <= prefifo_read_index + 1'b1;
                2: begin
                    prefifo_ack_ref <= 1'b1; prefifo_read_state <= 3;
                end
                3: if (!prefifo_full_ref) begin
                    prefifo_ack_ref <= 0; prefifo_read_state <= 0;
                end
            endcase
        end
    end
    xpm_memory_sdpram #(
        .MEMORY_SIZE(64*PREFIFO_TRACE_WIDTH), .MEMORY_PRIMITIVE("block"),
        .CLOCKING_MODE("independent_clock"), .USE_MEM_INIT(0),
        .WRITE_DATA_WIDTH_A(PREFIFO_TRACE_WIDTH),
        .BYTE_WRITE_WIDTH_A(PREFIFO_TRACE_WIDTH), .ADDR_WIDTH_A(6),
        .READ_DATA_WIDTH_B(PREFIFO_TRACE_WIDTH), .ADDR_WIDTH_B(6),
        .READ_LATENCY_B(1), .READ_RESET_VALUE_B("0"),
        .RST_MODE_B("SYNC"), .WRITE_MODE_B("read_first"),
        .SIM_ASSERT_CHK(1)
    ) i_prefifo_trace_ram (
        .clka(rx_clk), .ena(prefifo_write), .wea(1'b1),
        .addra(prefifo_write_index), .dina(prefifo_capture_word),
        .clkb(ref_clk200), .rstb(1'b0), .enb(prefifo_read),
        .addrb(prefifo_read_index), .doutb(prefifo_read_word),
        .regceb(1'b1), .sleep(1'b0),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0),
        .sbiterrb(), .dbiterrb());
    (* MARK_DEBUG = "TRUE" *) wire [1:0] prefifo_raw_frame_ref = prefifo_read_word[226:225];
    (* MARK_DEBUG = "TRUE" *) wire [1:0] prefifo_raw_frame_previous_ref = prefifo_read_word[224:223];
    (* MARK_DEBUG = "TRUE" *) wire [5:0] prefifo_raw_data_rise_ref = prefifo_read_word[222:217];
    (* MARK_DEBUG = "TRUE" *) wire [5:0] prefifo_raw_data_fall_ref = prefifo_read_word[216:211];
    (* MARK_DEBUG = "TRUE" *) wire [47:0] prefifo_official_data_ref = prefifo_read_word[210:163];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_official_valid_ref = prefifo_read_word[162];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_official_status_ref = prefifo_read_word[161];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_official_rst_ref = prefifo_read_word[160];
    (* MARK_DEBUG = "TRUE" *) wire [63:0] prefifo_sample_data_ref = prefifo_read_word[159:96];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_sample_valid_ref = prefifo_read_word[95];
    (* MARK_DEBUG = "TRUE" *) wire [63:0] prefifo_pending_data_ref = prefifo_read_word[94:31];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_pending_valid_ref = prefifo_read_word[30];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_pending_last_ref = prefifo_read_word[29];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_fifo_source_ready_ref = prefifo_read_word[28];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_armed_rx_ref = prefifo_read_word[27];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_overflow_rx_ref = prefifo_read_word[26];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_frame_error_rx_ref = prefifo_read_word[25];
    (* MARK_DEBUG = "TRUE" *) wire prefifo_delay_error_rx_ref = prefifo_read_word[24];
    (* MARK_DEBUG = "TRUE" *) wire [23:0] prefifo_rx_edge_counter_ref = prefifo_read_word[23:0];
    (* MARK_DEBUG = "TRUE" *) wire [11:0] rx1_i_ref = prefifo_official_data_ref[11:0];
    (* MARK_DEBUG = "TRUE" *) wire [11:0] rx1_q_ref = prefifo_official_data_ref[23:12];
    (* MARK_DEBUG = "TRUE" *) wire [11:0] rx2_i_ref = prefifo_official_data_ref[35:24];
    (* MARK_DEBUG = "TRUE" *) wire [11:0] rx2_q_ref = prefifo_official_data_ref[47:36];

    wire [23:0] rx_counter_cdc;
    xpm_cdc_gray #(.WIDTH(24), .DEST_SYNC_FF(3), .INIT_SYNC_FF(1),
        .REG_OUTPUT(1), .SIM_ASSERT_CHK(0)) i_rx_counter_cdc (
        .src_clk(rx_clk), .src_in_bin(rx_edge_counter),
        .dest_clk(ref_clk200), .dest_out_bin(rx_counter_cdc));
    reg [17:0] ref_window = 0;
    reg [23:0] ref_previous_count = 0;
    (* MARK_DEBUG = "TRUE" *) reg [23:0] rx_edges_per_ms_ref = 0;
    always @(posedge ref_clk200 or negedge ref_resetn) begin
        if (!ref_resetn) begin ref_window <= 0; ref_previous_count <= 0; rx_edges_per_ms_ref <= 0; end
        else if (ref_window == 199999) begin
            ref_window <= 0; rx_edges_per_ms_ref <= rx_counter_cdc - ref_previous_count;
            ref_previous_count <= rx_counter_cdc;
        end else ref_window <= ref_window + 1'b1;
    end
    // Only independent single-bit status levels cross here; IQ uses the FIFO.
    // Booted is sticky so later frame/overflow faults never withdraw TVALID.
    always @(posedge rx_clk or negedge rx_resetn) begin
        if (!rx_resetn) status_rx <= 0;
        else status_rx <= {delay_error_rx, frame_error_rx, overflow_rx,
                           armed_rx && !failed_rx, locked_rx,
                           ready_pipe[2] && fifo_booted_rx, fifo_booted_rx};
    end
    genvar flag;
    generate for (flag = 0; flag < 7; flag = flag + 1) begin : g_status_cdc
        (* ASYNC_REG = "TRUE" *) reg [2:0] sync_pipe = 0;
        always @(posedge m_axis_aclk or negedge axis_resetn)
            if (!axis_resetn) sync_pipe <= 0;
            else sync_pipe <= {sync_pipe[1:0], status_rx[flag]};
        assign status_sync[flag] = sync_pipe[2];
    end endgenerate
    assign rx_ready = status_sync[1];
    assign frame_locked = status_sync[2];
    assign capture_active = status_sync[3];
    assign overflow = status_sync[4];
    assign frame_error = status_sync[5];
    assign delay_error = status_sync[6];
    assign m_axis_tdata = fifo_data;
    assign m_axis_tkeep = fifo_keep;
    assign m_axis_tlast = fifo_last;
    assign m_axis_tvalid = fifo_valid && axis_allow;

    // synthesis translate_off
    initial if (PACKET_SAMPLES < 1 || FIFO_DEPTH < 16 || (FIFO_DEPTH & (FIFO_DEPTH-1)))
        $fatal(1,"Invalid AD9361 AXIS FIFO/packet size");
    // synthesis translate_on
endmodule
