`timescale 1ns/1ps
module tb_ris_mt;
    reg clk=0,resetn=0,normal_mr=0,normal_oe=1;
    always #5 clk=~clk;
    reg [49:0] normal_data=0;
    reg [9:0] normal_shift=0,normal_latch=0;
    reg wr_valid=0;
    reg [15:0] wr_addr=0,rd_addr=0;
    reg [31:0] wr_data=0;
    reg [3:0] wr_strb=15;
    wire [1:0] wr_resp,rd_resp;
    wire [31:0] rd_data;
    wire [49:0] data;
    wire [9:0] shift,latch;
    wire oe_n,busy_owned;
    ris_fast_io dut(.*,.normal_mr_n(normal_mr),.normal_oe_n(normal_oe));
    reg [7:0] sr[0:49],q[0:49];
    integer pulses[0:9],latches=0, expected_index=0;
    integer expected_duration[0:15],expected_level[0:15];
    real previous_latch=0,first_latch=0,playback_setup_end=0;
    bit checking=0;
    always @(posedge dut.fast_clk)
        if(checking && dut.u_mt.setup==1) playback_setup_end=$realtime;
    genvar c,g;
    generate for(c=0;c<50;c=c+1) begin: chips
        always @(posedge shift[c/5] or negedge normal_mr)
            if(!normal_mr) sr[c]<=0; else sr[c]<={sr[c][6:0],data[c]};
        always @(posedge latch[c/5]) begin
            q[c]<=sr[c];
            if(checking && sr[c]!== (expected_level[expected_index] ? 8'hff : 8'h00))
                $fatal(1,"MT lane %0d wrong level at segment %0d: %h",c,expected_index,sr[c]);
        end
    end
    for(g=0;g<10;g=g+1)begin: groups
        initial pulses[g]=0;
        always @(posedge shift[g])begin
            pulses[g]++;
            if(checking && (latch[g] || oe_n))$fatal(1,"MT shift/latch overlap or OE disabled");
        end
        always @(posedge latch[g])begin
            if(checking && pulses[g]!=8)$fatal(1,"MT expected eight shifts, got %0d",pulses[g]);
            pulses[g]=0;
        end
    end endgenerate
    always @(posedge latch[0])begin
        if(checking)begin
            if(latches==0)begin
                first_latch=$realtime;
                // 29 fixed pipeline clocks define the local playback origin;
                // the file's initial T adds exactly that many further clocks.
                // UNISIM ODDR adds 100 ps C-to-Q; the behavioral substitute
                // adds none. Both are well below a single 3.333 ns tick.
                if(($realtime-playback_setup_end-(dut.mt_delay+29)*10.0/3)>0.12 ||
                   ($realtime-playback_setup_end-(dut.mt_delay+29)*10.0/3)<-0.02)
                    $fatal(1,"Initial MT delay: measured %f ns, expected %f ns plus ODDR propagation",
                        $realtime-playback_setup_end,(dut.mt_delay+29)*10.0/3);
            end
            else if(($realtime-previous_latch-expected_duration[expected_index-1]*10.0/3)>0.02 ||
                    ($realtime-previous_latch-expected_duration[expected_index-1]*10.0/3)<-0.02)
                $fatal(1,"MT interval wrong at %0d: got %f expected ticks %0d",expected_index,$realtime-previous_latch,expected_duration[expected_index-1]);
            previous_latch=$realtime;latches++;
        end
    end
    // Move expected index after every physical chip has sampled the latch.
    always @(negedge latch[0])if(checking)expected_index++;
    task write_reg(input [15:0] addr,input [31:0] value);
        @(negedge clk);wr_addr=addr;wr_data=value;wr_valid=1;
        #1;if(wr_resp!=0)$fatal(1,"MT write rejected: %h=%h",addr,value);
        @(negedge clk);wr_valid=0;
    endtask
    task control(input integer mode);
        write_reg('ha4,mode);rd_addr='ha8;
        do begin repeat(2)@(negedge clk);end while(rd_data[4]);
    endtask
    task segment(input integer index,input integer level,input integer ticks);
        write_reg('hdc,index);write_reg('he0,(level<<31)|ticks);
        rd_addr='he0;repeat(3)@(negedge clk);
        if(rd_data!==((level<<31)|ticks))$fatal(1,"RAM readback mismatch");
    endtask
    task release_pins;
        checking=0;control(0);normal_data={50{dut.level_sync[1]}};control(8);
    endtask
    integer prior;
    initial begin
        #40;resetn=1;normal_mr=1;wait(dut.locked_sync[1]);repeat(10)@(negedge clk);normal_oe=0;
        // User example at 1 MHz, one-shot: delay30, high150 low120 high90 low240.
        write_reg('hd4,4);write_reg('hd8,0);write_reg('he4,300);write_reg('he8,30);
        segment(0,1,150);segment(1,0,120);segment(2,1,90);segment(3,0,240);
        expected_level[0]=1;expected_level[1]=0;expected_level[2]=1;expected_level[3]=0;
        expected_duration[0]=150;expected_duration[1]=120;expected_duration[2]=90;expected_duration[3]=240;
        checking=1;control(10);wait(latches==4);wait(!dut.running_sync[1]);
        repeat(10)@(negedge clk);
        if(!dut.owned_sync[1] || dut.level_sync[1] || latches!=4)$fatal(1,"One-shot did not finish low/hold");
        release_pins();
        $display("PASS MT: user example, 50 physical shift-register models, exact segment intervals, one-shot low");
        // Exact compiler output for (50,80), once: 30% high, 50% low,
        // 20% high, then low at this cycle's end (no spill into the next).
        write_reg('hd4,4);write_reg('hd8,0);write_reg('he8,0);
        segment(0,1,90);segment(1,0,150);segment(2,1,60);segment(3,0,30);
        latches=0;expected_index=0;
        expected_duration[0]=90;expected_duration[1]=150;expected_duration[2]=60;expected_duration[3]=30;
        checking=1;control(10);wait(latches==4);wait(!dut.running_sync[1]);
        if(dut.level_sync[1])$fatal(1,"Wrapped one-shot did not end low");
        release_pins();
        $display("PASS MT: (50,80) wraps inside its own cycle, once ends at P");
        // [50,80; 0,0; 30,0]: the second period remains entirely low.
        write_reg('hd4,6);
        segment(0,1,90);segment(1,0,150);segment(2,1,60);
        segment(3,0,300);segment(4,1,90);segment(5,0,240);
        latches=0;expected_index=0;
        for(integer i=0;i<6;i++)expected_level[i]=!(i%2);
        expected_duration[0]=90;expected_duration[1]=150;expected_duration[2]=60;
        expected_duration[3]=300;expected_duration[4]=90;expected_duration[5]=240;
        checking=1;control(10);wait(latches==6);wait(!dut.running_sync[1]);release_pins();
        $display("PASS MT: wrapped pulse does not alter following zero-duty cycle");
        // Exact loop plan for (50,80). Adjacent high portions at the table
        // join merge, but the cycle waveform is identical from the first tour.
        write_reg('hd4,5);write_reg('hd8,3);
        segment(0,1,90);segment(1,0,150);segment(2,1,150);
        segment(3,0,150);segment(4,1,150);
        latches=0;expected_index=0;
        for(integer i=0;i<16;i++)begin expected_level[i]=!(i%2);expected_duration[i]=i==0 ? 90 : 150;end
        checking=1;control(11);wait(latches==8);release_pins();
        $display("PASS MT: (50,80) circular phase waveform repeats without boundary artifacts");
        // Minimum 100ns intervals, protected RAM, STOP during burst/quiet, release.
        write_reg('hd4,2);write_reg('hd8,0);write_reg('he8,0);
        segment(0,1,30);segment(1,0,30);
        latches=0;expected_index=0;
        for(integer i=0;i<16;i++)begin expected_level[i]=!(i%2);expected_duration[i]=30;end
        checking=1;control(11);
        @(negedge clk);wr_addr='he0;wr_data=30;wr_valid=1;#1;
        if(wr_resp!=2)$fatal(1,"Running table was mutable");
        @(negedge clk);wr_valid=0;
        wait(latches==8);release_pins();prior=latches;repeat(50)@(negedge clk);
        if(latches!=prior)$fatal(1,"STOP continued latching");
        write_reg('hd4,1);segment(0,0,300000000);write_reg('he8,300000000);
        control(11);control(0);if(dut.running_sync[1])$fatal(1,"STOP during initial delay failed");control(8);
        control(11);resetn=0;normal_mr=0;#30;
        if(!oe_n || |shift || |latch)$fatal(1,"MT reset did not disable outputs");
        $display("RIS_MT_TEST_PASS");$finish;
    end
    initial begin #1000000;$fatal(1,"MT timeout");end
endmodule
