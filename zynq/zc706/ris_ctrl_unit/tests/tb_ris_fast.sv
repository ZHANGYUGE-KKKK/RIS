`timescale 1ns/1ps
module tb_ris_fast;
    reg clk=0, resetn=0, normal_mr=0, normal_oe=1;
    always #5 clk=~clk;
    reg [49:0] normal_data=0;
    reg [9:0] normal_shift=0, normal_latch=0;
    reg wr_valid=0;
    reg [15:0] wr_addr=0,rd_addr=0;
    reg [31:0] wr_data=0;
    reg [3:0] wr_strb=15;
    wire [1:0] wr_resp, rd_resp;
    wire [31:0] rd_data;
    wire [49:0] data;
    wire [9:0] shift,latch;
    wire oe_n,busy_owned;
    ris_fast_io dut(.*,.normal_mr_n(normal_mr),.normal_oe_n(normal_oe));
    reg [7:0] sr[0:49],q[0:49];
    integer pulses[0:9],updates[0:9];
    real last_shift[0:9],last_fall[0:9],last_latch[0:9],last_output[0:9];
    real expected_half_ns=0;
    bit checking=0;
    genvar c,g;
    generate for(c=0;c<50;c=c+1) begin: chips
        always @(posedge shift[c/5] or negedge normal_mr)
            if(!normal_mr) sr[c]<=0; else sr[c]<={sr[c][6:0],data[c]};
        always @(posedge latch[c/5]) begin
            q[c]<=sr[c];
            if(checking && sr[c]!==8'h00 && sr[c]!==8'hff) $fatal(1,"Non-uniform output lane %0d: %h",c,sr[c]);
            if(checking && updates[c/5]>2 && sr[c]!==~q[c]) $fatal(1,"Missing 0/1 alternation lane %0d",c);
        end
    end
    for(g=0;g<10;g=g+1) begin: timing
        initial begin pulses[g]=0;updates[g]=0;last_shift[g]=0;last_fall[g]=0;last_latch[g]=0;last_output[g]=0;end
        always @(negedge normal_mr) pulses[g]=0;
        always @(posedge shift[g]) begin
            pulses[g]++;
            if(checking && (latch[g] || oe_n)) $fatal(1,"Shift/latch overlap or high-Z");
            if(checking && last_fall[g]>0 && $realtime-last_fall[g]<4.99) $fatal(1,"SHCP LOW too short");
            last_shift[g]=$realtime;
        end
        always @(negedge shift[g]) begin
            if(checking && $realtime-last_shift[g]<4.99) $fatal(1,"SHCP HIGH too short");
            last_fall[g]=$realtime;
        end
        always @(posedge latch[g]) begin
            if(checking) begin
                if(pulses[g]!=8 || shift[g] || oe_n) $fatal(1,"Expected eight shifts, got %0d",pulses[g]);
                if($realtime-last_shift[g]<13.0) $fatal(1,"Insufficient final-shift to latch guard");
                if(updates[g]>1 && expected_half_ns>0 &&
                    ($realtime-last_latch[g]<expected_half_ns-0.1 || $realtime-last_latch[g]>expected_half_ns+0.1))
                    $fatal(1,"Wrong half-period expected=%0f actual=%0f",expected_half_ns,$realtime-last_latch[g]);
            end
            pulses[g]=0;updates[g]++;last_latch[g]=$realtime;
        end
    end endgenerate
    always @(posedge oe_n) if(checking) $fatal(1,"OE used as zero/high-Z during playback");
    task write_control(input integer mode);
        @(negedge clk);wr_addr='ha4;wr_data=mode;wr_valid=1;
        #1;if(wr_resp!=0)$fatal(1,"Control rejected %0d",mode);
        @(negedge clk);wr_valid=0;rd_addr='ha8;
        do begin repeat(2)@(negedge clk);end while(rd_data[4]);
    endtask
    task exercise(input integer mhz, input integer ticks);
        integer prior_updates;
        checking=0;normal_data=0;normal_shift=0;normal_latch=0;
        for(integer i=0;i<10;i++)begin pulses[i]=0;updates[i]=0;end
        expected_half_ns=10.0*ticks/3;checking=1;
        if(mhz==9)begin
            @(negedge clk);wr_addr='hc0;wr_data=ticks;wr_valid=1;
            #1;if(wr_resp!=0)$fatal(1,"Custom divider rejected");
            @(negedge clk);wr_valid=0;
        end
        write_control(mhz);
        wait(updates[0]>=8);
        write_control(0);
        if(dut.running_sync[1] || !dut.owned_sync[1])$fatal(1,"STOP did not retain pins");
        prior_updates=updates[0];repeat(25)@(negedge clk);
        if(updates[0]!=prior_updates)$fatal(1,"STOP continued latching");
        // Align normal outputs to the held final level before release.
        normal_data={50{dut.level_sync[1]}};
        write_control(8);repeat(10)@(negedge clk);
        if(dut.owned_sync[1] || updates[0]!=prior_updates)$fatal(1,"Release created a latch edge");
        checking=0;
        $display("PASS: mode %0d full cycle; 400 outputs, eight shifts, 5ns SHCP, exact half-period, STOP/hold/release, no high-Z",mhz);
    endtask
    task normal_transfer(input integer tag);
        checking=0;
        for(integer bit_index=7;bit_index>=0;bit_index--)begin
            @(negedge clk);
            for(integer lane=0;lane<50;lane++)normal_data[lane]=((tag^(lane*7))>>bit_index)&1;
            @(negedge clk);normal_shift='h3ff;
            @(negedge clk);normal_shift=0;
        end
        repeat(2)@(negedge clk);normal_latch='h3ff;
        repeat(2)@(negedge clk);normal_latch=0;
        repeat(2)@(negedge clk);
        for(integer lane=0;lane<50;lane++)
            if(q[lane]!==((tag^(lane*7))&255))$fatal(1,"Normal transfer corrupted lane %0d",lane);
        $display("PASS: normal 50-lane arbitrary frame through shared ODDR outputs");
    endtask
    initial begin
        #40;resetn=1;normal_mr=1;
        wait(dut.locked_sync[1]);repeat(10)@(negedge clk);
        normal_oe=0;
        normal_transfer('ha5);
        exercise(1,150);exercise(3,50);exercise(5,30);
        exercise(9,63);exercise(9,3000);
        // Minimum/maximum divider and partial writes are checked at the bus.
        @(negedge clk);wr_addr='hc0;wr_data=29;wr_valid=1;#1;
        if(wr_resp!=2)$fatal(1,"Too-fast custom divider accepted");
        @(negedge clk);wr_data=150000001;#1;
        if(wr_resp!=2)$fatal(1,"Out-of-range slow divider accepted");
        @(negedge clk);wr_data=30;wr_strb=3;#1;
        if(wr_resp!=2)$fatal(1,"Partial divider write accepted");
        @(negedge clk);wr_data=150000000;wr_strb=15;#1;
        if(wr_resp!=0)$fatal(1,"1 Hz divider rejected");
        @(negedge clk);wr_valid=0;
        expected_half_ns=500000000.0;
        write_control(9);
        wait(dut.u_engine.phase==30);
        // STOP during a long quiet interval must acknowledge promptly.
        write_control(0);
        if(dut.running_sync[1])$fatal(1,"Low frequency STOP did not finish");
        write_control(8);
        normal_transfer('h5a);
        // Unsupported presets and partial writes cannot mutate ownership.
        @(negedge clk);wr_addr='ha4;wr_data=2;wr_valid=1;#1;
        if(wr_resp!=2)$fatal(1,"Unsupported frequency accepted");
        @(negedge clk);wr_valid=0;
        write_control(5);repeat(100)@(negedge clk);
        resetn=0;normal_mr=0;#30;
        if(!oe_n || |shift || |latch)$fatal(1,"Reset did not disable/clear outputs");
        $display("RIS_FAST_TEST_PASS");$finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule
