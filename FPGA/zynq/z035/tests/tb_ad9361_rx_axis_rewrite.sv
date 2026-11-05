`timescale 1ns/1ps

// Independent pin-level test for config915: 2R2T, LVDS DDR, Fs=15.36 MSPS.
// The source models UG-570 bus order, 4.5 ns clock-to-data delay, and the
// board's six inverted data pairs (SPI 0x03d/0x03e=0). No DUT internals are
// forced or used as the expected-data oracle. Real UNISIM/XPM models are used.
module tb_ad9361_rx_axis_rewrite;
    parameter integer PACKET_SAMPLES = 17;
    parameter integer RX_CLOCK_INVERT = 0;
    localparam integer FIFO_DEPTH = 64;
    localparam integer MAX_SAMPLES = 32768;
    reg source_clk = 0;
    reg source_clock_enable = 1;
    reg m_axis_aclk = 0;
    reg ref_clk200 = 0;
    always #8.138 if (source_clock_enable) source_clk = ~source_clk;
    initial begin #1.3; forever #5 m_axis_aclk = ~m_axis_aclk; end
    initial begin #0.7; forever #2.5 ref_clk200 = ~ref_clk200; end
    wire rx_clk_p = source_clk ^ RX_CLOCK_INVERT;
    wire rx_clk_n = ~rx_clk_p;
    reg rx_frame_p = 0;
    wire rx_frame_n = ~rx_frame_p;
    reg [5:0] rx_data_p = 6'h3f;
    wire [5:0] rx_data_n = ~rx_data_p;
    reg aresetn = 0;
    reg capture_arm = 0;
    wire rx_ready, frame_locked, capture_active, overflow, frame_error, delay_error;
    wire [63:0] m_axis_tdata;
    wire [7:0] m_axis_tkeep;
    wire m_axis_tlast, m_axis_tvalid;
    reg m_axis_tready = 1;
    reg s_axi_awvalid = 0;
    reg [15:0] s_axi_awaddr = 0;
    reg [2:0] s_axi_awprot = 0;
    wire s_axi_awready;
    reg s_axi_wvalid = 0;
    reg [31:0] s_axi_wdata = 0;
    reg [3:0] s_axi_wstrb = 0;
    wire s_axi_wready, s_axi_bvalid;
    wire [1:0] s_axi_bresp;
    reg s_axi_bready = 0;
    reg s_axi_arvalid = 0;
    reg [15:0] s_axi_araddr = 0;
    reg [2:0] s_axi_arprot = 0;
    wire s_axi_arready, s_axi_rvalid;
    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    reg s_axi_rready = 0;

    ad9361_rx_axis #(.FIFO_DEPTH(FIFO_DEPTH), .PACKET_SAMPLES(PACKET_SAMPLES)) dut (.*);

    // Observe only the newly implemented FIFO boundary, never force it. The
    // 2020.2 XPM S-5 assertion incorrectly demands a synchronized asynchronous
    // pointer in one cycle; these checks enforce the actual interface contract.
    always @(posedge dut.rx_clk) begin
        if (dut.fifo_write === 1'b1 &&
            (dut.fifo_reset !== 1'b0 || dut.fifo_write_busy !== 1'b0 || dut.fifo_full !== 1'b0))
            $fatal(1, "FIFO write during reset/busy/full");
    end
    always @(posedge m_axis_aclk) begin
        if (dut.fifo_read === 1'b1 &&
            (dut.axis_running !== 1'b1 || dut.fifo_read_busy !== 1'b0 || dut.fifo_empty !== 1'b0))
            $fatal(1, "FIFO read during reset/busy/empty");
    end

    reg [63:0] expected [0:MAX_SAMPLES-1];
    reg expected_good [0:MAX_SAMPLES-1];
    integer completed_samples = 0;
    integer source_id = 0;
    integer phase = 0;
    reg malformed_request = 0;
    reg pn_mode = 0;
    reg pn_corrupt_request = 0;
    reg halfword_slip_request = 0;
    integer halfword_slips = 0;
    reg group_bad, group_corrupt;
    reg [11:0] sample_i1, sample_q1, sample_i2, sample_q2;
    reg [5:0] bus_word;
    reg frame_word;
    reg [15:0] pn_r1 = 16'hace1, pn_r2 = 16'hb7e3;

    function automatic [15:0] sx12(input [11:0] value);
        sx12 = {{4{value[11]}}, value};
    endfunction
    function automatic [11:0] reverse12(input [11:0] value);
        integer bit_index;
        for (bit_index=0; bit_index<12; bit_index=bit_index+1)
            reverse12[bit_index] = value[11-bit_index];
    endfunction
    // AD9361 BIST sequence: one 16-bit state advance per IQ pair. This
    // serial recurrence is independent of the receiver's parallel datapath.
    function automatic [15:0] device_pn_next(input [15:0] state);
        reg feedback;
        integer bit_index;
        begin
            feedback = state[1] ^ state[2];
            for (bit_index=4; bit_index<16; bit_index=bit_index+1)
                feedback = feedback ^ state[bit_index];
            device_pn_next = {state[14:0], feedback};
        end
    endfunction

    initial begin : wire_source
        @(posedge source_clk);
        forever begin
            // Repeat one low-FRAME halfword between tuples. The following
            // group moves to the opposite DDR parity without swapping IQ.
            if (halfword_slip_request) begin
                #4.5;
                rx_data_p = ~6'h15;
                rx_frame_p = 0;
                @(source_clk);
                halfword_slip_request = 0;
                halfword_slips = halfword_slips + 1;
            end
            if (source_id == MAX_SAMPLES) $fatal(1, "source history exhausted");
            group_bad = malformed_request;
            group_corrupt = pn_corrupt_request;
            if (pn_mode) begin
                sample_i1 = pn_r1[15:4];
                sample_q1 = reverse12(pn_r1[11:0]);
                sample_i2 = pn_r2[15:4];
                sample_q2 = reverse12(pn_r2[11:0]);
                pn_r1 = device_pn_next(pn_r1);
                pn_r2 = device_pn_next(pn_r2);
                if (group_corrupt) sample_i1 = sample_i1 ^ 12'h001;
            end else begin
                sample_i1 = source_id;
                sample_i2 = source_id ^ 12'ha53;
                sample_q2 = (source_id * 13) + 12'h831;
                case (source_id % 8)
                    0: sample_q1 = 12'h000;
                    1: sample_q1 = 12'h7ff;
                    2: sample_q1 = 12'h800;
                    3: sample_q1 = 12'hfff;
                    default: sample_q1 = (source_id * 7) ^ 12'h5a6;
                endcase
            end
            expected[source_id] = {sx12(sample_q2), sx12(sample_i2),
                                   sx12(sample_q1), sx12(sample_i1)};
            expected_good[source_id] = !group_bad;
            for (phase=0; phase<8; phase=phase+1) begin
                case (phase)
                    0: bus_word = sample_i1[11:6];
                    1: bus_word = sample_q1[11:6];
                    2: bus_word = sample_i1[5:0];
                    3: bus_word = sample_q1[5:0];
                    4: bus_word = sample_i2[11:6];
                    5: bus_word = sample_q2[11:6];
                    6: bus_word = sample_i2[5:0];
                    7: bus_word = sample_q2[5:0];
                endcase
                frame_word = (phase < 4);
                // Deliberately invalid 11010000: the two I1/Q1 low halves
                // no longer share a frame level. No partial tuple is valid.
                if (group_bad && phase == 2) frame_word = 0;
                #4.5;
                rx_data_p = ~bus_word;
                rx_frame_p = frame_word;
                if (phase == 7) completed_samples = source_id + 1;
                @(source_clk);
            end
            source_id = source_id + 1;
        end
    end

    // Independent observation oracle: sample the external pins in physical
    // rising/falling order. Neither decoded data nor the DUT's IDDR outputs
    // are used as expected values. The source delay and tested taps keep the
    // pin values stable at both sample edges throughout this functional test.
    localparam integer MAX_PIN_PAIRS = MAX_SAMPLES*4 + 2048;
    reg [13:0] pin_pairs [0:MAX_PIN_PAIRS-1];
    reg [6:0] pin_rising_sample = 0;
    integer pin_pair_count = 0;
    always @(posedge rx_clk_p)
        pin_rising_sample = {rx_frame_p, rx_data_p};
    always @(negedge rx_clk_p) begin
        if (pin_pair_count == MAX_PIN_PAIRS) $fatal(1, "pin observation history exhausted");
        pin_pairs[pin_pair_count] = {pin_rising_sample, rx_frame_p, rx_data_p};
        pin_pair_count = pin_pair_count + 1;
    end

    reg [13:0] raw_alignment [0:7];
    reg [21:0] previous_raw_tag = 0;
    reg [21:0] current_raw_tag;
    reg [7:0] previous_raw_frames = 0;
    reg previous_raw_locked = 0;
    reg raw_tag_seen = 0;
    integer raw_alignment_count = 0;
    integer raw_expected_pair = -1;
    integer raw_history_count = 0;
    integer raw_records = 0;
    integer raw_payload_checks = 0;
    integer raw_history_checks = 0;
    integer raw_tag_wraps = 0;
    integer raw_candidates, raw_match, raw_search, raw_offset, raw_equal;
    always @(posedge m_axis_aclk) begin : observation_scoreboard
        if (!aresetn) begin
            raw_tag_seen = 0;
            raw_alignment_count = 0;
            raw_expected_pair = -1;
            raw_history_count = 0;
            previous_raw_frames = 0;
            previous_raw_locked = 0;
        end else if (dut.debug_raw_rx[48] === 1'b1) begin
            if ((^dut.debug_raw_rx[47:0]) === 1'bx)
                $fatal(1, "raw observation marked valid with unknown payload");
            // ABI deliberately splits the 22-bit cycle tag around flags.
            current_raw_tag = {dut.debug_raw_rx[31:26], dut.debug_raw_rx[47:32]};
            if (raw_tag_seen && current_raw_tag !== ((previous_raw_tag + 1'b1) & 22'h3fffff))
                $fatal(1, "raw observation sequence gap/reorder: %h -> %h", previous_raw_tag, current_raw_tag);
            if (raw_tag_seen && current_raw_tag[15:0] < previous_raw_tag[15:0])
                raw_tag_wraps = raw_tag_wraps + 1;
            raw_tag_seen = 1;
            previous_raw_tag = current_raw_tag;
            raw_records = raw_records + 1;

            if (dut.debug_raw_rx[25]) begin
                if (raw_expected_pair >= 0) begin
                    if (raw_expected_pair >= pin_pair_count ||
                        dut.debug_raw_rx[13:0] !== pin_pairs[raw_expected_pair])
                        $fatal(1, "raw pin payload mismatch at tag=%h pair=%0d got=%h expected=%h",
                               current_raw_tag, raw_expected_pair, dut.debug_raw_rx[13:0], pin_pairs[raw_expected_pair]);
                    raw_expected_pair = raw_expected_pair + 1;
                    raw_payload_checks = raw_payload_checks + 1;
                end else begin
                    for (raw_offset=0; raw_offset<7; raw_offset=raw_offset+1)
                        raw_alignment[raw_offset] = raw_alignment[raw_offset+1];
                    raw_alignment[7] = dut.debug_raw_rx[13:0];
                    if (raw_alignment_count < 8) raw_alignment_count = raw_alignment_count + 1;
                    if (raw_alignment_count == 8) begin
                        // Correlate only startup transport latency. Eight
                        // pairs span two independently numbered IQ tuples.
                        raw_candidates = 0;
                        raw_match = -1;
                        for (raw_search=(pin_pair_count>128 ? pin_pair_count-128 : 0);
                             raw_search+7<pin_pair_count; raw_search=raw_search+1) begin
                            raw_equal = 1;
                            for (raw_offset=0; raw_offset<8; raw_offset=raw_offset+1)
                                if (raw_alignment[raw_offset] !== pin_pairs[raw_search+raw_offset]) raw_equal = 0;
                            if (raw_equal) begin
                                raw_candidates = raw_candidates + 1;
                                raw_match = raw_search;
                            end
                        end
                        if (raw_candidates == 1) raw_expected_pair = raw_match + 8;
                    end
                end
            end
            if (raw_history_count >= 4 && previous_raw_locked && dut.debug_raw_rx[22]) begin
                if (dut.debug_raw_rx[21:14] !== previous_raw_frames)
                    $fatal(1, "raw FRAME history mismatch at tag=%h got=%h expected=%h",
                           current_raw_tag, dut.debug_raw_rx[21:14], previous_raw_frames);
                raw_history_checks = raw_history_checks + 1;
            end
            previous_raw_frames = {previous_raw_frames[5:0], dut.debug_raw_rx[13], dut.debug_raw_rx[6]};
            previous_raw_locked = dut.debug_raw_rx[22];
            if (raw_history_count < 4) raw_history_count = raw_history_count + 1;
        end
    end

    integer epoch_floor = 0;
    integer last_seen = -1;
    integer received = 0;
    integer all_received = 0;
    integer packet_index = 0;
    integer total_packets = 0;
    integer match_found, matched_id, scan;
    reg allow_gaps = 0;
    reg previous_stall = 0;
    reg [63:0] held_data;
    reg held_last;
    integer stalled_cycles = 0;
    always @(posedge m_axis_aclk) begin : independent_scoreboard
        if (!aresetn) begin
            last_seen = -1;
            received = 0;
            packet_index = 0;
            previous_stall = 0;
        end else begin
            if (previous_stall && (!m_axis_tvalid || m_axis_tdata !== held_data ||
                                   m_axis_tlast !== held_last || m_axis_tkeep !== 8'hff))
                $fatal(1, "AXIS payload changed while stalled at %t", $time);
            previous_stall = m_axis_tvalid && !m_axis_tready;
            held_data = m_axis_tdata;
            held_last = m_axis_tlast;
            if (previous_stall) stalled_cycles = stalled_cycles + 1;
            if (m_axis_tvalid && m_axis_tready) begin
                if (!capture_active) $fatal(1, "AXIS transfer before capture_active");
                if (m_axis_tkeep !== 8'hff) $fatal(1, "incorrect TKEEP");
                if (m_axis_tlast !== (packet_index == PACKET_SAMPLES-1))
                    $fatal(1, "TLAST mismatch at beat %0d packet position %0d", received, packet_index);
                match_found = 0;
                matched_id = -1;
                for (scan=(last_seen<0 ? epoch_floor : last_seen+1);
                     scan<completed_samples; scan=scan+1) begin
                    if (expected[scan] === m_axis_tdata && match_found == 0) begin
                        match_found = 1;
                        matched_id = scan;
                    end
                end
                if (!match_found)
                    $fatal(1, "tuple mismatch/reorder: got %016h after source %0d, launched=%0d at %t",
                           m_axis_tdata, last_seen, completed_samples, $time);
                if (!expected_good[matched_id])
                    $fatal(1, "malformed FRAME emitted source tuple %0d", matched_id);
                if (!allow_gaps && last_seen >= 0 && matched_id != last_seen+1)
                    $fatal(1, "unexpected source gap %0d -> %0d", last_seen, matched_id);
                last_seen = matched_id;
                received = received + 1;
                all_received = all_received + 1;
                if (packet_index == PACKET_SAMPLES-1) begin
                    packet_index = 0;
                    total_packets = total_packets + 1;
                end else packet_index = packet_index + 1;
            end
        end
    end

    task automatic axi_write(input [15:0] address, input [31:0] data,
                             input [3:0] strobes, input integer aw_delay,
                             input integer w_delay);
        integer hold_cycle;
        begin
            @(negedge m_axis_aclk);
            s_axi_bready = 0;
            fork
                begin
                    repeat (aw_delay) @(negedge m_axis_aclk);
                    s_axi_awaddr = address;
                    s_axi_awvalid = 1;
                    do @(posedge m_axis_aclk); while (!s_axi_awready);
                    @(negedge m_axis_aclk);
                    s_axi_awvalid = 0;
                end
                begin
                    repeat (w_delay) @(negedge m_axis_aclk);
                    s_axi_wdata = data;
                    s_axi_wstrb = strobes;
                    s_axi_wvalid = 1;
                    do @(posedge m_axis_aclk); while (!s_axi_wready);
                    @(negedge m_axis_aclk);
                    s_axi_wvalid = 0;
                end
            join
            while (!s_axi_bvalid) @(negedge m_axis_aclk);
            for (hold_cycle=0; hold_cycle<5; hold_cycle=hold_cycle+1) begin
                @(negedge m_axis_aclk);
                if (!s_axi_bvalid || s_axi_bresp !== 0)
                    $fatal(1, "write response failed/stall changed at %h", address);
            end
            s_axi_bready = 1;
            @(negedge m_axis_aclk);
            s_axi_bready = 0;
            repeat (2) @(negedge m_axis_aclk);
        end
    endtask

    task automatic axi_read(input [15:0] address, output [31:0] data);
        integer hold_cycle;
        begin
            @(negedge m_axis_aclk);
            s_axi_araddr = address;
            s_axi_arvalid = 1;
            s_axi_rready = 0;
            do @(posedge m_axis_aclk); while (!s_axi_arready);
            @(negedge m_axis_aclk);
            s_axi_arvalid = 0;
            while (!s_axi_rvalid) @(negedge m_axis_aclk);
            data = s_axi_rdata;
            for (hold_cycle=0; hold_cycle<5; hold_cycle=hold_cycle+1) begin
                @(negedge m_axis_aclk);
                if (!s_axi_rvalid || s_axi_rdata !== data || s_axi_rresp !== 0)
                    $fatal(1, "read response failed/stall changed at %h", address);
            end
            s_axi_rready = 1;
            @(negedge m_axis_aclk);
            s_axi_rready = 0;
            repeat (2) @(negedge m_axis_aclk);
        end
    endtask

    task automatic configure_rx;
        integer channel;
        begin
            axi_write(16'h0040, 32'h00000003, 4'hf, 0, 3);
            axi_write(16'h0044, 32'h00000000, 4'hf, 4, 0);
            for (channel=0; channel<4; channel=channel+1) begin
                axi_write(16'h0400+channel*16'h0040, 32'h1, 4'hf, 0, 2);
                axi_write(16'h0418+channel*16'h0040, 32'h0, 4'hf, 3, 0);
            end
        end
    endtask

    task automatic reset_rx;
        begin
            @(negedge m_axis_aclk);
            aresetn = 0;
            capture_arm = 0;
            m_axis_tready = 1;
            malformed_request = 0;
            allow_gaps = 0;
            repeat (100) @(negedge m_axis_aclk);
            epoch_floor = completed_samples;
            aresetn = 1;
            configure_rx();
        end
    endtask

    task automatic await_ready;
        integer timeout_cycles;
        begin
            timeout_cycles = 0;
            while ((!rx_ready || !frame_locked) && timeout_cycles<10000) begin
                @(negedge m_axis_aclk);
                timeout_cycles = timeout_cycles + 1;
            end
            if (!rx_ready || !frame_locked) $fatal(1, "RX failed to become ready/locked");
        end
    endtask

    task automatic receive_more(input integer count);
        integer target_count, timeout_cycles;
        begin
            target_count = received + count;
            timeout_cycles = 0;
            while (received<target_count && timeout_cycles<count*12+10000) begin
                @(negedge m_axis_aclk);
                timeout_cycles = timeout_cycles + 1;
            end
            if (received<target_count) $fatal(1, "AXIS stopped: received=%0d target=%0d", received, target_count);
        end
    endtask

    task automatic source_more(input integer count);
        integer target_count;
        begin
            target_count = completed_samples + count;
            while (completed_samples<target_count) @(negedge m_axis_aclk);
        end
    endtask

    task automatic arm_pulse;
        begin
            @(negedge m_axis_aclk);
            capture_arm = 1;
            repeat (12) @(negedge m_axis_aclk);
            capture_arm = 0;
        end
    endtask

    // Snapshot after pausing the source at a repeatable frame phase. Let the
    // read clock drain the observation FIFO and settle every CDC counter;
    // serial AXI reads then describe one instant, without read-skew tolerance.
    task automatic pause_source_for_snapshot;
        begin
            @(negedge rx_frame_p);
            @(negedge source_clk);
            source_clock_enable = 0;
            repeat (40) @(negedge m_axis_aclk);
        end
    endtask

    task automatic read_stable_diagnostics(output [31:0] samples,
                                           output [31:0] clocks,
                                           output [31:0] frame_rises,
                                           output [31:0] faults);
        reg [31:0] histogram_counts [0:3];
        reg [31:0] clock_check;
        integer bin;
        begin
            axi_read(16'h1000, samples);
            axi_read(16'h1004, clocks);
            axi_read(16'h100c, faults);
            axi_read(16'h1010, frame_rises);
            for (bin=0; bin<4; bin=bin+1) begin
                axi_read(16'h1020+bin*4, histogram_counts[bin]);
                if (histogram_counts[bin][31:24] !== 0) $fatal(1, "histogram %0d ABI width mismatch", bin);
            end
            axi_read(16'h1004, clock_check);
            if (clocks !== clock_check) $fatal(1, "diagnostic snapshot was not stable");
            if (((histogram_counts[0]+histogram_counts[1]+histogram_counts[2]+histogram_counts[3]) & 32'h00ffffff) !== clocks)
                $fatal(1, "FRAME histogram total does not equal RX clock count: %0d+%0d+%0d+%0d != %0d",
                       histogram_counts[0], histogram_counts[1], histogram_counts[2], histogram_counts[3], clocks);
            if (frame_rises[31:24] !== 0 || faults[31:24] !== 0)
                $fatal(1, "extended diagnostic counter ABI width mismatch");
        end
    endtask

    reg [31:0] readback;
    reg [31:0] samples_before, clocks_before, samples_after, clocks_after;
    reg [31:0] frame_rises_before, frame_rises_after, faults_before, faults_after;
    integer iteration, channel, before_fault;
    initial begin : test_scenarios
        $display("BEGIN rewrite pin-level test PACKET_SAMPLES=%0d CLOCK_INVERT=%0d", PACKET_SAMPLES, RX_CLOCK_INVERT);
        reset_rx();
        // ADI ABI compatibility deliberately retains full-word writes:
        // WSTRB is ignored by the unmodified upstream up_axi bridge.
        axi_write(16'h0008, 32'h12345678, 4'hf, 0, 7);
        axi_read(16'h0008, readback);
        if (readback !== 32'h12345678) $fatal(1, "AW-before-W write/read failed");
        axi_write(16'h0008, 32'ha5c33c5a, 4'h1, 6, 0);
        axi_read(16'h0008, readback);
        if (readback !== 32'ha5c33c5a) $fatal(1, "native WSTRB compatibility changed");
        axi_write(16'h0008, 32'h55aa9966, 4'h0, 0, 0);
        axi_read(16'h0008, readback);
        if (readback !== 32'h55aa9966) $fatal(1, "native zero-WSTRB compatibility changed");
        axi_read(16'h0040, readback);
        if (readback[1:0] !== 2'b11) $fatal(1, "reset register ABI mismatch");
        for (channel=0; channel<4; channel=channel+1) begin
            axi_read(16'h0400+channel*16'h0040, readback);
            if (readback !== 32'h1) $fatal(1, "channel %0d control ABI mismatch", channel);
        end
        await_ready();
        axi_read(16'h0000, readback);
        if (readback !== 32'h000a0300) $fatal(1, "ADI version register changed: %h", readback);
        axi_read(16'h1008, readback);
        if (readback !== 32'h41445258) $fatal(1, "project signature register changed: %h", readback);
        axi_read(16'h101c, readback);
        if (readback !== 32'h00010001) $fatal(1, "diagnostic capability ABI mismatch: %h", readback);
        pause_source_for_snapshot();
        read_stable_diagnostics(samples_before, clocks_before, frame_rises_before, faults_before);
        source_clock_enable = 1;
        source_more(100);
        pause_source_for_snapshot();
        read_stable_diagnostics(samples_after, clocks_after, frame_rises_after, faults_after);
        if (samples_after<=samples_before || clocks_after<=clocks_before ||
            samples_after[31:24] !== 0 || clocks_after[31:24] !== 0)
            $fatal(1, "diagnostic counter ABI/increment failure");
        if (clocks_after-clocks_before !== 4*(samples_after-samples_before))
            $fatal(1, "stable clock/sample counters do not match exact 2R2T 4:1 ratio");
        if (frame_rises_after-frame_rises_before !== samples_after-samples_before)
            $fatal(1, "stable FRAME rising/sample counters do not match exact 1:1 ratio");
        if (faults_after !== faults_before) $fatal(1, "healthy paused/resumed source raised frame fault counter");
        source_clock_enable = 1;
        $display("PASS diagnostic capability, exact FRAME/sample 1:1 and histogram/RX clock totals");
        // Exercise actual IDELAYE2 CNTVALUEOUT, rather than a register shadow.
        // Sequential lane tuning may disturb framing; this is intentionally
        // unarmed, as in the firmware calibration procedure.
        for (channel=0; channel<7; channel=channel+1) begin
            axi_write(16'h0800+channel*4, 32'd31, 4'hf, 0, 2);
            axi_read(16'h0800+channel*4, readback);
            if (readback !== 32'd31) $fatal(1, "IDELAY lane %0d maximum tap readback=%h", channel, readback);
        end
        source_more(20);
        await_ready();
        for (channel=0; channel<7; channel=channel+1) begin
            axi_write(16'h0800+channel*4, 32'd0, 4'hf, 2, 0);
            axi_read(16'h0800+channel*4, readback);
            if (readback !== 32'd0) $fatal(1, "IDELAY lane %0d minimum tap readback=%h", channel, readback);
        end
        source_more(20);
        await_ready();
        $display("PASS version/signature/counter ABI and all seven IDELAY min/max tap registers");
        repeat (200) @(negedge m_axis_aclk);
        if (m_axis_tvalid || received || capture_active) $fatal(1, "unarmed receiver produced data");
        axi_read(16'h100c, faults_before);
        malformed_request = 1;
        source_more(7);
        malformed_request = 0;
        source_more(12);
        await_ready();
        axi_read(16'h100c, faults_after);
        if (faults_after <= faults_before)
            $fatal(1, "unarmed malformed FRAME did not increment diagnostic fault counter");
        if (frame_error || delay_error || capture_active || m_axis_tvalid)
            $fatal(1, "unarmed tuning error poisoned later capture");
        $display("PASS unarmed malformed FRAME increments diagnostic faults without capture sticky errors");
        arm_pulse();
        receive_more(40);
        if (!capture_active) $fatal(1, "capture_arm falling edge stopped one-shot capture");
        for (iteration=0; iteration<1200; iteration=iteration+1) begin
            @(negedge m_axis_aclk);
            m_axis_tready = ((iteration % 7) != 0) && ((iteration % 11) != 0);
        end
        m_axis_tready = 0;
        repeat (100) @(negedge m_axis_aclk);
        m_axis_tready = 1;
        receive_more(60);
        // Exercise repeated real production TLAST wraps, including ordinary
        // source counter/sign-boundary wrap, without a shortened packet model.
        if (PACKET_SAMPLES >= 4096) receive_more(5*PACKET_SAMPLES);
        if (overflow || frame_error || delay_error) $fatal(1, "unexpected healthy-stream error");
        $display("PASS tuple order/sign extension, AXI-Lite, arm latch and AXIS backpressure");

        allow_gaps = 1;
        halfword_slip_request = 1;
        source_more(12);
        await_ready();
        receive_more(30);
        if (halfword_slips != 1 || !frame_error || !frame_locked)
            $fatal(1, "halfword parity slip did not flag/reacquire");
        allow_gaps = 0;
        receive_more(40);
        $display("PASS halfword parity slip detection and reacquisition");

        allow_gaps = 1;
        malformed_request = 1;
        source_more(7);
        malformed_request = 0;
        before_fault = completed_samples;
        source_more(12);
        await_ready();
        receive_more(30);
        if (!frame_error || !frame_locked || last_seen<before_fault)
            $fatal(1, "malformed frame did not flag/reacquire");
        allow_gaps = 0;
        receive_more(40);
        if (!frame_error) $fatal(1, "frame error was not sticky");
        $display("PASS malformed frame rejection and reacquisition");

        reset_rx();
        await_ready();
        repeat (100) @(negedge m_axis_aclk);
        if (overflow || frame_error || delay_error || capture_active || m_axis_tvalid)
            $fatal(1, "external reset did not clear capture/error state");
        arm_pulse();
        receive_more(20);
        allow_gaps = 1;
        m_axis_tready = 0;
        repeat (1200) @(negedge m_axis_aclk);
        if (!overflow) $fatal(1, "FIFO overflow was not reported");
        m_axis_tready = 1;
        receive_more(180);
        if (!overflow) $fatal(1, "FIFO overflow was not sticky");
        allow_gaps = 0;
        receive_more(40);
        $display("PASS reset/rearm, overflow and post-overflow tuple integrity");

        pn_mode = 1;
        reset_rx();
        await_ready();
        source_more(160);
        for (channel=0; channel<4; channel=channel+1)
            axi_write(16'h0404+channel*16'h0040, 32'h6, 4'hf, 0, 2);
        source_more(160);
        for (channel=0; channel<4; channel=channel+1) begin
            axi_read(16'h0404+channel*16'h0040, readback);
            if (readback[2:1] !== 2'b00)
                $fatal(1, "AD9361 device PN failed to lock channel %0d status=%h", channel, readback);
        end
        pn_corrupt_request = 1;
        source_more(2);
        pn_corrupt_request = 0;
        source_more(160);
        axi_read(16'h0404, readback);
        if (!readback[2]) $fatal(1, "PN bit corruption did not set sticky PN error");
        for (channel=0; channel<4; channel=channel+1)
            axi_write(16'h0404+channel*16'h0040, 32'h6, 4'hf, 2, 0);
        source_more(160);
        for (channel=0; channel<4; channel=channel+1) begin
            axi_read(16'h0404+channel*16'h0040, readback);
            if (readback[2:1] !== 0) $fatal(1, "PN W1C/recovery failed channel %0d status=%h", channel, readback);
        end
        if (stalled_cycles<100 || total_packets<5) $fatal(1, "insufficient protocol coverage");
        if (raw_records<500 || raw_payload_checks<500 || raw_history_checks<500)
            $fatal(1, "insufficient raw observation coverage: records=%0d payload=%0d history=%0d",
                   raw_records, raw_payload_checks, raw_history_checks);
        if (PACKET_SAMPLES >= 4096 && raw_tag_wraps == 0)
            $fatal(1, "production run did not exercise split raw cycle-tag rollover");
        $display("PASS raw observation valid/sequence, independent pin payload and FRAME history: records=%0d payload=%0d history=%0d tag_low16_wraps=%0d",
                 raw_records, raw_payload_checks, raw_history_checks, raw_tag_wraps);
        $display("PASS device PN acquisition, corruption detection and W1C");
        $display("PASS rewrite PACKET_SAMPLES=%0d CLOCK_INVERT=%0d beats=%0d packets=%0d stalls=%0d",
                 PACKET_SAMPLES, RX_CLOCK_INVERT, all_received, total_packets, stalled_cycles);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "global timeout");
    end
endmodule
