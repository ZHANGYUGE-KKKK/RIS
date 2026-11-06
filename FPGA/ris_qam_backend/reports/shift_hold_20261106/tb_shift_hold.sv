`timescale 1ns/1ps
// Diagnostic only: production RTL is compiled unchanged.
module tb_shift_hold;
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
    wire oe_n,busy_owned,clock_ready;
    ris_fast_io dut(.*,.normal_mr_n(normal_mr),.normal_oe_n(normal_oe));
    reg [7:0] sr[0:49],q[0:49];
    wire q0=q[0][0];
    integer pulses[0:9],latches=0,mode_id=0;
    real rise_at[0:9],fall_at[0:9],latch_at[0:9],previous_latch=0;
    reg checking=0,last_level=0;
    integer logfile;
    initial begin
        logfile=$fopen("edges.csv","w");
        $fdisplay(logfile,"path,event,time_ns,level,previous_interval_ns");
        $dumpfile("shift_hold.vcd");
        $dumpvars(0,clk,resetn,data,shift,latch,oe_n,q0,mode_id);
    end
    genvar c,g;
    generate for(c=0;c<50;c=c+1)begin: chips
        real data_changed=0;
        initial begin sr[c]=0;q[c]=0;end
        always @(data[c])data_changed=$realtime;
        always @(posedge shift[c/5] or negedge normal_mr)
            if(!normal_mr)sr[c]<=0;
            else sr[c]<={sr[c][6:0],data[c]};
        always @(posedge shift[c/5])
            if(checking && $realtime-data_changed<3.2)
                $fatal(1,"DS setup violation lane %0d",c);
        always @(posedge latch[c/5])begin
            q[c]<=sr[c];
            if(checking && sr[c]!==(!(latches%2) ? 8'hff:8'h00))
                $fatal(1,"Wrong serial contents lane %0d event %0d: %h",c,latches,sr[c]);
        end
        // Verify all 400 held output bits on every fast clock, including
        // quiet intervals and the stopped-high interval. No analog model.
        always @(posedge dut.fast_clk)begin
            #0.2;
            if(checking && q[c]!=={8{last_level}})
                $fatal(1,"Output changed during hold, lane %0d",c);
        end
    end
    for(g=0;g<10;g=g+1)begin: groups
        initial begin pulses[g]=0;rise_at[g]=0;fall_at[g]=0;latch_at[g]=0;end
        always @(posedge shift[g])begin
            pulses[g]++;
            if(checking && (latch[g] || oe_n || $realtime-fall_at[g]<4.98))
                $fatal(1,"SHCP low width/overlap/OE error group %0d",g);
            rise_at[g]=$realtime;
        end
        always @(negedge shift[g])begin
            if(checking && $realtime-rise_at[g]<4.98)
                $fatal(1,"SHCP high width error group %0d",g);
            fall_at[g]=$realtime;
        end
        always @(posedge latch[g])begin
            latch_at[g]=$realtime;
            if(checking && pulses[g]!=8)
                $fatal(1,"Extra/missing shifts group %0d got %0d",g,pulses[g]);
            pulses[g]=0;
        end
        always @(negedge latch[g])
            if(checking && $realtime-latch_at[g]<4.98)
                $fatal(1,"STCP high width error group %0d",g);
    end endgenerate
    // Delay bookkeeping until all fifty chips have sampled the same event.
    always @(posedge latch[0])begin
        if(checking)begin
            if(latches>0 &&
               ($realtime-previous_latch<((latches%2)?12500.0:37500.0)-0.05 ||
                $realtime-previous_latch>((latches%2)?12500.0:37500.0)+0.05))
                $fatal(1,"Unexpected latch / wrong interval %f ns",$realtime-previous_latch);
            $fdisplay(logfile,"%0d,%0d,%0.6f,%0d,%0.6f",mode_id,latches,$realtime,!(latches%2),latches?$realtime-previous_latch:0);
            previous_latch=$realtime;
            #0.01;last_level=!(latches%2);latches++;
        end
    end
    always @(oe_n or normal_mr or clock_ready)
        if(checking && (oe_n!==0 || normal_mr!==1 || clock_ready!==1))
            $fatal(1,"OE/MR/clock disturbed during hold");
    task write_reg(input [15:0] addr,input [31:0] value);
        @(negedge clk);wr_addr=addr;wr_data=value;wr_valid=1;
        #1;if(wr_resp!=0)$fatal(1,"Write rejected %h=%h",addr,value);
        @(negedge clk);wr_valid=0;
    endtask
    task mt_control(input integer cmd);
        write_reg('ha4,cmd);rd_addr='ha8;
        do begin repeat(2)@(negedge clk);end while(rd_data[4]);
    endtask
    task qam_control(input integer cmd);
        write_reg('h204,cmd);rd_addr='h214;
        do begin repeat(2)@(negedge clk);end while(rd_data[3]);
    endtask
    task segment(input integer idx,input integer level,input integer ticks);
        write_reg('hdc,idx);write_reg('he0,(level<<31)|ticks);
    endtask
    task check_stopped_high;
        integer before_latches;
        before_latches=latches;
        #50000;
        if(latches!=before_latches || shift!==0 || latch!==0 || !last_level)
            $fatal(1,"Stopped high not held / extra clocks");
        for(integer i=0;i<10;i++)if(pulses[i]!=0)$fatal(1,"Extra clocks in stopped hold");
        $display("PASS path=%0d: 20kHz/25%%, 400 outputs, 12.5us high/37.5us low, eight 100MHz shifts/edge, no extra latches, OE low, stopped-high hold 50us",mode_id);
        checking=0;
    endtask
    initial begin
        #40;resetn=1;normal_mr=1;wait(clock_ready);repeat(20)@(negedge clk);normal_oe=0;
        // Exact host MT compiler result for (25,0), 20kHz, looping.
        mode_id=1;
        write_reg('hd4,4);write_reg('hd8,2);write_reg('he4,15000);write_reg('he8,0);
        segment(0,1,3750);segment(1,0,11250);segment(2,1,3750);segment(3,0,11250);
        latches=0;checking=1;mt_control(11);wait(latches==9);mt_control(0);
        check_stopped_high();normal_data={50{1'b1}};mt_control(8);
        // Same waveform through both QAM timing paths; payload index 00.
        for(integer profile=0;profile<2;profile++)begin
            mode_id=profile+2;qam_control(16);
            if(profile==1)write_reg('h250,64);
            // 75-tick legacy slices give exact 3750/11250 tick intervals.
            write_reg('h208,profile==1 ? 1:75);
            write_reg('h210,profile==1 ? 15000:200);write_reg('h20c,1);
            for(integer f=0;f<2;f++)for(integer word=0;word<13;word++)
                write_reg('h240,f==1 ? 0:(word==12 ? 'hffff:'hffffffff));
            write_reg('h244,(profile==1 ? 3750:50)<<16);
            write_reg('h244,((profile==1 ? 11250:150)<<16)|1);
            for(integer s=0;s<256;s++)write_reg('h248,2<<16);
            write_reg('h24c,0);
            latches=0;last_level=1;checking=1;qam_control(2);wait(latches==9);qam_control(0);
            check_stopped_high();qam_control(8);
        end
        $fclose(logfile);$display("SHIFT_HOLD_DIAGNOSTIC_PASS");$finish;
    end
    initial begin #2000000;$fatal(1,"Diagnostic timeout");end
endmodule
