`timescale 1ns/1ps
module tb_ris_qam;
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
    integer pulses[0:9];
    integer expected_frame[0:65535],expected_ticks[0:65535];
    reg [399:0] dictionary[0:2047];
    reg [31:0] file_frames[0:26623],file_events[0:32767],file_symbols[0:255];
    reg [7:0] file_payload[0:4095];
    integer latches=0, expected_index=0, expected_count=0;
    real previous_latch=0, shift_rise[0:9], shift_fall[0:9];
    bit checking=0,check_interval=1;
    real latch_start[0:9];
    genvar c,g;
    generate for(c=0;c<50;c=c+1) begin: chips
        real changed=0;
        always @(data[c]) changed=$realtime;
        always @(posedge shift[c/5] or negedge normal_mr)
            if(!normal_mr) sr[c]<=0; else sr[c]<={sr[c][6:0],data[c]};
        always @(posedge shift[c/5])if(checking && $realtime-changed<3.2)
            $fatal(1,"DS setup below one fast clock on lane %0d",c);
        always @(posedge latch[c/5]) begin
            q[c]<=sr[c];
            if(checking && (expected_index>=expected_count ||
               sr[c]!==dictionary[expected_frame[expected_index]][c*8+:8]))
                $fatal(1,"QAM lane %0d event %0d got %h expected frame %0d byte %h",
                    c,expected_index,sr[c],expected_frame[expected_index],
                    dictionary[expected_frame[expected_index]][c*8+:8]);
        end
    end
    for(g=0;g<10;g=g+1)begin: groups
        initial begin pulses[g]=0;shift_rise[g]=0;shift_fall[g]=0;end
        always @(posedge shift[g])begin
            pulses[g]++;
            if(checking)begin
                if(latch[g] || oe_n)$fatal(1,"shift/latch overlap or OE disabled");
                if($realtime-shift_fall[g]<4.98)$fatal(1,"SHCP low shorter than 5 ns");
            end
            shift_rise[g]=$realtime;
        end
        always @(negedge shift[g]) begin
            if(checking && $realtime-shift_rise[g]<4.98)$fatal(1,"SHCP high shorter than 5 ns");
            shift_fall[g]=$realtime;
        end
        always @(negedge latch[g])if(checking && $realtime-latch_start[g]<4.98)$fatal(1,"STCP high shorter than 5 ns");
        always @(posedge latch[g])begin
            latch_start[g]=$realtime;
            if(checking && pulses[g]!=8)$fatal(1,"expected 8 shifts, got %0d",pulses[g]);
            pulses[g]=0;
        end
    end endgenerate
    always @(posedge latch[0]) if(checking)begin
        if(check_interval && expected_index!=0 &&
           (($realtime-previous_latch-expected_ticks[expected_index-1]*10.0/3)>0.04 ||
            ($realtime-previous_latch-expected_ticks[expected_index-1]*10.0/3)<-0.04))
            $fatal(1,"event %0d duration got %f ns expected %0d ticks",expected_index,
                $realtime-previous_latch,expected_ticks[expected_index-1]);
        previous_latch=$realtime;latches++;
    end
    always @(negedge latch[0])if(checking)expected_index++;
    task write_reg(input [15:0] addr,input [31:0] value);
        @(negedge clk);wr_addr=addr;wr_data=value;wr_valid=1;
        #1;if(wr_resp!=0)$fatal(1,"write rejected %h=%h",addr,value);
        @(negedge clk);wr_valid=0;
    endtask
    task reject(input [15:0] addr,input [31:0] value);
        @(negedge clk);wr_addr=addr;wr_data=value;wr_valid=1;
        #1;if(wr_resp!=2)$fatal(1,"bad write accepted %h=%h",addr,value);
        @(negedge clk);wr_valid=0;
    endtask
    task wait_idle;
        integer timeout;
        rd_addr='h214;timeout=0;
        do begin @(negedge clk);timeout++;if(timeout>2000000)$fatal(1,"idle timeout");end
        while(rd_data[3:1]!=0);
        repeat(4)@(negedge clk);
    endtask
    task control(input integer cmd);
        write_reg('h204,cmd);rd_addr='h214;
        do begin repeat(2)@(negedge clk);end while(rd_data[3]);
    endtask
    task release_pins;
        checking=0;control(0);wait_idle();control(8);wait_idle();
    endtask
    task frame(input integer id);
        integer b;
        reg [415:0] padded;
        padded={16'b0,dictionary[id]};
        for(b=0;b<13;b++) begin
            if(b==12)reject('h240,padded[b*32+:32]|32'h10000);
            write_reg('h240,padded[b*32+:32]);
        end
    endtask
    task fixture(input integer bad);
        integer i,j;
        control(16);
        write_reg('h208,60);write_reg('h20c,2);write_reg('h210,4);
        for(i=0;i<3;i++)begin
            for(j=0;j<50;j++)dictionary[i][j*8+:8]=(j*(7+i*4))^(8'ha5+i*31);
            frame(i);
        end
        write_reg('h244,(1<<16)|0);
        write_reg('h244,(2<<16)|(bad==2 ? 2048:1));
        write_reg('h244,((bad==3 ? 2:1)<<16)|2);
        write_reg('h244,(4<<16)|1);
        for(i=0;i<256;i++)write_reg('h248,i==1 ? ((1<<16)|3) :
                                                  bad==1 && i==255 ? ((2<<16)|3) : (3<<16));
        write_reg('h24c,0);write_reg('h24c,1);
    endtask
    task check_error(input integer error);
        wait_idle();rd_addr='h218;#1;
        if(rd_data!=error)$fatal(1,"error got %0d expected %0d",rd_data,error);
        if(dut.qam_owned || dut.qam_running)$fatal(1,"invalid table acquired outputs");
    endtask
    integer i,j,n,p,k,e,first,count,nframes,nevents,npayload,krepeat,loopticks;
    integer saved_latches;
    reg [415:0] padded;
    reg [31:0] held_word;
    string fixture_dir;
    initial begin
        #23;resetn=1;normal_mr=1;normal_oe=0;repeat(40)@(negedge clk);
        rd_addr='h200;#1;if(rd_data!='h51414d31 || rd_resp)$fatal(1,"identity");
        reject('h208,1);reject('h208,59);reject('h208,1000001);
        reject('h20c,0);reject('h210,0);reject('h204,1);reject('h24c,256);
        wr_strb=3;reject('h208,60);wr_strb=15;
        fixture(0);
        for(i=0;i<8;i++)begin
            expected_frame[i]=(i<6 ? i%3 : 1);
            expected_ticks[i]=(i<6 ? (i%3==1 ? 120:60):240);
        end
        expected_count=8;expected_index=0;latches=0;checking=1;
        control(1);
        reject('h240,0);reject('h208,120);reject('ha4,1);
        reject('h204,8);reject('h204,16);reject('h204,1);reject('h248,0);
        wait_idle();
        if(latches!=8 || expected_index!=8)$fatal(1,"once count %0d",latches);
        saved_latches=latches;repeat(60)@(negedge clk);
        if(latches!=saved_latches || !dut.qam_owned)$fatal(1,"one-shot failed to hold");
        for(i=0;i<13;i++)begin
            rd_addr='h280+i*4;#1;padded={16'b0,dictionary[1]};
            if(rd_data!==padded[i*32+:32])$fatal(1,"held frame readback word %0d",i);
        end
        release_pins();
        $display("PASS QAM: 50 independent bytes, 8 pulses, 5ns SHCP, K/payload, exact durations, hold/readback");

        for(i=1;i<=3;i++)begin
            fixture(i);saved_latches=latches;control(1);check_error(i);
            if(latches!=saved_latches)$fatal(1,"invalid table produced latch");
        end
        $display("PASS QAM: complete preflight rejects descriptor/frame/period errors without output");

        fixture(0);expected_index=0;latches=0;expected_count=64;
        for(i=8;i<64;i++)begin expected_frame[i]=expected_frame[i%8];expected_ticks[i]=expected_ticks[i%8];end
        checking=1;control(2);wait(latches>=10);
        wait(dut.u_qam.phase==10);control(0);wait_idle();
        saved_latches=latches;repeat(100)@(negedge clk);
        if(latches!=saved_latches || shift!=0 || latch!=0)$fatal(1,"STOP left pulses");
        release_pins();
        $display("PASS QAM: whole payload looping and STOP completes current burst without timing distortion");

        // Stop during validation: normal pins must never be acquired.
        control(1);control(0);wait_idle();
        if(dut.qam_owned)$fatal(1,"STOP during preflight acquired pins");
        // The existing mode must exclude QAM start; new mode excludes legacy.
        write_reg('ha4,1);repeat(20)@(negedge clk);reject('h204,1);
        write_reg('ha4,0);repeat(60)@(negedge clk);write_reg('ha4,8);repeat(20)@(negedge clk);
        $display("PASS QAM: preflight STOP, legacy arbitration");

        if($value$plusargs("FIXTURE=%s",fixture_dir))begin
            $readmemh({fixture_dir,"/dimensions.hex"},file_symbols,0,4);
            nframes=file_symbols[0];nevents=file_symbols[1];npayload=file_symbols[2];
            krepeat=file_symbols[3];loopticks=file_symbols[4];
            $readmemh({fixture_dir,"/frames.hex"},file_frames,0,nframes*13-1);
            $readmemh({fixture_dir,"/events.hex"},file_events,0,nevents-1);
            $readmemh({fixture_dir,"/symbols.hex"},file_symbols);
            $readmemh({fixture_dir,"/payload.hex"},file_payload,0,npayload-1);
            control(16);
            if($test$plusargs("CHECK_QAM64"))write_reg('h250,64);
            write_reg('h208,loopticks);write_reg('h210,$test$plusargs("CHECK_QAM64") ? 1875:256);write_reg('h20c,krepeat);
            for(i=0;i<nframes;i++)begin
                padded=0;
                for(j=0;j<13;j++)begin padded[j*32+:32]=file_frames[i*13+j];write_reg('h240,file_frames[i*13+j]);end
                dictionary[i]=padded[399:0];
            end
            for(i=0;i<nevents;i++)write_reg('h244,file_events[i]);
            for(i=0;i<256;i++)write_reg('h248,file_symbols[i]);
            for(i=0;i<npayload;i++)write_reg('h24c,file_payload[i]);
            n=0;
            for(p=0;p<npayload;p++)begin
                first=file_symbols[file_payload[p]][15:0];count=file_symbols[file_payload[p]][31:16];
                for(k=0;k<krepeat;k++)for(e=first;e<first+count;e++)begin
                    expected_frame[n]=file_events[e][15:0];expected_ticks[n]=file_events[e][31:16]*loopticks;n++;
                end
            end
            expected_count=n;expected_index=0;latches=0;checking=1;
            control(1);wait_idle();
            if(latches!=n || expected_index!=n)$fatal(1,"codebook count got %0d expected %0d",latches,n);
            release_pins();
            $display("PASS QAM: real 256-symbol codebook, %0d vectors and K=%0d payload events checked",n,krepeat);
            if($test$plusargs("CHECK_PREAMBLE") || $test$plusargs("CHECK_QAM64"))begin
                if(n*2>65536)$fatal(1,"preamble fixture too long");
                for(i=0;i<n;i++)begin expected_frame[n+i]=expected_frame[i];expected_ticks[n+i]=expected_ticks[i];end
                expected_count=n*2;expected_index=0;latches=0;checking=1;
                control(2);wait(latches>=n+2);control(0);wait_idle();
                release_pins();
                $display("RIS_PREAMBLE_TEST_PASS: 400-bit prefix/QAM states, every latch interval and frame-loop boundary");
            end
        end
        if($test$plusargs("CHECK_QAM64"))begin
            // Worst case: every event lasts only 29 fast ticks, including STOP.
            control(16);write_reg('h250,64);write_reg('h208,1);write_reg('h210,58);write_reg('h20c,1);
            for(i=0;i<2;i++)frame(i);
            write_reg('h244,(29<<16)|0);write_reg('h244,(29<<16)|1);
            for(i=0;i<256;i++)write_reg('h248,2<<16);
            write_reg('h24c,0);
            for(i=0;i<128;i++)begin expected_frame[i]=i%2;expected_ticks[i]=29;end
            expected_count=128;expected_index=0;latches=0;checking=1;
            control(2);wait(latches>=20);wait(dut.u_qam.phase==10);control(0);wait_idle();
            saved_latches=latches;repeat(100)@(negedge clk);
            if(latches!=saved_latches || shift || latch)$fatal(1,"64QAM dense STOP failed");
            release_pins();
            // An event below 29 ticks must fail before acquiring the outputs.
            control(16);write_reg('h250,64);write_reg('h208,1);write_reg('h210,28);frame(0);
            write_reg('h244,28<<16);for(i=0;i<256;i++)write_reg('h248,1<<16);write_reg('h24c,0);
            control(1);check_error(2);
            $display("RIS_QAM64_TEST_PASS: full source, prefix/frame boundaries, 29-tick dense events, STOP, min-event rejection, 100MHz SHCP");
        end
        // Reset while shifting cancels ownership and disables outputs.
        fixture(0);control(2);wait(dut.qam_running);wait(dut.u_qam.phase==10);
        normal_mr=0;normal_oe=1;resetn=0;#100;
        if(!oe_n || shift || latch || dut.qam_owned)$fatal(1,"reset did not quiet output");
        resetn=1;normal_mr=1;repeat(40)@(negedge clk);
        reject('h204,1); // Reset invalidates all uploaded tables.
        $display("RIS_QAM_TEST_PASS");$finish;
    end
    initial begin #200000000;$fatal(1,"timeout");end
endmodule
