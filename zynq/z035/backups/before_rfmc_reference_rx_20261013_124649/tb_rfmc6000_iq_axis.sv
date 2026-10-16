`timescale 1ns / 1ps

// Uses actual Xilinx UNISIM IO primitives and XPM async FIFO, no FIFO mocks.
module tb_rfmc6000_iq_axis;
    parameter integer I_FALLING = 1;
    parameter integer PACKET_WORDS = 7;
    localparam integer NORMAL_TARGET = (PACKET_WORDS > 100) ?
                                       PACKET_WORDS * 2 + 3 : 200;
    reg rx_clk = 0, ref_clk = 0, axis_clk = 0;
    reg rx_clock_running = 1;
    always #2.0345 if (rx_clock_running) rx_clk = ~rx_clk; // 245.76 MHz
    always #2.5 ref_clk = ~ref_clk;
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
                       .I_ON_FALLING_EDGE(I_FALLING)) dut (
        .rx_clk_p(rx_clk), .rx_clk_n(~rx_clk),
        .rx_frame_p(frame), .rx_frame_n(~frame),
        .rx_data_p(data), .rx_data_n(~data), .ref_clk200(ref_clk),
        .aresetn(resetn), .m_axis_aclk(axis_clk), .capture_arm(arm),
        .rx_ready(ready_status), .frame_locked(locked), .capture_active(active),
        .overflow(overflow), .frame_error(frame_error), .delay_error(delay_error),
        .m_axis_tdata(axis_data), .m_axis_tkeep(keep), .m_axis_tvalid(valid),
        .m_axis_tlast(last), .m_axis_tready(ready));

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
        @(posedge rx_clk);
        #0.2; data = I_FALLING ? i : q; frame = f;
        @(negedge rx_clk);
        #0.2; data = I_FALLING ? q : i; frame = bad_frame ? !f : f;
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
        // Arm is latched; lowering it is deliberately not a mid-packet abort.
        arm = 0;
        wait (received >= NORMAL_TARGET + 30);
        $display("PASS: full-rate DDR IQ, signs, frame alignment, unrelated clocks, random backpressure, TLAST");

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
        $display("PASS: corrupt FRAME stops capture without emitting an incomplete IQ tuple");

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
        force dut.delay_ready_ref = 1'b0;
        wait (delay_error);
        repeat (8) @(negedge axis_clk);
        release dut.delay_ready_ref;
        if (overflow || active || ready_status)
            $fatal(1, "IDELAY lock-loss status incorrect");
        drain_and_check_stop();
        if (!delay_error) $fatal(1, "Delay error did not stay latched");
        $display("PASS: IDELAY lock loss invalidates capture and preserves buffered beats");
        $display("RFMC6000_IQ_AXIS_TEST_PASS I_FALLING=%0d PACKET_WORDS=%0d", I_FALLING, PACKET_WORDS);
        $finish;
    end
    initial begin #1000000; $fatal(1, "Test timed out"); end
endmodule
