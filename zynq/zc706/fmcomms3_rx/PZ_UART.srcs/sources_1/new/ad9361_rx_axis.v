`timescale 1ns / 1ps
// Receiver for current FMCOMMS3 config915: 2R2T LVDS DDR, Fs=15.36 MSPS.
// SPI baseline: 010/011/012=C8/00/10, 006=0F, 03D/03E=00/00.
// UG-570 Fig.79 defines the serial order; UG-671 defines default data inversion.
// The FPGA does not configure SPI. Software owns RF setup and timing calibration.
// Raw signed 12-bit samples become AXIS {Q2,I2,Q1,I1}, four signed 16-bit lanes.
// ADI's unmodified register/PN blocks preserve the software register ABI.
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
    wire adc_reset_rx;
    wire adc_mmcm_reset;
    wire delay_reset_ref;
    wire adc_r1_mode;
    wire adc_ddr_edgesel;
    wire [3:0] channel_enable_rx;
    wire [6:0] up_adc_dld;
    wire [34:0] up_adc_dwdata;
    wire [23:0] sample_counter_axis;
    wire [23:0] edge_counter_axis;

    // The AD9361 emits eight six-bit chunks per dual-channel sample. Keep
    // their chronological order; do not assign I/Q from the IDDR edge name.
    // SPI timing calibration can move the frame boundary across either edge.
    wire rx_clk_pad, rx_clk;
    wire rx_reset, axis_reset;
    wire axis_resetn = !axis_reset;
    wire delay_ready_ref, delay_ready_rx;
    wire [34:0] up_adc_drdata;
    wire [6:0] pad_data, delayed_data, early_data, late_data;
    wire [5:0] early_chunk = early_data[5:0] ^ 6'h3f;
    wire [5:0] late_chunk = late_data[5:0] ^ 6'h3f;

    IBUFDS #(.DIFF_TERM("FALSE"), .IOSTANDARD("LVDS_25")) u_clock_input
        (.I(rx_clk_p), .IB(rx_clk_n), .O(rx_clk_pad));
    BUFG u_rx_clock (.I(rx_clk_pad), .O(rx_clk));

    xpm_cdc_async_rst #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .RST_ACTIVE_HIGH(1))
    u_rx_reset (.src_arst(!aresetn), .dest_clk(rx_clk), .dest_arst(rx_reset));
    xpm_cdc_async_rst #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .RST_ACTIVE_HIGH(1))
    u_axis_reset (.src_arst(!aresetn), .dest_clk(m_axis_aclk), .dest_arst(axis_reset));

    (* IODELAY_GROUP = IO_DELAY_GROUP *)
    IDELAYCTRL u_delay_calibration
        (.REFCLK(ref_clk200), .RST(delay_reset_ref), .RDY(delay_ready_ref));
    xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(0))
    u_delay_ready_cdc (.src_clk(ref_clk200), .src_in(delay_ready_ref),
        .dest_clk(rx_clk), .dest_out(delay_ready_rx));

    genvar lane;
    generate for (lane = 0; lane < 7; lane = lane + 1) begin : g_input
        if (lane == 6) begin : g_frame
            IBUFDS #(.DIFF_TERM("FALSE"), .IOSTANDARD("LVDS_25")) u_input
                (.I(rx_frame_p), .IB(rx_frame_n), .O(pad_data[lane]));
        end else begin : g_data
            IBUFDS #(.DIFF_TERM("FALSE"), .IOSTANDARD("LVDS_25")) u_input
                (.I(rx_data_p[lane]), .IB(rx_data_n[lane]), .O(pad_data[lane]));
        end
        // The vendor register plane drives these in m_axis_aclk. IDELAYE2
        // control uses that same clock; only the delayed serial data feeds RX.
        (* IODELAY_GROUP = IO_DELAY_GROUP *)
        IDELAYE2 #(.DELAY_SRC("IDATAIN"), .IDELAY_TYPE("VAR_LOAD"),
            .IDELAY_VALUE(0), .HIGH_PERFORMANCE_MODE("TRUE"),
            .REFCLK_FREQUENCY(200.0), .SIGNAL_PATTERN("DATA")) u_delay (
            .C(m_axis_aclk), .CE(1'b0), .INC(1'b0), .LD(up_adc_dld[lane]),
            .CNTVALUEIN(up_adc_dwdata[lane*5 +: 5]),
            .CNTVALUEOUT(up_adc_drdata[lane*5 +: 5]),
            .IDATAIN(pad_data[lane]), .DATAIN(1'b0),
            .DATAOUT(delayed_data[lane]), .CINVCTRL(1'b0),
            .LDPIPEEN(1'b0), .REGRST(1'b0));
        IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .SRTYPE("SYNC"),
            .INIT_Q1(1'b0), .INIT_Q2(1'b0)) u_ddr (
            .C(rx_clk), .CE(1'b1), .D(delayed_data[lane]),
            .Q1(early_data[lane]), .Q2(late_data[lane]),
            .R(rx_reset), .S(1'b0));
    end endgenerate

    // Nine chronological half-words cover an eight-slot tuple ending on
    // either sampled edge. Require the preceding FRAME=0 as well as 11110000
    // to distinguish the RX1 boundary. All candidates contain a whole tuple.
    reg [41:0] chunk_history = 0;
    reg [7:0] frame_history = 0;
    reg [2:0] history_count = 0;
    wire [53:0] chunk_window = {chunk_history, early_chunk, late_chunk};
    wire [9:0] frame_window = {frame_history, early_data[6], late_data[6]};
    wire ends_early = frame_window[9:1] == 9'b011110000;
    wire ends_late = frame_window[8:0] == 9'b011110000;
    wire candidate_valid = (history_count == 5) && (ends_early || ends_late);
    wire [47:0] chunks = ends_early ? chunk_window[53:6] : chunk_window[47:0];
    wire [11:0] candidate_i1 = {chunks[47:42], chunks[35:30]};
    wire [11:0] candidate_q1 = {chunks[41:36], chunks[29:24]};
    wire [11:0] candidate_i2 = {chunks[23:18], chunks[11:6]};
    wire [11:0] candidate_q2 = {chunks[17:12], chunks[5:0]};
    reg [47:0] rx_sample_data = 0;
    reg rx_sample_valid = 0;
    reg rx_frame_locked = 0;
    reg [1:0] tuple_interval = 0;
    reg tuple_ends_early = 0;
    reg frame_fault = 0;
    wire decoder_reset = rx_reset || adc_reset_rx || !delay_ready_rx || adc_r1_mode;

    always @(posedge rx_clk) begin
        rx_sample_valid <= 1'b0;
        frame_fault <= 1'b0;
        if (decoder_reset) begin
            chunk_history <= 0;
            frame_history <= 0;
            history_count <= 0;
            rx_sample_data <= 0;
            rx_frame_locked <= 1'b0;
            tuple_interval <= 0;
            tuple_ends_early <= 0;
        end else begin
            chunk_history <= chunk_window[41:0];
            frame_history <= frame_window[7:0];
            if (history_count != 5) history_count <= history_count + 1'b1;
            if (candidate_valid) begin
                rx_sample_data <= {candidate_q2, candidate_i2, candidate_q1, candidate_i1};
                rx_sample_valid <= 1'b1;
                rx_frame_locked <= 1'b1;
                tuple_interval <= 0;
                tuple_ends_early <= ends_early;
                // Four whole clocks alone cannot detect a one-half-clock
                // slip. A locked stream must also preserve its edge parity.
                if (rx_frame_locked && ((tuple_interval != 3) ||
                    (tuple_ends_early != ends_early))) frame_fault <= 1'b1;
            end else if (rx_frame_locked) begin
                tuple_interval <= tuple_interval + 1'b1;
                if (tuple_interval == 3) begin
                    rx_frame_locked <= 1'b0;
                    frame_fault <= 1'b1;
                end
            end
        end
    end

    // Capture is one-shot until fabric reset. A software ARM pulse can arrive
    // before acquisition; keep the request until the receiver becomes ready.
    reg arm_latched_axis = 0;
    wire arm_request_rx;
    reg active_rx = 0;
    reg overflow_rx = 0;
    reg frame_error_rx = 0;
    reg delay_error_rx = 0;
    wire fifo_full, fifo_empty, fifo_write_busy, fifo_read_busy;
    reg fifo_reset = 1'b1;
    reg axis_running = 1'b0;
    reg tuple_pending = 1'b0;
    reg [63:0] pending_data = 0;
    wire receiver_ready_rx = !decoder_reset && !fifo_write_busy;
    always @(posedge m_axis_aclk) begin
        axis_running <= !axis_reset;
        if (axis_reset) arm_latched_axis <= 1'b0;
        else if (capture_arm) arm_latched_axis <= 1'b1;
    end
    xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(0))
    u_arm_cdc (.src_clk(m_axis_aclk), .src_in(arm_latched_axis),
        .dest_clk(rx_clk), .dest_out(arm_request_rx));

    always @(posedge rx_clk) begin
        if (rx_reset) begin
            active_rx <= 1'b0;
            overflow_rx <= 1'b0;
            frame_error_rx <= 1'b0;
            delay_error_rx <= 1'b0;
        end else begin
            if (arm_request_rx && receiver_ready_rx && rx_frame_locked && (&channel_enable_rx))
                active_rx <= 1'b1;
            if (active_rx) begin
                if (tuple_pending && !fifo_write_busy && !fifo_reset && fifo_full)
                    overflow_rx <= 1'b1;
                if (frame_fault || adc_reset_rx || adc_r1_mode) frame_error_rx <= 1'b1;
                if (!delay_ready_rx) delay_error_rx <= 1'b1;
            end
        end
    end

    wire [63:0] tuple_data = {
        {4{rx_sample_data[47]}}, rx_sample_data[47:36],
        {4{rx_sample_data[35]}}, rx_sample_data[35:24],
        {4{rx_sample_data[23]}}, rx_sample_data[23:12],
        {4{rx_sample_data[11]}}, rx_sample_data[11:0]};
    // Synchronous controls at the BRAM boundary: asynchronous reset assertion
    // and ADI control CDC outputs must not feed RAM enables combinationally.
    always @(posedge rx_clk) begin
        fifo_reset <= rx_reset;
        if (rx_reset) begin
            tuple_pending <= 1'b0;
            pending_data <= 0;
        end else begin
            tuple_pending <= active_rx && receiver_ready_rx &&
                (&channel_enable_rx) && rx_sample_valid;
            pending_data <= tuple_data;
        end
    end
    wire fifo_write = tuple_pending && !fifo_full && !fifo_write_busy && !fifo_reset;
    wire fifo_read = m_axis_tvalid && m_axis_tready;
    wire [63:0] fifo_data;
    // Reset is released synchronously in the write domain. No read/write is
    // allowed while that side reports reset busy. The ADC cannot be stalled:
    // a full FIFO drops whole tuples and latches overflow for software.
    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"), .FIFO_WRITE_DEPTH(FIFO_DEPTH),
        .WRITE_DATA_WIDTH(64), .READ_DATA_WIDTH(64),
        .CDC_SYNC_STAGES(4), .READ_MODE("fwft"), .FIFO_READ_LATENCY(0),
        .FULL_RESET_VALUE(0), .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"), .USE_ADV_FEATURES("0000"),
        .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH)+1),
        .RD_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH)+1),
        .PROG_FULL_THRESH(10), .PROG_EMPTY_THRESH(10),
        // Vivado 2020.2 XPM S-5 compares an asynchronous read pointer to its
        // delayed synchronized value on the very next clock and false-fails.
        // The regression checks reset/busy/enable and data continuity instead.
        .SIM_ASSERT_CHK(0), .WAKEUP_TIME(0)
    ) u_capture_fifo (
        .rst(fifo_reset), .wr_clk(rx_clk), .rd_clk(m_axis_aclk),
        .din(pending_data), .wr_en(fifo_write), .full(fifo_full),
        .wr_rst_busy(fifo_write_busy), .rd_en(fifo_read),
        .dout(fifo_data), .empty(fifo_empty), .rd_rst_busy(fifo_read_busy),
        .sleep(1'b0), .injectsbiterr(1'b0), .injectdbiterr(1'b0),
        .almost_empty(), .almost_full(), .data_valid(), .dbiterr(),
        .overflow(), .prog_empty(), .prog_full(), .rd_data_count(),
        .sbiterr(), .underflow(), .wr_ack(), .wr_data_count());

    // FWFT owns the output word until the AXIS handshake consumes it.
    // TLAST advances only with a transfer, so every signal remains stable
    // during backpressure, including a stalled packet's final beat.
    localparam integer PACKET_WIDTH = PACKET_SAMPLES > 1 ? $clog2(PACKET_SAMPLES) : 1;
    reg [PACKET_WIDTH-1:0] packet_index = 0;
    assign m_axis_tvalid = axis_running && !fifo_read_busy && !fifo_empty;
    assign m_axis_tdata = fifo_data;
    assign m_axis_tkeep = 8'hff;
    assign m_axis_tlast = (packet_index == PACKET_SAMPLES-1);
    always @(posedge m_axis_aclk) begin
        if (axis_reset) packet_index <= 0;
        else if (fifo_read) begin
            if (m_axis_tlast) packet_index <= 0;
            else packet_index <= packet_index + 1'b1;
        end
    end

    wire [5:0] status_rx = {delay_error_rx, frame_error_rx, overflow_rx,
        active_rx, rx_frame_locked, receiver_ready_rx};
    wire [5:0] status_axis;
    generate for (lane = 0; lane < 6; lane = lane + 1) begin : g_status
        xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1))
        u_sync (.src_clk(rx_clk), .src_in(status_rx[lane]),
            .dest_clk(m_axis_aclk), .dest_out(status_axis[lane]));
    end endgenerate
    assign {delay_error, frame_error, overflow, capture_active, frame_locked, rx_ready}
        = axis_reset ? 6'd0 : status_axis;

    // Synthesis-visible debug taps in the same domain as the AXIS ILA.
    (* MARK_DEBUG = "TRUE" *) wire [63:0] debug_axis_data = m_axis_tdata;
    (* MARK_DEBUG = "TRUE" *) wire [9:0] debug_axis_flags =
        {status_axis, m_axis_tlast, m_axis_tready, m_axis_tvalid, capture_arm};
    (* MARK_DEBUG = "TRUE" *) wire [23:0] debug_sample_count = sample_counter_axis;
    (* MARK_DEBUG = "TRUE" *) wire [23:0] debug_clock_count = edge_counter_axis;

    // synthesis translate_off
    initial begin
        if (FIFO_DEPTH < 16 || FIFO_DEPTH > 4194304 || ((FIFO_DEPTH & (FIFO_DEPTH-1)) != 0))
            $fatal(1, "FIFO_DEPTH must be a power of two, at least 16 (XPM FIFO)");
        if (PACKET_SAMPLES < 1) $fatal(1, "PACKET_SAMPLES must be positive");
    end
    // synthesis translate_on

    // Compatibility register plane. The ADI monitor receives every decoded
    // tuple, including ARM=0, so software can tune and check PN before capture.

    wire up_wreq;
    wire [13:0] up_waddr;
    wire [31:0] up_wdata;
    wire up_rreq;
    wire [13:0] up_raddr;
    wire adi_up_wack;
    wire adi_up_rack;
    wire [31:0] adi_up_rdata;
    wire [12:0] adi_delay_load;
    wire [64:0] adi_delay_write;
    wire [64:0] adi_delay_read;
    reg diagnostic_rack = 1'b0;
    reg [31:0] diagnostic_rdata = 32'd0;

    reg [23:0] sample_counter_rx = 24'd0;
    reg [23:0] edge_counter_rx = 24'd0;

    // These counters remain alive during ADC register resets and delay tuning.
    // The edge counter counts complete DATA_CLK cycles, as expected by the
    // existing driver (four DATA_CLK cycles per dual-channel tuple).
    always @(posedge rx_clk) begin
        if (rx_reset) begin
            sample_counter_rx <= 24'd0;
            edge_counter_rx <= 24'd0;
        end else begin
            edge_counter_rx <= edge_counter_rx + 1'b1;
            if (rx_sample_valid)
                sample_counter_rx <= sample_counter_rx + 1'b1;
        end
    end

    xpm_cdc_gray #(
        .DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
        .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(24)
    ) u_sample_counter_cdc (
        .src_clk(rx_clk), .src_in_bin(sample_counter_rx),
        .dest_clk(m_axis_aclk), .dest_out_bin(sample_counter_axis)
    );

    xpm_cdc_gray #(
        .DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
        .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(24)
    ) u_edge_counter_cdc (
        .src_clk(rx_clk), .src_in_bin(edge_counter_rx),
        .dest_clk(m_axis_aclk), .dest_out_bin(edge_counter_axis)
    );

    // Board diagnostics remain active with ARM=0. Count only increments of
    // one so each source counter can cross through a Gray synchronizer.
    // FRAME rising edges (not both edges) occur at the dual-RX sample rate.
    reg frame_previous_late = 0;
    wire frame_rising = (!frame_previous_late && early_data[6]) ||
        (!early_data[6] && late_data[6]);
    wire [7:0] diagnostic_events =
        (8'b00010000 << {early_data[6], late_data[6]}) |
        {4'b0000, !delay_ready_rx, (!decoder_reset && !rx_frame_locked),
         frame_rising, frame_fault};
    wire [191:0] diagnostic_counters_axis;
    always @(posedge rx_clk) begin
        if (rx_reset) frame_previous_late <= 1'b0;
        else frame_previous_late <= late_data[6];
    end
    genvar diagnostic_index;
    generate for (diagnostic_index = 0; diagnostic_index < 8;
        diagnostic_index = diagnostic_index + 1) begin : g_diagnostics
        reg [23:0] counter_rx = 0;
        always @(posedge rx_clk) begin
            if (rx_reset) counter_rx <= 0;
            else if (diagnostic_events[diagnostic_index]) counter_rx <= counter_rx + 1'b1;
        end
        xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
            .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(24)) u_count_cdc (
            .src_clk(rx_clk), .src_in_bin(counter_rx), .dest_clk(m_axis_aclk),
            .dest_out_bin(diagnostic_counters_axis[diagnostic_index*24 +: 24]));
    end endgenerate

    // A separate observation FIFO records every RX clock independently of
    // ARM. It never backpressures capture. Sequence gaps expose debug drops.
    // Record: [47:32] RX cycle tag, [25:22] ready/fault/valid/locked,
    // [21:14] previous FRAME history, [13:7] early {FRAME,DATA}, [6:0] late.
    reg [47:0] raw_record_rx = 0;
    reg raw_pending_rx = 0;
    wire raw_full, raw_empty, raw_write_busy, raw_read_busy;
    wire [47:0] raw_record_axis;
    wire raw_read = axis_running && !raw_read_busy && !raw_empty;
    always @(posedge rx_clk) begin
        if (rx_reset) begin
            raw_pending_rx <= 1'b0;
            raw_record_rx <= 0;
        end else begin
            raw_pending_rx <= 1'b1;
            raw_record_rx <= {edge_counter_rx[15:0], edge_counter_rx[21:16], delay_ready_rx,
                frame_fault, rx_sample_valid, rx_frame_locked,
                frame_history, early_data, late_data};
        end
    end
    xpm_fifo_async #(.FIFO_MEMORY_TYPE("block"), .FIFO_WRITE_DEPTH(128),
        .WRITE_DATA_WIDTH(48), .READ_DATA_WIDTH(48), .CDC_SYNC_STAGES(4),
        .READ_MODE("fwft"), .FIFO_READ_LATENCY(0), .FULL_RESET_VALUE(0),
        .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"), .USE_ADV_FEATURES("0000"),
        .WR_DATA_COUNT_WIDTH(8), .RD_DATA_COUNT_WIDTH(8),
        .PROG_FULL_THRESH(10), .PROG_EMPTY_THRESH(10), .SIM_ASSERT_CHK(0),
        .WAKEUP_TIME(0)) u_observation_fifo (
        .rst(fifo_reset), .wr_clk(rx_clk), .rd_clk(m_axis_aclk), .din(raw_record_rx),
        .wr_en(raw_pending_rx && !fifo_reset && !raw_write_busy && !raw_full),
        .full(raw_full), .wr_rst_busy(raw_write_busy), .rd_en(raw_read),
        .dout(raw_record_axis), .empty(raw_empty), .rd_rst_busy(raw_read_busy),
        .sleep(1'b0), .injectsbiterr(1'b0), .injectdbiterr(1'b0), .almost_empty(),
        .almost_full(), .data_valid(), .dbiterr(), .overflow(), .prog_empty(),
        .prog_full(), .rd_data_count(), .sbiterr(), .underflow(), .wr_ack(), .wr_data_count());
    (* MARK_DEBUG = "TRUE" *) wire [48:0] debug_raw_rx = {raw_read, raw_record_axis};

    // Preserve the three project-specific words and extend diagnostics. ADI's
    // internal bus uses word addresses rather than AXI byte addresses.
    always @(posedge m_axis_aclk) begin
        diagnostic_rack <= 1'b0;
        diagnostic_rdata <= 32'd0;
        if (axis_resetn && up_rreq) begin
            case (up_raddr)
                14'h0400: begin
                    diagnostic_rack <= 1'b1;
                    diagnostic_rdata <= {8'd0, sample_counter_axis};
                end
                14'h0401: begin
                    diagnostic_rack <= 1'b1;
                    diagnostic_rdata <= {8'd0, edge_counter_axis};
                end
                14'h0402: begin
                    diagnostic_rack <= 1'b1;
                    diagnostic_rdata <= 32'h41445258;
                end
                14'h0403: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[23:0]}; end
                14'h0404: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[47:24]}; end
                14'h0405: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[71:48]}; end
                14'h0406: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[95:72]}; end
                14'h0407: begin diagnostic_rack <= 1; diagnostic_rdata <= 32'h00010001; end
                14'h0408: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[119:96]}; end
                14'h0409: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[143:120]}; end
                14'h040a: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[167:144]}; end
                14'h040b: begin diagnostic_rack <= 1; diagnostic_rdata <= {8'd0, diagnostic_counters_axis[191:168]}; end
                default: begin end
            endcase
        end
    end

    // Preserve native ADI bridge semantics. The upstream PS uses word writes;
    // this vendor bridge accepts AW/W together and does not apply WSTRB.
    up_axi #(.AXI_ADDRESS_WIDTH(16)) u_register_bridge (
        .up_rstn(axis_resetn), .up_clk(m_axis_aclk),
        .up_axi_awvalid(s_axi_awvalid), .up_axi_awaddr(s_axi_awaddr),
        .up_axi_awready(s_axi_awready),
        .up_axi_wvalid(s_axi_wvalid), .up_axi_wdata(s_axi_wdata),
        .up_axi_wstrb(s_axi_wstrb), .up_axi_wready(s_axi_wready),
        .up_axi_bvalid(s_axi_bvalid), .up_axi_bresp(s_axi_bresp),
        .up_axi_bready(s_axi_bready),
        .up_axi_arvalid(s_axi_arvalid), .up_axi_araddr(s_axi_araddr),
        .up_axi_arready(s_axi_arready),
        .up_axi_rvalid(s_axi_rvalid), .up_axi_rresp(s_axi_rresp),
        .up_axi_rdata(s_axi_rdata), .up_axi_rready(s_axi_rready),
        .up_wreq(up_wreq), .up_waddr(up_waddr), .up_wdata(up_wdata),
        .up_wack(adi_up_wack),
        .up_rreq(up_rreq), .up_raddr(up_raddr),
        .up_rdata(adi_up_rdata | diagnostic_rdata),
        .up_rack(adi_up_rack | diagnostic_rack)
    );

    assign up_adc_dld = adi_delay_load[6:0];
    assign up_adc_dwdata = adi_delay_write[34:0];
    assign adi_delay_read = {30'd0, up_adc_drdata};

    // Only the documented control/PN-monitor interface is reused. Physical
    // capture, frame decoding, tuple packing, packetization and FIFO ownership
    // belong to the new receiver implementation surrounding this fragment.
    axi_ad9361_rx #(
        .ID(0), .FPGA_TECHNOLOGY(1), .MODE_1R1T(0),
        .CMOS_OR_LVDS_N(0), .PPS_RECEIVER_ENABLE(0), .INIT_DELAY(0),
        .USERPORTS_DISABLE(1), .DATAFORMAT_DISABLE(1),
        .DCFILTER_DISABLE(1), .IQCORRECTION_DISABLE(1)
    ) u_registers_pn (
        .mmcm_rst(adc_mmcm_reset),
        .adc_rst(adc_reset_rx), .adc_clk(rx_clk),
        .adc_valid(rx_sample_valid), .adc_data(rx_sample_data),
        .adc_status(rx_frame_locked),
        .adc_r1_mode(adc_r1_mode), .adc_ddr_edgesel(adc_ddr_edgesel),
        .dac_data(48'd0),
        .up_dld(adi_delay_load), .up_dwdata(adi_delay_write),
        .up_drdata(adi_delay_read), .delay_clk(ref_clk200),
        .delay_rst(delay_reset_ref), .delay_locked(delay_ready_ref),
        .adc_enable_i0(channel_enable_rx[0]), .adc_valid_i0(), .adc_data_i0(),
        .adc_enable_q0(channel_enable_rx[1]), .adc_valid_q0(), .adc_data_q0(),
        .adc_enable_i1(channel_enable_rx[2]), .adc_valid_i1(), .adc_data_i1(),
        .adc_enable_q1(channel_enable_rx[3]), .adc_valid_q1(), .adc_data_q1(),
        .adc_dovf(overflow_rx),
        .up_adc_gpio_in(32'd0), .up_adc_gpio_out(),
        .up_pps_rcounter(32'd0), .up_pps_status(1'b1), .up_pps_irq_mask(),
        .up_rstn(axis_resetn), .up_clk(m_axis_aclk),
        .up_wreq(up_wreq), .up_waddr(up_waddr), .up_wdata(up_wdata),
        .up_wack(adi_up_wack),
        .up_rreq(up_rreq), .up_raddr(up_raddr),
        .up_rdata(adi_up_rdata), .up_rack(adi_up_rack),
        .up_drp_sel(), .up_drp_wr(), .up_drp_addr(), .up_drp_wdata(),
        .up_drp_rdata(32'd0), .up_drp_ready(1'b0), .up_drp_locked(1'b1)
    );

endmodule
