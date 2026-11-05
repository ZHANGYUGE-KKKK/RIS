`timescale 1ns / 1ps
module tb_rfmc_capture;
    reg clk = 0;
    always #5 clk = ~clk;
    reg resetn = 0;
    reg [31:0] ctrl = 0, n = 0;
    reg ready = 0;
    wire [31:0] status;
    wire [63:0] data;
    wire [7:0] keep;
    wire valid, last, in_ready;
    reg in_valid = 0;
    reg [63:0] in_data = 0;
    rfmc_capture_axis #(.BLOCK_WORDS(4)) dut (
        .aclk(clk), .aresetn(resetn), .control(ctrl), .sample_count(n),
        .mig_ready(1'b1), .rx_overflow(1'b0), .rx_frame_error(1'b0),
        .rx_delay_ready(1'b1), .status(status),
        .status_clk(clk), .status_resetn(resetn),
        .s_axis_tdata(in_data), .s_axis_tvalid(in_valid), .s_axis_tready(in_ready),
        .m_axis_tdata(data), .m_axis_tkeep(keep), .m_axis_tvalid(valid),
        .m_axis_tready(ready), .m_axis_tlast(last)
    );
    integer tick = 0, got = 0, tails = 0;
    reg [63:0] held;
    reg held_last, stalled = 0;
    reg check_ramp = 1;
    always @(negedge clk) begin
        tick = tick + 1;
        ready = (tick % 5 != 0) && (tick % 5 != 1);
    end
    always @(posedge clk) if (resetn) begin
        if (stalled && (!valid || data !== held || last !== held_last))
            $fatal(1, "AXIS changed while backpressured");
        stalled = valid && !ready;
        held = data; held_last = last;
        if (valid && ready && check_ramp) begin
            if (data !== {(32'h5a5a5a5a ^ got), 32'(got)})
                $fatal(1, "test data mismatch at beat %0d", got);
            if (keep !== 8'hff || last !== ((got == 3) || (got == 7) || (got == 9)))
                $fatal(1, "packet boundary mismatch at beat %0d", got);
            if (last) tails = tails + 1;
            got = got + 1;
        end
    end
    task settle;
        begin repeat (6) @(negedge clk); end
    endtask
    initial begin
        repeat (4) @(negedge clk); resetn = 1;
        ctrl = 2; n = 10; settle;
        ctrl = 3;
        wait(status[1]); settle;
        if (got != 10 || tails != 3 || status[0]) $fatal(1, "capture count error");
        check_ramp = 0;
        ctrl = 2; n = 0; settle; ctrl = 3; settle;
        if (!status[7] || status[0]) $fatal(1, "zero-length ARM was accepted");
        ctrl = 2; n = 134217729; settle; ctrl = 3; settle;
        if (!status[7] || status[0]) $fatal(1, "oversize ARM was accepted");
        // Exercise live RX selection, draining while idle, and a short final packet.
        ctrl = 0; n = 1; settle;
        if (!in_ready) $fatal(1, "idle RX FIFO is not draining");
        ctrl = 1; settle;
        @(negedge clk); in_valid = 1; in_data = 64'h123456789abcdef0;
        wait(valid && ready);
        if (data !== in_data || !last) $fatal(1, "live RX passthrough error");
        @(negedge clk); in_valid = 0;
        wait(status[1]); settle;
        $display("CAPTURE_AXIS_TEST_PASS");
        $finish;
    end
    initial begin #10000; $fatal(1, "timeout"); end
endmodule
