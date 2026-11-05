`timescale 1ns / 1ps

module tb_ris_595;
    parameter integer HALF = 5;
    localparam real PHASE_NS = HALF * 10.0;
    reg clk = 0;
    always #5 clk = !clk;
    reg resetn = 0;
    reg [31:0] command = 0;
    wire [31:0] status;
    wire [49:0] data;
    wire [9:0] shcp, stcp;
    wire mr_n, oe_n;
    ris_595_bringup #(.HALF_PERIOD_CYCLES(HALF)) dut (
        .clk(clk), .resetn(resetn), .command(command), .status(status),
        .ris_data(data), .ris_shcp(shcp), .ris_stcp(stcp),
        .ris_mr_n(mr_n), .ris_oe_n(oe_n)
    );

    // Model the actual board: 50 independent DS lanes, 10 shared clock pairs,
    // global MR/OE. MR clears ONLY the shift register, never the output latch.
    wire [7:0] stored [0:49];
    wire [7:0] q [0:49];
    genvar chip;
    generate for (chip = 0; chip < 50; chip = chip + 1) begin : device
        reg [7:0] shift_reg;
        reg [7:0] storage_reg;
        always @(posedge shcp[chip/5] or negedge mr_n) begin
            if (!mr_n) shift_reg <= 0;
            else shift_reg <= {shift_reg[6:0], data[chip]};
        end
        always @(posedge stcp[chip/5]) storage_reg <= shift_reg;
        assign stored[chip] = storage_reg;
        assign q[chip] = oe_n ? 8'bz : storage_reg;
    end endgenerate

    real ds_changed = 0, last_rise = 0, last_fall = 0;
    real latch_rise = 0, reset_fall = 0;
    integer shifts = 0;
    integer latches = 0;
    always @(data[0]) ds_changed = $realtime;
    always @(negedge mr_n) begin
        shifts = 0;
        reset_fall = $realtime;
    end
    always @(posedge mr_n) begin
        if (($realtime - reset_fall) < PHASE_NS - 0.01)
            $fatal(1, "MR pulse too short");
    end
    always @(posedge shcp[0]) begin
        if (!mr_n || stcp != 0) $fatal(1, "Invalid SHCP/MR/STCP overlap");
        if (($realtime - ds_changed) < PHASE_NS - 0.01)
            $fatal(1, "DS setup interval too short");
        if (shifts != 0 && ($realtime - last_fall) < PHASE_NS - 0.01)
            $fatal(1, "SHCP low pulse too short");
        shifts = shifts + 1;
        last_rise = $realtime;
    end
    always @(negedge shcp[0]) begin
        if (mr_n && resetn && !command[10]) begin
            if (($realtime - last_rise) < PHASE_NS - 0.01)
                $fatal(1, "SHCP high pulse too short");
            last_fall = $realtime;
        end
    end
    always @(posedge stcp[0]) begin
        if (!mr_n || shcp != 0 || shifts != 8)
            $fatal(1, "Latch without exactly eight shifts: %0d", shifts);
        if (($realtime - last_fall) < PHASE_NS - 0.01)
            $fatal(1, "SHCP-to-STCP guard too short");
        shifts = 0;
        latches = latches + 1;
        latch_rise = $realtime;
    end
    always @(negedge stcp[0]) begin
        if (mr_n && resetn && !command[10] &&
            ($realtime - latch_rise) < PHASE_NS - 0.01)
            $fatal(1, "STCP pulse too short");
    end
    always @(posedge clk) begin
        #1;
        if (shcp !== {10{shcp[0]}} || stcp !== {10{stcp[0]}})
            $fatal(1, "Clock groups disagree");
        if (data[49:1] !== 0) $fatal(1, "Unused DATA lanes must be zero");
        if ((!status[2] || !resetn || command[10]) && oe_n !== 1)
            $fatal(1, "OE enabled before valid initialization");
    end

    task automatic write_command(input reg [31:0] value);
        @(negedge clk); command = value;
        @(posedge clk); #1;
    endtask
    task automatic wait_ready;
        integer cycles;
        cycles = 0;
        while (!status[0] && cycles < 2000) begin
            @(negedge clk); cycles = cycles + 1;
        end
        if (!status[0]) $fatal(1, "Ready timeout");
    endtask
    task automatic submit(input reg [7:0] value);
        write_command(32'h200 | value);
        write_command(32'h300 | value);
        write_command(32'h200 | value);
    endtask
    task automatic expect_completed(input integer expected, input reg [7:0] value);
        integer cycles, j;
        cycles = 0;
        while (status[31:16] != expected && cycles < 2000) begin
            @(negedge clk); cycles = cycles + 1;
        end
        if (status[31:16] != expected) $fatal(1, "Completion timeout: %h", status);
        if (!status[0] || status[1] || !status[2] || !status[3])
            $fatal(1, "Unexpected completion status %h", status);
        if (status[15:8] !== value || q[0] !== value)
            $fatal(1, "Byte/bit order mismatch expected %h status %h Q %h", value, status, q[0]);
        for (j = 1; j < 50; j = j + 1)
            if (q[j] !== 0) $fatal(1, "Unused chip %0d not zero: %h", j, q[j]);
    endtask

    integer value, before_latches;
    initial begin
        // Request enable before first frame; output must remain high impedance.
        command = 32'h200;
        #1; resetn = 1;
        #1; resetn = 0;
        repeat (4) @(negedge clk);
        resetn = 1;
        wait_ready();
        if (oe_n !== 1 || q[0] !== 8'bz) $fatal(1, "Unsafe initial output");

        // Exhaust all byte values, including walking bits, alternating and all-1.
        for (value = 0; value < 256; value = value + 1) begin
            submit(value[7:0]);
            expect_completed(value + 1, value[7:0]);
        end
        if (latches != 256) $fatal(1, "Unexpected latch count");

        // Changes to DATA and a second START while busy must not corrupt frame.
        submit(8'ha5);
        write_command(32'h25a);
        write_command(32'h35a);
        write_command(32'h25a);
        expect_completed(257, 8'ha5);
        if (!status[4]) $fatal(1, "Rejected request was not reported");
        repeat (HALF * 25) @(negedge clk);
        if (status[31:16] != 257) $fatal(1, "Busy request was queued");

        // Holding START high triggers once; output enable changes do not relatch.
        write_command(32'h23c);
        write_command(32'h33c);
        expect_completed(258, 8'h3c);
        repeat (HALF * 25) @(negedge clk);
        if (status[31:16] != 258) $fatal(1, "Held START retriggered");
        write_command(32'h03c);
        if (oe_n !== 1 || q[0] !== 8'bz) $fatal(1, "OE disable failed");
        if (stored[0] !== 8'h3c) $fatal(1, "OE changed output storage");
        write_command(32'h23c);
        if (q[0] !== 8'h3c) $fatal(1, "OE re-enable failed");

        // Reset in the middle of a shift: no latch, OE off, old Q preserved.
        submit(8'h81);
        @(posedge shcp[0]);
        before_latches = latches;
        write_command(32'h600);
        if (oe_n !== 1 || mr_n !== 0 || shcp !== 0 || stcp !== 0)
            $fatal(1, "Soft reset did not abort shift safely");
        if (stored[0] !== 8'h3c || latches != before_latches)
            $fatal(1, "MR incorrectly cleared or latched Q");

        // START high through reset release must not synthesize a new request.
        write_command(32'h700);
        repeat (HALF * 2) @(negedge clk);
        write_command(32'h300);
        wait_ready();
        repeat (HALF * 25) @(negedge clk);
        if (status[31:16] != 0 || status[2] || status[4] || oe_n !== 1)
            $fatal(1, "Unexpected request/flags after soft reset");
        submit(8'h96);
        expect_completed(1, 8'h96);

        // Reset while latch is high: the physical storage already changed,
        // but the in-flight operation must not be counted as completed.
        submit(8'h69);
        @(posedge stcp[0]);
        write_command(32'h600);
        if (stored[0] !== 8'h69 || oe_n !== 1 || status[31:16] != 0)
            $fatal(1, "Reset during latch handled incorrectly");
        write_command(32'h200);
        wait_ready();
        submit(8'h00);
        expect_completed(1, 8'h00);

        // External reset must also immediately disable an initialized output.
        @(negedge clk); resetn = 0;
        #1;
        if (oe_n !== 1 || mr_n !== 0 || status[2]) $fatal(1, "External reset failed");
        repeat (HALF * 2) @(negedge clk);
        command = 32'h200;
        resetn = 1;
        wait_ready();
        submit(8'h42);
        expect_completed(1, 8'h42);
        $display("RIS_595_TEST_PASS HALF=%0d: exhaustive bytes, 50-chip model, timing, busy, OE, resets", HALF);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "Simulation watchdog expired");
    end
endmodule
