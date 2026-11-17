`timescale 1ns / 1ps

// Uses actual Xilinx UNISIM IO primitives and XPM async FIFO, no FIFO mocks.
module tb_rfmc6000_iq_axis;
    parameter integer I_FALLING = 1;
    parameter integer PACKET_WORDS = 7;
    parameter integer SKEW_TAPS = 0;
    parameter integer FALL_DELAY = 1;
    localparam [34:0] DELAY_TAPS = SKEW_TAPS ?
        {5'd8, 5'd10, 5'd6, 5'd8, 5'd9, 5'd7, 5'd8} : {7{5'd12}};
    localparam integer NORMAL_TARGET = (PACKET_WORDS > 100) ?
                                       PACKET_WORDS * 2 + 3 : 200;
    reg rx_clk = 0, ref_clk = 0, axis_clk = 0;
    reg rx_clock_running = 1;
    reg ref_clock_running = 1;
    always #2.0345 if (rx_clock_running) rx_clk = ~rx_clk; // 245.76 MHz
    always #2.5 if (ref_clock_running) ref_clk = ~ref_clk;
    always #5.0 axis_clk = ~axis_clk; // PS FCLK0: 100 MHz, unrelated to RX
    reg resetn = 0, arm = 0;
    reg [5:0] data = 0;
    reg frame = 0;
    wire [63:0] axis_data;
    wire [7:0] keep;
    wire valid, last, ready_status, locked, active, overflow, frame_error, delay_error;
    reg ready = 0;
    integer ready_mode = 0;
    reg [15:0] lfsr = 16'h8a31;
    reg corrupt = 0;
    integer physical_index = 0;
    integer received = 0, next_index = -1, packet_index = 0;
    integer reset_floor = 0;
    reg stalled = 0;
    reg [63:0] held_data;
    reg [7:0] held_keep;
    reg held_last;

    rfmc6000_iq_axis #(.FIFO_DEPTH(64), .PACKET_SAMPLES(PACKET_WORDS),
                       .INPUT_DELAY_TAPS(DELAY_TAPS),
                       .FALLING_EDGE_DELAY(FALL_DELAY),
                       .I_ON_FALLING_EDGE(I_FALLING)) dut (
        .rx_clk_p(rx_clk), .rx_clk_n(~rx_clk),
        .rx_frame_p(frame), .rx_frame_n(~frame),
        .rx_data_p(data), .rx_data_n(~data), .ref_clk200(ref_clk),
        .aresetn(resetn), .m_axis_aclk(axis_clk), .capture_arm(arm),
        .rx_ready(ready_status), .frame_locked(locked), .capture_active(active),
        .overflow(overflow), .frame_error(frame_error), .delay_error(delay_error),
        .m_axis_tdata(axis_data), .m_axis_tkeep(keep), .m_axis_tvalid(valid),
        .m_axis_tlast(last), .m_axis_tready(ready));

    // Unmodified RFMC6000 7035 reference sees the same physical input. Its
    // output has one extra clock of latency after the final IQ pair. Check
    // every complete DUT tuple before CDC against that independent decoder.
    wire ref_valid;
    wire [11:0] ref_i1, ref_q1, ref_i2, ref_q2;
    axi_ad9361_dev_if_idelay reference_rx (
        .rx_frame_in_p(frame), .rx_frame_in_n(~frame),
        .rx_data_in_p(data), .rx_data_in_n(~data),
        .data_clk(dut.rx_clk), .clk200(ref_clk), .rstn(resetn),
        .adc_valid(ref_valid), .adc_data_i1(ref_i1), .adc_data_q1(ref_q1),
        .adc_data_i2(ref_i2), .adc_data_q2(ref_q2), .adc_status(),
        .adc_r1_mode(1'b0), .dac_valid(1'b0), .dac_r1_mode(1'b0),
        .dac_data_i1(12'd0), .dac_data_q1(12'd0),
        .dac_data_i2(12'd0), .dac_data_q2(12'd0),
        .tx_clk_out_p(), .tx_clk_out_n(), .tx_frame_out_p(), .tx_frame_out_n(),
        .tx_data_out_p(), .tx_data_out_n(), .chip_data(),
        .idly_en(7'h7f), .idly_d(5'd12));
    reg compare_valid = 0;
    reg [63:0] compare_data = 0;
    integer reference_matches = 0;
    always @(posedge dut.rx_clk) begin
        if (!dut.rx_resetn) compare_valid <= 0;
        else begin
            compare_valid <= dut.sample_valid;
            compare_data <= dut.sample_data;
        end
    end
    always @(negedge dut.rx_clk) begin
        if (resetn && I_FALLING && FALL_DELAY && compare_valid) begin
            if (!ref_valid || compare_data !==
                {extend12(ref_q2), extend12(ref_i2),
                 extend12(ref_q1), extend12(ref_i1)})
                $fatal(1, "RFMC6000 reference IQ/alignment mismatch: DUT %h, reference %h",
                       compare_data, {extend12(ref_q2), extend12(ref_i2),
                                      extend12(ref_q1), extend12(ref_i1)});
            reference_matches = reference_matches + 1;
        end
    end
    // Scoreboard the frozen-bank debug CDC independently of IQ decoding.
    // Source writes and REF reads use unrelated clocks; a bank cannot be
    // overwritten until every REF record has been consumed.
    reg [288:0] trace_expected [0:63];
    integer trace_received = 0;
    integer trace_next = 0;
    reg [23:0] trace_last_counter = 0;
    always @(posedge dut.rx_clk)
        if (dut.prefifo_write)
            trace_expected[dut.prefifo_write_index] = dut.prefifo_capture_word;
    always @(negedge ref_clk or negedge resetn) begin
        if (!resetn) trace_next = 0;
        else if (dut.prefifo_valid_ref) begin
            if (dut.prefifo_index_ref !== trace_next[5:0])
                $fatal(1, "200 MHz debug record index skipped/repeated");
            if (dut.prefifo_read_word !== trace_expected[trace_next])
                $fatal(1, "200 MHz debug record torn/corrupted across CDC");
            if (trace_next != 0 && dut.prefifo_rx_edge_counter_ref !==
                ((trace_last_counter + 1'b1) & 24'hffffff))
                $fatal(1, "Debug bank does not contain consecutive RX cycles");
            trace_last_counter = dut.prefifo_rx_edge_counter_ref;
            trace_next = (trace_next + 1) % 64;
            trace_received = trace_received + 1;
        end
    end
    genvar lane;
    generate for (lane = 0; lane < 7; lane = lane + 1) begin : check_delay_load
        always @(posedge axis_clk)
            if (ready_status &&
                dut.g_rx_lane[lane].i_delay.CNTVALUEOUT !== DELAY_TAPS[lane*5 +: 5])
                $fatal(1, "Lane %0d did not load configured tap before RX ready", lane);
    end endgenerate

    function automatic [11:0] value_i1(input integer n);
        value_i1 = n;
    endfunction
    function automatic [11:0] value_q1(input integer n);
        value_q1 = n ^ 12'h800;
    endfunction
    function automatic [11:0] value_i2(input integer n);
        value_i2 = n[0] ? 12'h7ff : 12'h800;
    endfunction
    function automatic [11:0] value_q2(input integer n);
        value_q2 = n[1] ? 12'hfff : 12'h000;
    endfunction
    function automatic [15:0] extend12(input [11:0] n);
        extend12 = {{4{n[11]}}, n};
    endfunction
    function automatic [63:0] expected_word(input integer n);
        expected_word = {extend12(value_q2(n)), extend12(value_i2(n)),
                         extend12(value_q1(n)), extend12(value_i1(n))};
    endfunction

    task automatic send_pair(input [5:0] i, input [5:0] q,
                              input bit f, input bit bad_frame);
        if (FALL_DELAY) begin
            @(posedge rx_clk);
            #0.2; data = I_FALLING ? i : q; frame = f;
            @(negedge rx_clk);
            #0.2; data = I_FALLING ? q : i; frame = bad_frame ? !f : f;
        end else begin
            // FMCOMMS3 FRAME qualifies a rising edge and the following fall.
            // Expected IQ words are generated independently above.
            @(negedge rx_clk);
            #0.2; data = I_FALLING ? q : i; frame = f;
            @(posedge rx_clk);
            #0.2; data = I_FALLING ? i : q; frame = bad_frame ? !f : f;
        end
    endtask
    task automatic send_sample(input integer n);
        reg [11:0] a, b, c, d;
        bit fault;
        a = value_i1(n); b = value_q1(n); c = value_i2(n); d = value_q2(n);
        send_pair(a[11:6], b[11:6], 1, 0);
        fault = corrupt;
        if (fault) corrupt = 0;
        send_pair(a[5:0], b[5:0], 1, fault);
        send_pair(c[11:6], d[11:6], 0, 0);
        send_pair(c[5:0], d[5:0], 0, 0);
    endtask
    initial forever begin
        send_sample(physical_index);
        physical_index = physical_index + 1;
    end

    always @(negedge axis_clk) begin
        lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        case (ready_mode)
            0: ready = 0;
            1: ready = 1;
            default: ready = lfsr[0] || lfsr[4];
        endcase
    end
    always @(posedge axis_clk) begin
        if (!resetn) begin
            received = 0; next_index = -1; packet_index = 0; stalled = 0;
        end else begin
            if (stalled && (!valid || axis_data !== held_data ||
                            keep !== held_keep || last !== held_last))
                $fatal(1, "AXIS payload/VALID changed while stalled");
            stalled = valid && !ready;
            held_data = axis_data; held_keep = keep; held_last = last;
            if (valid && ready) begin
                if (next_index == -1) begin
                    next_index = axis_data[11:0] + (reset_floor / 4096) * 4096;
                    if (next_index < reset_floor) next_index = next_index + 4096;
                    if (next_index > physical_index + 1)
                        $fatal(1, "Stale pre-reset data escaped the FIFO");
                end
                if (axis_data !== expected_word(next_index))
                    $fatal(1, "Missing/reordered/mixed IQ at index %0d: %h != %h",
                           next_index, axis_data, expected_word(next_index));
                if (keep !== 8'hff || last !== (packet_index == PACKET_WORDS-1))
                    $fatal(1, "TKEEP/TLAST mismatch at sample %0d", received);
                next_index = next_index + 1; received = received + 1;
                packet_index = (packet_index == PACKET_WORDS-1) ? 0 : packet_index+1;
            end
        end
    end

    // Check actual macro enables against its busy/full/empty flags. This
    // avoids the optional 2020.2 SVA that assumes a one-cycle CDC pointer.
    always @(posedge rx_clk) begin
        if (dut.i_cdc_fifo.xpm_fifo_base_inst.ram_wr_en_i &&
            (dut.i_cdc_fifo.xpm_fifo_base_inst.wrst_busy ||
             dut.i_cdc_fifo.xpm_fifo_base_inst.ram_full_i))
            $fatal(1, "FIFO write occurred while resetting or full");
    end
    always @(posedge axis_clk) begin
        if (dut.i_cdc_fifo.xpm_fifo_base_inst.ram_rd_en_i &&
            dut.i_cdc_fifo.xpm_fifo_base_inst.ram_empty_i)
            $fatal(1, "FIFO read occurred while resetting or empty");
    end

    task automatic reset_capture;
        @(negedge axis_clk); resetn = 0; arm = 0; ready_mode = 0;
        reset_floor = physical_index;
        #600;
        @(negedge axis_clk); resetn = 1;
        wait (ready_status && locked);
        repeat (10) @(negedge axis_clk);
        if (valid || active || overflow || frame_error || delay_error)
            $fatal(1, "Startup/arm/reset status is incorrect");
    endtask
    task automatic drain_and_check_stop;
        integer count;
        ready_mode = 1;
        repeat (300) @(negedge axis_clk);
        count = received;
        repeat (100) @(negedge axis_clk);
        if (valid || active || received != count)
            $fatal(1, "Capture continued after a data-loss fault");
    endtask

    initial begin
        reset_capture();
        ready_mode = 2; arm = 1;
        wait (received >= NORMAL_TARGET);
        if (overflow || frame_error || delay_error || !active)
            $fatal(1, "Healthy max-rate stream reported an error");
        if (dut.dbg_window_errors || dut.dbg_sequence_errors)
            $fatal(1, "Independent pre-FIFO monitor rejected healthy repeating FRAME");
        // Arm is latched; lowering it is deliberately not a mid-packet abort.
        arm = 0;
        wait (received >= NORMAL_TARGET + 30);
        $display("PASS: full-rate DDR IQ, signs, frame alignment, unrelated clocks, random backpressure, TLAST");
        if (I_FALLING && FALL_DELAY) begin
            if (reference_matches < NORMAL_TARGET)
                $fatal(1, "Insufficient RFMC6000 reference comparisons");
            $display("PASS: %0d complete IQ tuples match the unmodified RFMC6000 7035 reference", reference_matches);
        end

        ready_mode = 0;
        wait (overflow);
        repeat (8) @(negedge axis_clk);
        if (frame_error || delay_error || active) $fatal(1, "Overflow status incorrect");
        drain_and_check_stop();
        if (!overflow) $fatal(1, "Overflow did not stay latched");
        $display("PASS: FIFO overflow preserves the ordered prefix and stalled AXIS beat, then stops");

        reset_capture(); ready_mode = 1; arm = 1;
        wait (received >= 50);
        ready_mode = 0; corrupt = 1;
        wait (frame_error);
        repeat (8) @(negedge axis_clk);
        if (overflow || locked || active) $fatal(1, "Frame-loss status incorrect");
        drain_and_check_stop();
        if (!dut.dbg_window_errors || !dut.dbg_sequence_errors)
            $fatal(1, "Independent pre-FIFO monitor missed corrupt FRAME");
        $display("PASS: independent pre-FIFO monitor accepts healthy FRAME and detects corruption");
        $display("PASS: corrupt FRAME stops capture without emitting an incomplete IQ tuple");

        wait (dut.diag_snapshot_valid_ref);
        if ({dut.diag_rx_counter_ref, dut.diag_frame_history_ref,
             dut.diag_sample_data_ref, dut.diag_rx_data_pair_ref,
             dut.diag_lane_fall_ref, dut.diag_lane_rise_ref,
             dut.diag_frame_pair_ref, dut.diag_phase_ref,
             dut.diag_flags_ref} !== dut.diag_snapshot_rx)
            $fatal(1, "First FRAME fault snapshot was not transferred atomically");
        if (!dut.diag_flags_ref[6] || dut.diag_phase_ref != 1 ||
            dut.diag_frame_pair_ref == 2'b11)
            $fatal(1, "Snapshot does not describe the injected post-lock FRAME fault");
        $display("PASS: first FRAME fault context crosses atomically to the 200 MHz domain");

        if (I_FALLING && PACKET_WORDS == 7 && !SKEW_TAPS) begin
            #2100000;
            if (!dut.rx_clock_active_ref || dut.rx_edges_per_ms_ref < 245700 ||
                dut.rx_edges_per_ms_ref > 245850)
                $fatal(1, "200 MHz diagnostic measured the wrong RX clock frequency: %0d kHz",
                       dut.rx_edges_per_ms_ref);
            @(negedge rx_clk); rx_clock_running = 0;
            #2100000;
            if (dut.rx_clock_active_ref || dut.rx_edges_per_ms_ref != 0 ||
                !dut.diag_snapshot_valid_ref)
                $fatal(1, "200 MHz diagnostics did not retain the snapshot and detect stopped RX clock");
            rx_clock_running = 1;
            $display("PASS: independent 200 MHz clock measurement and stopped-RX snapshot retention");
        end

        // Reset must hide the old stream even while RX DATA_CLK is stopped.
        @(negedge rx_clk); rx_clock_running = 0;
        @(negedge axis_clk); resetn = 0; arm = 0;
        reset_floor = physical_index;
        #600;
        if (valid || overflow || frame_error || delay_error)
            $fatal(1, "Reset did not assert with RX clock stopped");
        rx_clock_running = 1;
        #200;
        @(negedge axis_clk); resetn = 1;
        wait (ready_status && locked);
        ready_mode = 1; arm = 1;
        wait (received >= 50);
        if (overflow || frame_error || delay_error)
            $fatal(1, "Clock-stop reset did not recover");
        $display("PASS: stopped-RX-clock reset, restart, and stale-data rejection");

        ready_mode = 0;
        // Readiness must clear even with no more reference-clock edges.
        @(negedge ref_clk); ref_clock_running = 0;
        force dut.delay_ready_ref = 1'b0;
        wait (delay_error);
        repeat (8) @(negedge axis_clk);
        release dut.delay_ready_ref;
        ref_clock_running = 1;
        if (overflow || active || ready_status)
            $fatal(1, "IDELAY lock-loss status incorrect");
        drain_and_check_stop();
        if (!delay_error) $fatal(1, "Delay error did not stay latched");
        $display("PASS: stopped reference clock/IDELAY lock loss invalidates capture and preserves buffered beats");
        if (I_FALLING && PACKET_WORDS == 7 && !SKEW_TAPS) begin
            // A stuck-low FRAME passes the reference allow-list, but must
            // fail the independent sequence checker even with ARM disabled.
            @(negedge axis_clk); resetn = 0; arm = 0; ready_mode = 0;
            force dut.frame_pair = 2'b00;
            #600;
            @(negedge axis_clk); resetn = 1;
            wait (dut.dbg_monitor_valid);
            repeat (16) @(negedge dut.rx_clk);
            if (dut.dbg_window_errors || !dut.dbg_sequence_errors || locked)
                $fatal(1, "Stuck FRAME was not distinguished from illegal FRAME");
            release dut.frame_pair;
            $display("PASS: pre-FIFO monitor detects stuck FRAME without ARM or functional lock");
            // A permanently unpairable FRAME must still produce an atomic
            // diagnostic record, although the functional decoder never locks.
            @(negedge axis_clk); resetn = 0; arm = 0; ready_mode = 0;
            force dut.frame_pair = 2'b01;
            #600;
            @(negedge axis_clk); resetn = 1;
            wait (dut.diag_snapshot_valid_ref);
            if (dut.diag_flags_ref[6] || dut.diag_frame_pair_ref != 2'b01 ||
                dut.diag_frame_history_ref != 16'h5555 ||
                dut.diag_rx_counter_ref != 24'd1048575 || locked || frame_error)
                $fatal(1, "Unlocked FRAME timeout snapshot is incorrect");
            release dut.frame_pair;
            $display("PASS: never-locked FRAME timeout captures coherent history in the 200 MHz domain");
        end
        if (trace_received < 128)
            $fatal(1, "Insufficient frozen-bank debug CDC records");
        $display("PASS: %0d coherent pre-FIFO records transferred to 200 MHz, ordered 64-cycle banks", trace_received);
        $display("RFMC6000_IQ_AXIS_TEST_PASS I_FALLING=%0d PACKET_WORDS=%0d SKEW_TAPS=%0d FALL_DELAY=%0d", I_FALLING, PACKET_WORDS, SKEW_TAPS, FALL_DELAY);
        $finish;
    end
    initial begin #12000000; $fatal(1, "Test timed out"); end
endmodule
