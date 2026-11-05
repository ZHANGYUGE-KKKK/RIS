`timescale 1ns / 1ps

// RFMC6000 / AD9361, 7-series, two RX channels, LVDS DDR, repeating RX_FRAME.
// Falling edge carries I, following rising edge carries Q by default.
// FRAME is high for I1/Q1 MSB + LSB, low for I2/Q2 MSB + LSB.
// One AXIS beat: {sign_extended_Q2, I2, Q1, I1}; every component is 16 bits.
//
// capture_arm is a level in m_axis_aclk, synchronized and latched in RX.
// Prepare DMA first, then assert arm. It remains armed until aresetn is low.
// aresetn resets the entire acquisition/FIFO; it is not a packet stop command.
// Never pause the physical ADC with TREADY. Buffer stalls; latch any loss and
// stop admitting new samples. Already buffered beats remain AXIS-compliant.
// All status outputs below belong to m_axis_aclk and clear only on reset.
//
// INPUT_DELAY_TAPS has seven 5-bit fields: D0..D5, then FRAME [34:30].
// VAR_LOAD taps are loaded at startup in ref_clk200. Default: reference tap 8.
// Input alignment follows the RFMC6000 7035 example: SAME_EDGE_PIPELINED,
// register falling-edge samples once, then pair them with rising-edge samples.
// Board-specific taps still need a PN/error-window check.
// Requires Vivado XPM_FIFO, XPM_CDC, XPM_MEMORY and a stable 200 MHz refclk.
// m_axis_aclk uses PS FCLK_CLK0 at 100 MHz. RX capture uses AD9361 DATA_CLK;
// ref_clk200 is for IDELAY calibration/loading and remains at 200 MHz.
module rfmc6000_iq_axis #(
    parameter integer FIFO_DEPTH = 4096,
    parameter integer PACKET_SAMPLES = 4096,
    parameter [34:0] INPUT_DELAY_TAPS = {7{5'd8}},
    parameter integer I_ON_FALLING_EDGE = 1,
    // 1: legacy RFMC falling edge + following rising edge.
    // 0: same-cycle pipelined IDDR outputs, selected for FMCOMMS3.
    parameter integer FALLING_EDGE_DELAY = 1,
    parameter IO_DELAY_GROUP = "RFMC_IQ_RX_DELAY"
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
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 100000000, ASSOCIATED_BUSIF M_AXIS, ASSOCIATED_RESET aresetn" *)
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
    input wire m_axis_tready
);
    localparam integer PACKET_COUNT_WIDTH =
        (PACKET_SAMPLES <= 1) ? 1 : $clog2(PACKET_SAMPLES);

    wire rx_clk_ibuf, rx_clk;
    IBUFDS #(.IOSTANDARD("LVDS_25"), .DIFF_TERM("FALSE"),
             .IBUF_LOW_PWR("FALSE")) i_rx_clk (
        .I(rx_clk_p), .IB(rx_clk_n), .O(rx_clk_ibuf));
    BUFG i_rx_clk_global (.I(rx_clk_ibuf), .O(rx_clk));

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
    (* MARK_DEBUG = "TRUE" *) wire rx_resetn = rx_reset_pipe[2];
    wire axis_resetn = axis_reset_pipe[2];
    wire ref_resetn = ref_reset_pipe[2];

    // 64 reference cycles hold IDELAYCTRL reset for >= 320 ns.
    reg [5:0] delay_reset_count = 0;
    always @(posedge ref_clk200 or negedge ref_resetn)
        if (!ref_resetn) delay_reset_count <= 0;
        else if (!(&delay_reset_count))
            delay_reset_count <= delay_reset_count + 1'b1;
    wire delay_ready_ref;
    (* IODELAY_GROUP = IO_DELAY_GROUP *) IDELAYCTRL i_delay_ctrl (
        .REFCLK(ref_clk200), .RST(!ref_resetn || !(&delay_reset_count)),
        .RDY(delay_ready_ref));

    // Match the reference's VAR_LOAD input delays, without passing its
    // 100 MHz AXI register bus directly into the 200 MHz delay-load clock.
    // All seven parameter fields are constant during operation. Load once
    // after calibration, then allow seven reference cycles to settle.
    reg [2:0] delay_load_count = 0;
    always @(posedge ref_clk200)
        if (!ref_resetn || !delay_ready_ref) delay_load_count <= 0;
        else if (!(&delay_load_count))
            delay_load_count <= delay_load_count + 1'b1;
    wire delay_load = delay_ready_ref && (delay_load_count == 0);
    // Register the ready level before CDC. Clear it even if REFCLK stops:
    // IDELAYCTRL.RDY dropping must not depend on another reference edge.
    wire delay_config_resetn = ref_resetn && delay_ready_ref;
    reg delay_configured_ref = 0;
    always @(posedge ref_clk200 or negedge delay_config_resetn)
        if (!delay_config_resetn) delay_configured_ref <= 0;
        else delay_configured_ref <= &delay_load_count;

    wire [6:0] lane_p = {rx_frame_p, rx_data_p};
    wire [6:0] lane_n = {rx_frame_n, rx_data_n};
    wire [6:0] lane_ibuf, lane_delay;
    (* MARK_DEBUG = "TRUE" *) wire [6:0] lane_rise, lane_fall;
    genvar lane;
    generate for (lane = 0; lane < 7; lane = lane + 1) begin : g_rx_lane
        localparam integer TAP = INPUT_DELAY_TAPS[lane*5 +: 5];
        IBUFDS #(.IOSTANDARD("LVDS_25"), .DIFF_TERM("FALSE"),
                 .IBUF_LOW_PWR("FALSE")) i_buffer (
            .I(lane_p[lane]), .IB(lane_n[lane]), .O(lane_ibuf[lane]));
        (* IODELAY_GROUP = IO_DELAY_GROUP *) IDELAYE2 #(
            .DELAY_SRC("IDATAIN"), .IDELAY_TYPE("VAR_LOAD"),
            .IDELAY_VALUE(TAP), .REFCLK_FREQUENCY(200.0),
            .HIGH_PERFORMANCE_MODE("FALSE"), .SIGNAL_PATTERN("DATA")
        ) i_delay (
            .IDATAIN(lane_ibuf[lane]), .DATAIN(1'b0),
            .DATAOUT(lane_delay[lane]), .C(ref_clk200), .CE(1'b0),
            .INC(1'b0), .LD(delay_load), .LDPIPEEN(1'b0), .REGRST(1'b0),
            .CINVCTRL(1'b0), .CNTVALUEIN(TAP[4:0]), .CNTVALUEOUT());
        IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .SRTYPE("ASYNC"),
               .INIT_Q1(1'b0), .INIT_Q2(1'b0)) i_ddr (
            // The RFMC reference runs IDDR continuously with R/S tied low.
            // Local reset clears the alignment/decoder/FIFO; their release
            // and boot/FRAME checks flush the IDDR pipeline before admission.
            // Avoid a high-fanout reset with a half-cycle IDDR recovery check.
            .C(rx_clk), .CE(1'b1), .R(1'b0), .S(1'b0),
            .D(lane_delay[lane]), .Q1(lane_rise[lane]),
            .Q2(lane_fall[lane]));
    end endgenerate

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
    // Keep data and FRAME under the same edge-pair selection. The legacy
    // reference delays Q2 once; FMCOMMS3 pairs the same-cycle Q2 and Q1.
    (* MARK_DEBUG = "TRUE" *) reg [6:0] lane_fall_d = 0;
    (* MARK_DEBUG = "TRUE" *) reg [11:0] rx_data_pair = 0;
    (* MARK_DEBUG = "TRUE" *) reg [1:0] frame_pair = 0;
    always @(posedge rx_clk or negedge rx_resetn) begin
        if (!rx_resetn) begin
            lane_fall_d <= 0; rx_data_pair <= 0; frame_pair <= 0;
        end else begin
            lane_fall_d <= lane_fall;
            rx_data_pair <= {FALLING_EDGE_DELAY ? lane_fall_d[5:0] : lane_fall[5:0], lane_rise[5:0]};
            frame_pair <= {FALLING_EDGE_DELAY ? lane_fall_d[6] : lane_fall[6], lane_rise[6]};
        end
    end
    wire [5:0] i_half = I_ON_FALLING_EDGE ? rx_data_pair[11:6] : rx_data_pair[5:0];
    wire [5:0] q_half = I_ON_FALLING_EDGE ? rx_data_pair[5:0] : rx_data_pair[11:6];

    // Lock only after a complete 11,11,00,00 sequence, acquired on 00->11.
    // A wrong edge/frame sequence after lock invalidates the acquisition.
    (* MARK_DEBUG = "TRUE" *) reg [2:0] phase = 0;
    (* MARK_DEBUG = "TRUE" *) reg previous_low = 0;
    (* MARK_DEBUG = "TRUE" *) reg locked_rx = 0, frame_error_rx = 0, delay_error_rx = 0;
    reg [5:0] i_msb = 0, q_msb = 0;
    reg [11:0] i1 = 0, q1 = 0;
    (* MARK_DEBUG = "TRUE" *) reg [63:0] sample_data = 0;
    (* MARK_DEBUG = "TRUE" *) reg sample_valid = 0;
    wire [11:0] i2_complete = {i_msb, i_half};
    wire [11:0] q2_complete = {q_msb, q_half};
    wire fifo_source_ready;
    (* MARK_DEBUG = "TRUE" *) reg fifo_booted_rx = 0;
    (* MARK_DEBUG = "TRUE" *) reg armed_rx = 0, overflow_rx = 0;
    wire failed_rx = overflow_rx || frame_error_rx || delay_error_rx;

    // A FRAME fault is decided from the values visible to the decoder in this
    // cycle.  Keep this expression separate from the functional state machine
    // so the debug capture cannot alter receive behavior.
    wire frame_fault_event = ready_pipe[2] && fifo_booted_rx &&
        !failed_rx && locked_rx &&
        (((phase == 0) && !(previous_low && frame_pair == 2'b11)) ||
         ((phase == 1) &&  (frame_pair != 2'b11)) ||
         ((phase == 2) &&  (frame_pair != 2'b00)) ||
         ((phase == 3) &&  (frame_pair != 2'b00)));

    always @(posedge rx_clk or negedge rx_resetn) begin
        if (!rx_resetn) begin
            phase <= 0; previous_low <= 0; locked_rx <= 0;
            frame_error_rx <= 0; delay_error_rx <= 0;
            i_msb <= 0; q_msb <= 0; i1 <= 0; q1 <= 0;
            sample_data <= 0; sample_valid <= 0;
        end else begin
            sample_valid <= 0;
            if (!ready_pipe[2]) begin
                phase <= 0; previous_low <= 0;
                if (fifo_booted_rx) delay_error_rx <= 1'b1;
                locked_rx <= 0;
            end else if (!failed_rx && fifo_booted_rx) begin
                case (phase)
                    0: begin
                        previous_low <= (frame_pair == 2'b00);
                        if (previous_low && frame_pair == 2'b11) begin
                            i_msb <= i_half; q_msb <= q_half; phase <= 1;
                        end else if (locked_rx) begin
                            frame_error_rx <= 1'b1; locked_rx <= 0;
                        end
                    end
                    1: begin
                        if (frame_pair == 2'b11) begin
                            i1 <= {i_msb, i_half}; q1 <= {q_msb, q_half};
                            phase <= 2;
                        end else begin
                            phase <= 0; previous_low <= (frame_pair == 2'b00);
                            if (locked_rx) begin
                                frame_error_rx <= 1'b1; locked_rx <= 0;
                            end
                        end
                    end
                    2: begin
                        if (frame_pair == 2'b00) begin
                            i_msb <= i_half; q_msb <= q_half; phase <= 3;
                        end else begin
                            phase <= 0; previous_low <= 0;
                            if (locked_rx) begin
                                frame_error_rx <= 1'b1; locked_rx <= 0;
                            end
                        end
                    end
                    3: begin
                        if (frame_pair == 2'b00) begin
                            sample_data <= {
                                {4{q2_complete[11]}}, q2_complete,
                                {4{i2_complete[11]}}, i2_complete,
                                {4{q1[11]}}, q1, {4{i1[11]}}, i1};
                            sample_valid <= 1'b1; locked_rx <= 1'b1;
                            phase <= 0; previous_low <= 1'b1;
                        end else begin
                            phase <= 0; previous_low <= 0;
                            if (locked_rx) begin
                                frame_error_rx <= 1'b1; locked_rx <= 0;
                            end
                        end
                    end
                    default: phase <= 0;
                endcase
            end
        end
    end

    // Debug-only RX-domain recorder. It remembers the eight FRAME pairs
    // preceding the first post-lock fault and the decoder context. If lock
    // has not been acquired after 1048575 RX cycles, capture the unlocked
    // context instead (snapshot flags.locked=0 distinguishes this case).
    // The complete record is transferred atomically to ref_clk200;
    // no live RX bus is sampled directly by the 200 MHz ILA.
    localparam integer DIAG_SNAPSHOT_WIDTH = 142;
    reg [23:0] rx_edge_counter = 0;
    reg [15:0] frame_history_rx = 0;
    reg [DIAG_SNAPSHOT_WIDTH-1:0] diag_snapshot_rx = 0;
    reg diag_send_rx = 0, diag_sent_rx = 0;
    wire diag_src_rcv;
    always @(posedge rx_clk or negedge rx_resetn) begin
        if (!rx_resetn) begin
            rx_edge_counter <= 0;
            frame_history_rx <= 0;
            diag_snapshot_rx <= 0;
            diag_send_rx <= 0;
            diag_sent_rx <= 0;
        end else begin
            rx_edge_counter <= rx_edge_counter + 1'b1;
            frame_history_rx <= {frame_history_rx[13:0], frame_pair};
            if (diag_send_rx && diag_src_rcv)
                diag_send_rx <= 1'b0;
            if (!diag_sent_rx && (frame_fault_event ||
                (!locked_rx && ready_pipe[2] && fifo_booted_rx &&
                 rx_edge_counter == 24'd1048575))) begin
                diag_snapshot_rx <= {
                    rx_edge_counter, frame_history_rx, sample_data,
                    rx_data_pair,
                    FALLING_EDGE_DELAY ? lane_fall_d : lane_fall,
                    lane_rise, frame_pair,
                    phase[1:0], previous_low, locked_rx, ready_pipe[2],
                    fifo_booted_rx, armed_rx, overflow_rx, delay_error_rx,
                    sample_valid};
                diag_send_rx <= 1'b1;
                diag_sent_rx <= 1'b1;
            end
        end
    end

    wire [DIAG_SNAPSHOT_WIDTH-1:0] diag_snapshot_cdc;
    wire diag_snapshot_req_ref;
    xpm_cdc_handshake #(
        .DEST_EXT_HSK(0), .DEST_SYNC_FF(3), .SRC_SYNC_FF(3),
        .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(0),
        .WIDTH(DIAG_SNAPSHOT_WIDTH)
    ) i_diag_snapshot_cdc (
        .src_clk(rx_clk), .src_in(diag_snapshot_rx),
        .src_send(diag_send_rx), .src_rcv(diag_src_rcv),
        .dest_clk(ref_clk200), .dest_out(diag_snapshot_cdc),
        .dest_req(diag_snapshot_req_ref), .dest_ack(1'b0));

    // Gray-counter CDC measures whether DATA_CLK is alive independently of
    // FRAME decoding.  At 200 MHz, one 1 ms window contains 200000 cycles;
    // rx_edges_per_ms_ref therefore reports DATA_CLK frequency in kHz.
    (* MARK_DEBUG = "TRUE" *) wire [23:0] rx_counter_ref;
    xpm_cdc_gray #(
        .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .REG_OUTPUT(1),
        .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(24)
    ) i_diag_clock_counter_cdc (
        .src_clk(rx_clk), .src_in_bin(rx_edge_counter),
        .dest_clk(ref_clk200), .dest_out_bin(rx_counter_ref));

    reg [17:0] ref_measure_count = 0;
    reg [23:0] rx_counter_previous_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [23:0] rx_edges_per_ms_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg rx_clock_active_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg diag_snapshot_valid_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg diag_snapshot_pulse_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [23:0] diag_rx_counter_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [15:0] diag_frame_history_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [63:0] diag_sample_data_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [11:0] diag_rx_data_pair_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [6:0] diag_lane_fall_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [6:0] diag_lane_rise_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [1:0] diag_frame_pair_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [1:0] diag_phase_ref = 0;
    (* MARK_DEBUG = "TRUE" *) reg [7:0] diag_flags_ref = 0;
    always @(posedge ref_clk200 or negedge ref_resetn) begin
        if (!ref_resetn) begin
            ref_measure_count <= 0;
            rx_counter_previous_ref <= 0;
            rx_edges_per_ms_ref <= 0;
            rx_clock_active_ref <= 0;
            diag_snapshot_valid_ref <= 0;
            diag_snapshot_pulse_ref <= 0;
            diag_rx_counter_ref <= 0;
            diag_frame_history_ref <= 0;
            diag_sample_data_ref <= 0;
            diag_rx_data_pair_ref <= 0;
            diag_lane_fall_ref <= 0;
            diag_lane_rise_ref <= 0;
            diag_frame_pair_ref <= 0;
            diag_phase_ref <= 0;
            diag_flags_ref <= 0;
        end else begin
            diag_snapshot_pulse_ref <= 1'b0;
            if (ref_measure_count == 18'd199999) begin
                ref_measure_count <= 0;
                rx_edges_per_ms_ref <= rx_counter_ref - rx_counter_previous_ref;
                rx_clock_active_ref <= (rx_counter_ref != rx_counter_previous_ref);
                rx_counter_previous_ref <= rx_counter_ref;
            end else begin
                ref_measure_count <= ref_measure_count + 1'b1;
            end
            if (diag_snapshot_req_ref) begin
                diag_snapshot_valid_ref <= 1'b1;
                diag_snapshot_pulse_ref <= 1'b1;
                diag_rx_counter_ref <= diag_snapshot_cdc[141:118];
                diag_frame_history_ref <= diag_snapshot_cdc[117:102];
                diag_sample_data_ref <= diag_snapshot_cdc[101:38];
                diag_rx_data_pair_ref <= diag_snapshot_cdc[37:26];
                diag_lane_fall_ref <= diag_snapshot_cdc[25:19];
                diag_lane_rise_ref <= diag_snapshot_cdc[18:12];
                diag_frame_pair_ref <= diag_snapshot_cdc[11:10];
                diag_phase_ref <= diag_snapshot_cdc[9:8];
                diag_flags_ref <= diag_snapshot_cdc[7:0];
            end
        end
    end

    // An elastic slot keeps FIFO input stable during backpressure. If another
    // complete sample arrives before it drains, stop and latch overflow.
    reg [63:0] pending_data = 0;
    reg pending_valid = 0, pending_last = 0;
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

    // Synthesis accepts only useful packet sizes and power-of-two FIFO depths.
    // synthesis translate_off
    initial begin
        if (PACKET_SAMPLES < 1 || FIFO_DEPTH < 16 ||
            (FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0 ||
            (I_ON_FALLING_EDGE != 0 && I_ON_FALLING_EDGE != 1) ||
            (FALLING_EDGE_DELAY != 0 && FALLING_EDGE_DELAY != 1))
            $fatal(1, "Invalid rfmc6000_iq_axis parameters");
    end
    // synthesis translate_on
endmodule
