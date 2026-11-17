`timescale 1ns / 1ps
module tb_rfmc_rx_pack;
    reg clk = 0;
    always #5 clk = ~clk;
    reg resetn = 0, adc_valid = 0, ready = 0, adc_status = 1;
    reg [11:0] i1 = 12'hfff, q1 = 12'h800, i2 = 12'h7ff, q2 = 12'h001;
    wire [63:0] data;
    wire valid, overflow, frame_error;
    rfmc_rx_pack dut (.adc_clk(clk), .adc_resetn(resetn),
        .adc_valid(adc_valid), .adc_status(adc_status), .delay_ready(1'b1),
        .adc_i1(i1), .adc_q1(q1), .adc_i2(i2), .adc_q2(q2),
        .overflow(overflow), .frame_error(frame_error),
        .m_axis_tdata(data), .m_axis_tvalid(valid), .m_axis_tready(ready));
    initial begin
        repeat (3) @(negedge clk); resetn = 1; adc_valid = 1;
        @(negedge clk); adc_valid = 0;
        if (!valid || data !== 64'h000107ff_f800ffff) $fatal(1, "sign extension/order error");
        i1 = 12'h002; adc_valid = 1;
        @(negedge clk); adc_valid = 0;
        if (!overflow || data !== 64'h000107ff_f800ffff || !valid)
            $fatal(1, "stalled sample changed or overflow was hidden");
        ready = 1;
        @(negedge clk);
        if (valid) $fatal(1, "elastic slot did not drain");
        adc_status = 0;
        @(negedge clk);
        if (!frame_error) $fatal(1, "frame error was hidden");
        resetn = 0;
        @(negedge clk);
        if (overflow || frame_error || valid) $fatal(1, "reset failed");
        $display("RX_PACK_TEST_PASS");
        $finish;
    end
endmodule
