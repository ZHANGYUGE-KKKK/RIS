`timescale 1ns/1ps
module tb_ris_controller #(parameter integer FRAME_SLOTS=16);
    reg clk=0;
    always #5 clk=~clk;
    reg resetn=0;
    reg [3:0] awid=0,arid=0;
    reg [31:0] awaddr=0,araddr=0,wdata=0;
    reg [7:0] awlen=0,arlen=0;
    reg [2:0] awsize=2,arsize=2;
    reg [1:0] awburst=1,arburst=1;
    reg awvalid=0,wvalid=0,wlast=0,bready=0,arvalid=0,rready=0;
    reg [3:0] wstrb=0;
    wire awready,wready,bvalid,arready,rvalid,rlast;
    wire [3:0] bid,rid;
    wire [1:0] bresp,rresp;
    wire [31:0] rdata;
    wire [49:0] data;
    wire [9:0] shcp,stcp;
    wire mr_n,oe_n;
    ris_controller_axi #(.ID_WIDTH(4),.FRAME_SLOTS(FRAME_SLOTS),.CMD_DEPTH(4),
        .RESULT_DEPTH(32),.BLOCK_DEPTH(8)) dut (
        .s_axi_aclk(clk),.s_axi_aresetn(resetn),
        .s_axi_awid(awid),.s_axi_awaddr(awaddr),.s_axi_awlen(awlen),
        .s_axi_awsize(awsize),.s_axi_awburst(awburst),.s_axi_awlock(1'b0),
        .s_axi_awcache(4'b0),.s_axi_awprot(3'b0),.s_axi_awqos(4'b0),
        .s_axi_awvalid(awvalid),.s_axi_awready(awready),
        .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wlast(wlast),
        .s_axi_wvalid(wvalid),.s_axi_wready(wready),
        .s_axi_bid(bid),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
        .s_axi_arid(arid),.s_axi_araddr(araddr),.s_axi_arlen(arlen),
        .s_axi_arsize(arsize),.s_axi_arburst(arburst),.s_axi_arlock(1'b0),
        .s_axi_arcache(4'b0),.s_axi_arprot(3'b0),.s_axi_arqos(4'b0),
        .s_axi_arvalid(arvalid),.s_axi_arready(arready),
        .s_axi_rid(rid),.s_axi_rdata(rdata),.s_axi_rresp(rresp),
        .s_axi_rlast(rlast),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
        .ris_data(data),.ris_shcp(shcp),.ris_stcp(stcp),.ris_mr_n(mr_n),.ris_oe_n(oe_n)
    );
    reg [7:0] shift_data[0:49],q[0:49],expected[0:49];
    integer updates[0:9],shifts[0:9];
    real last_latch[0:9],previous_latch[0:9];
    reg [7:0] history[0:4095];
    integer history_count=0;
    genvar c,g;
    generate
        for (c=0;c<50;c=c+1) begin: device
            always @(posedge shcp[c/5] or negedge mr_n)
                if (!mr_n) shift_data[c]<=0;
                else shift_data[c]<={shift_data[c][6:0],data[c]};
            always @(posedge stcp[c/5]) q[c]<=shift_data[c];
        end
        for (g=0;g<10;g=g+1) begin: timing_check
            initial begin updates[g]=0; shifts[g]=0; last_latch[g]=0; previous_latch[g]=0; end
            always @(negedge mr_n) shifts[g]=0;
            always @(posedge shcp[g]) begin
                if (!mr_n || stcp[g]) $fatal(1,"Illegal shift overlap group %0d",g);
                shifts[g]=shifts[g]+1;
            end
            always @(posedge stcp[g]) begin
                if (!mr_n || shcp[g] || shifts[g]!=8)
                    $fatal(1,"Expected eight shifts group %0d got %0d",g,shifts[g]);
                shifts[g]=0; updates[g]=updates[g]+1;
                previous_latch[g]=last_latch[g]; last_latch[g]=$realtime;
            end
        end
    endgenerate
    always @(posedge stcp[0]) begin
        history[history_count]=shift_data[0]; history_count=history_count+1;
    end
    // AXI response fields must remain stable under backpressure.
    reg b_stalled=0,r_stalled=0;
    reg [5:0] saved_b;
    reg [38:0] saved_r;
    always @(posedge clk) begin
        if (resetn) begin
            if (b_stalled && (!bvalid || {bid,bresp}!==saved_b)) $fatal(1,"B channel changed while stalled");
            if (r_stalled && (!rvalid || {rid,rdata,rresp,rlast}!==saved_r)) $fatal(1,"R channel changed while stalled");
        end
        b_stalled<=resetn && bvalid && !bready;
        r_stalled<=resetn && rvalid && !rready;
        saved_b<={bid,bresp}; saved_r<={rid,rdata,rresp,rlast};
    end
    function automatic [7:0] byte_pattern(input integer index,input integer tag);
        byte_pattern=tag^(index*13);
    endfunction
    reg [31:0] words[0:255];
    task automatic write_address(input [31:0] address,input integer beats,input [2:0] size,input [1:0] burst);
        @(negedge clk); awaddr=address; awlen=beats-1; awsize=size; awburst=burst; awid=4'ha; awvalid=1;
        do @(posedge clk); while (!awready);
        @(negedge clk); awvalid=0;
    endtask
    task automatic write_beats(input integer beats,input [3:0] strobe,input bit missing_last);
        integer n;
        for (n=0;n<beats;n=n+1) begin
            @(negedge clk); wdata=words[n]; wstrb=strobe; wlast=(n==beats-1)&&!missing_last; wvalid=1;
            do @(posedge clk); while (!wready);
            @(negedge clk); wvalid=0;
        end
    endtask
    task automatic finish_write(input [1:0] response);
        while (!bvalid) @(negedge clk);
        repeat (3) @(negedge clk);
        if (bresp!==response || bid!==4'ha) $fatal(1,"Bad B response addr=%h got=%h expected=%h",awaddr,bresp,response);
        bready=1; @(posedge clk); @(negedge clk); bready=0;
    endtask
    task automatic burst_write(input [31:0] address,input integer beats,
        input [3:0] strobe,input [2:0] size,input [1:0] burst,input bit data_first,
        input bit missing_last,input [1:0] response);
        fork
            begin if (data_first) repeat (3) @(posedge clk); write_address(address,beats,size,burst); end
            begin if (!data_first) repeat (2) @(posedge clk); write_beats(beats,strobe,missing_last); end
        join
        finish_write(response);
    endtask
    task automatic write_reg(input [15:0] address,input [31:0] value);
        words[0]=value; burst_write({16'h4120,address},1,15,2,1,0,0,0);
    endtask
    task automatic read_reg(input [15:0] address,output reg [31:0] value);
        @(negedge clk); araddr={16'h4120,address}; arlen=0; arsize=2; arburst=1; arid=4'h6; arvalid=1;
        do @(posedge clk); while (!arready);
        @(negedge clk); arvalid=0;
        while (!rvalid) @(negedge clk);
        repeat (2) @(negedge clk);
        if (rresp!=0 || rid!=6 || !rlast) $fatal(1,"Bad read response %h",address);
        value=rdata; rready=1;
        @(posedge clk); @(negedge clk); rready=0;
    endtask
    task automatic burst_read_check(input [15:0] address,input integer beats,input [1:0] response);
        integer n;
        @(negedge clk); araddr={16'h4120,address}; arlen=beats-1;
        arsize=2; arburst=1; arid=7; arvalid=1;
        do @(posedge clk); while (!arready);
        @(negedge clk); arvalid=0;
        for (n=0;n<beats;n=n+1) begin
            while (!rvalid) @(negedge clk);
            repeat (n%3+1) @(negedge clk);
            if (rresp!==response || rid!=7 || rlast!==(n==beats-1)) $fatal(1,"Bad burst read framing");
            if (response==0 && rdata!==words[n]) $fatal(1,"Readback beat %0d expected=%h got=%h",n,words[n],rdata);
            rready=1; @(posedge clk); @(negedge clk); rready=0;
        end
    endtask
    task automatic prepare_words(input integer tag);
        integer n,b;
        for (n=0;n<16;n=n+1) begin
            words[n]=0;
            for (b=0;b<4;b=b+1)
                if (n*4+b<50) words[n][b*8+:8]=byte_pattern(n*4+b,tag);
        end
    endtask
    task automatic stage_frame(input integer tag);
        prepare_words(tag); burst_write(32'h41200100,16,15,2,1,1,0,0);
    endtask
    task automatic upload(input integer slot,input integer tag);
        prepare_words(tag); burst_write(32'h41201000+slot*64,16,15,2,1,0,0,0);
        burst_read_check(16'h1000+slot*64,16,0);
    endtask
    integer next_id=1;
    task automatic command(input [7:0] op,input [1:0] flags,input [49:0] mask,
        input [31:0] arg0,input [31:0] arg1,output integer id);
        id=next_id; next_id=next_id+1;
        write_reg('h10,{22'b0,flags,op}); write_reg('h14,id);
        write_reg('h18,arg0); write_reg('h1c,arg1);
        write_reg('h20,mask[31:0]); write_reg('h24,{14'b0,mask[49:32]});
        write_reg('h28,1);
    endtask
    task automatic completion(input integer id,input [31:0] code);
        reg [31:0] levels,got_id,got_code;
        integer timeout;
        timeout=0; levels=0;
        while (levels[15:8]==0 && timeout<5000) begin
            read_reg('h3c,levels); timeout=timeout+1;
        end
        if (levels[15:8]==0) $fatal(1,"Completion timeout id=%0d",id);
        read_reg('h30,got_id); read_reg('h34,got_code);
        if (got_id!=id || got_code!=code)
            $fatal(1,"Completion expected %0d:%0d got %0d:%0d state=%0d",id,code,got_id,got_code,dut.u_core.state);
        write_reg('h38,1);
    endtask
    task automatic simple_command(input [7:0] op,input [31:0] arg0);
        integer id;
        command(op,0,0,arg0,0,id); completion(id,1);
    endtask
    task automatic check_pattern(input [49:0] mask,input integer tag);
        integer n;
        for (n=0;n<50;n=n+1) begin
            if (mask[n]) expected[n]=byte_pattern(n,tag);
            if (q[n]!==expected[n]) $fatal(1,"Chip %0d expected %h got %h tag=%h",n,expected[n],q[n],tag);
        end
    endtask
    task automatic wait_state(input integer target);
        reg [31:0] status;
        integer timeout;
        timeout=0;
        do begin read_reg('h4,status); timeout=timeout+1; end
        while (status[2:0]!=target && timeout<5000);
        if (status[2:0]!=target) $fatal(1,"State timeout target=%0d got=%0d",target,status[2:0]);
    endtask
    task automatic wait_updates(input integer count);
        integer timeout;
        timeout=0;
        while (updates[0]<count && timeout<20000) begin @(negedge clk); timeout=timeout+1; end
        if (updates[0]<count) $fatal(1,"Latch timeout");
        repeat (15) @(negedge clk);
    endtask
    task automatic set_config(input integer period,input integer base,input integer count,
        input integer loop_enable,input [49:0] mask);
        write_reg('h40,period); write_reg('h44,mask[31:0]); write_reg('h48,{14'b0,mask[49:32]});
        write_reg('h4c,base); write_reg('h50,count); write_reg('h54,loop_enable);
        simple_command('h11,0);
    endtask
    integer id,id2,id3,n,k,before_count,hist_start;
    integer queued_ids[0:3];
    integer old_updates[0:9];
    reg [31:0] value;
    reg [49:0] mask;
    initial begin
        for (n=0;n<50;n=n+1) expected[n]=0;
        #1; resetn=1; #1; resetn=0;
        repeat (4) @(negedge clk); resetn=1;
        wait_state(2);
        if (!oe_n) $fatal(1,"Outputs enabled at reset");
        check_pattern(0,0);
        simple_command('h30,0);
        if (oe_n) $fatal(1,"Output enable failed");

        $display("TEST: board-v1 400 outputs all LOW/HIGH at 1 MHz SHCP");
        write_reg('h40,10000);
        write_reg('h5c,50); write_reg('h60,50); write_reg('h64,50); write_reg('h68,50);
        simple_command('h11,0);
        for (k=0;k<4;k=k+1) begin
            read_reg('h6c,value); before_count=value;
            for (n=0;n<13;n=n+1)
                write_reg('h100+n*4,k[0] ? (n==12 ? 32'h0000ffff : 32'hffffffff) : 0);
            command(1,1,{50{1'b1}},0,0,id); completion(id,1);
            for (n=0;n<50;n=n+1) begin
                expected[n]=k[0] ? 8'hff : 8'h00;
                if (q[n]!==expected[n]) $fatal(1,"400-output test chip %0d",n);
            end
            for (n=0;n<16;n=n+1) begin
                read_reg('h140+n*4,value);
                if (value!==(k[0] && n<13 ? (n==12 ? 32'hffff : 32'hffffffff) : 0))
                    $fatal(1,"400-output mirror/reserved-byte mismatch word %0d",n);
            end
            read_reg('h6c,value);
            if (value!=before_count+1 || oe_n) $fatal(1,"400-output completion/OE mismatch");
            repeat (200) @(negedge clk);
            for (n=0;n<50;n=n+1)
                if (q[n]!==expected[n]) $fatal(1,"Static output did not hold");
        end
        write_reg('h40,1000);
        write_reg('h5c,5); write_reg('h60,5); write_reg('h64,5); write_reg('h68,5);
        simple_command('h11,0);

        $display("TEST: AXI shapes, independent channels, response backpressure");
        prepare_words('h19); burst_write(32'h41200100,16,15,2,1,1,0,0);
        burst_read_check('h100,16,0);
        words[0]=32'hdeadbeef; burst_write(32'h41200100,1,5,2,1,0,0,0);
        read_reg('h100,value);
        // Preserve bytes 1/3 from the preceding frame, replace bytes 0/2.
        if (value[7:0]!=8'hef || value[23:16]!=8'had ||
            value[15:8]!=byte_pattern(1,'h19) || value[31:24]!=byte_pattern(3,'h19))
            $fatal(1,"WSTRB was ignored");
        burst_write(32'h41200100,1,15,1,1,0,0,2);
        burst_write(32'h41200100,2,15,2,2,0,0,2);
        burst_write(32'h41201ffc,2,15,2,1,0,0,2);
        burst_write(32'h41200028,1,15,2,1,0,1,2);
        burst_read_check('h4,2,2);

        $display("TEST: all fifty independent chips and group preservation");
        stage_frame('h21); command(1,0,{50{1'b1}},0,0,id); completion(id,1);
        check_pattern({50{1'b1}},'h21);
        for (k=0;k<50;k=k+1) begin
            for (n=0;n<10;n=n+1) old_updates[n]=updates[n];
            stage_frame('h50+k); mask=50'b1<<k;
            command(1,0,mask,0,0,id); completion(id,1); check_pattern(mask,'h50+k);
            for (n=0;n<10;n=n+1)
                if (updates[n]!=old_updates[n]+(n==k/5)) $fatal(1,"Wrong group clock selected");
        end
        mask=(50'b1<<0)|(50'b1<<6)|(50'b1<<49);
        stage_frame('hc8); command(1,0,mask,0,0,id); completion(id,1); check_pattern(mask,'hc8);
        stage_frame('h72); command(1,0,{50{1'b1}},0,0,id);
        stage_frame('ha9); completion(id,1); check_pattern({50{1'b1}},'h72);

        $display("TEST: queued snapshots, urgent stop cancellation, reset cancellation");
        write_reg('h5c,32); simple_command('h11,0);
        stage_frame('ha0); command(1,0,{50{1'b1}},0,0,id);
        stage_frame('hb0); command(1,0,{50{1'b1}},0,0,id2);
        command('h23,0,0,0,0,id3);
        completion(id,1); completion(id2,3); completion(id3,1);
        check_pattern({50{1'b1}},'ha0);
        stage_frame('ha1); command(1,0,{50{1'b1}},0,0,id);
        stage_frame('hb1); command(1,0,{50{1'b1}},0,0,id2);
        command('h7f,0,0,0,0,id3);
        if (!oe_n) $fatal(1,"Reset did not immediately disable output");
        completion(id,3); completion(id2,3); completion(id3,1);
        for (n=0;n<50;n=n+1) expected[n]=0;
        check_pattern(0,0); wait_state(2); simple_command('h30,0);

        $display("TEST: immutable sequence blocks, finite playback, dynamic mask");
        upload(0,'h11); upload(1,'h22); upload(2,'h33);
        command('h40,0,0,0,3,id); completion(id,1);
        words[0]=0; burst_write(32'h41201000,1,15,2,1,0,0,2);
        set_config(256,0,3,0,50'h3ff); simple_command('h10,1);
        before_count=updates[0]; simple_command('h20,0);
        wait_updates(before_count+3); wait_state(2);
        if (last_latch[0]-previous_latch[0]!=2560.0) $fatal(1,"Wrong frame period");
        check_pattern(50'h3ff,'h33);

        $display("TEST: looping, pause/resume, live period config and inserted manual frame");
        simple_command('h41,0);
        upload(0,'h41); upload(1,'h52);
        command('h40,0,0,0,2,id); completion(id,1);
        set_config(256,0,2,1,{50{1'b1}});
        before_count=updates[0]; simple_command('h20,0); wait_updates(before_count+2);
        simple_command('h21,0); wait_state(5); before_count=updates[0];
        repeat (700) @(negedge clk);
        if (updates[0]!=before_count) $fatal(1,"Paused player changed outputs");
        simple_command('h22,0); wait_updates(before_count+2);
        write_reg('h40,384); simple_command('h11,0);
        before_count=updates[0]; wait_updates(before_count+3);
        if (last_latch[0]-previous_latch[0]!=3840.0) $fatal(1,"Live period change failed");
        hist_start=history_count;
        stage_frame('hf0); command(1,2,{50{1'b1}},0,0,id); completion(id,1);
        check_pattern({50{1'b1}},'hf0);
        before_count=updates[0]; wait_updates(before_count+3);
        begin : verify_insert
            reg [7:0] previous_auto;
            integer injections;
            previous_auto=0; injections=0;
            for (n=hist_start;n<history_count;n=n+1) begin
                if (history[n]=='hf0) injections=injections+1;
                else begin
                    if (history[n]!='h41 && history[n]!='h52) $fatal(1,"Unknown sequence frame");
                    if (previous_auto==history[n]) $fatal(1,"Sequence skipped/repeated around insertion");
                    previous_auto=history[n];
                end
            end
            if (injections!=1) $fatal(1,"Insertion count %0d",injections);
        end
        stage_frame('h77); command(1,1,{50{1'b1}},0,0,id); completion(id,1);
        wait_state(2); check_pattern({50{1'b1}},'h77); before_count=updates[0];
        repeat (900) @(negedge clk);
        if (updates[0]!=before_count) $fatal(1,"APPLY_AND_HOLD kept playing");
        read_reg('h4,value); if (value[4:3]!=0) $fatal(1,"HOLD mode not selected");

        $display("TEST: stream prefill, continuous block refill, underflow and recovery");
        simple_command('h41,0);
        set_config(256,0,0,0,{50{1'b1}}); write_reg('h58,2); simple_command('h11,0);
        simple_command('h10,2); simple_command('h20,0); wait_state(3);
        before_count=updates[0]; repeat (400) @(negedge clk);
        if (updates[0]!=before_count) $fatal(1,"PREFILL did not hold output");
        upload(0,'h81); upload(1,'h82); upload(2,'h83); upload(3,'h84);
        hist_start=history_count;
        command('h40,1,0,0,4,id); completion(id,1);
        upload(4,'h85); upload(5,'h86);
        command('h40,1,0,4,2,id); completion(id,1);
        wait_state(7);
        if (history_count-hist_start!=6) $fatal(1,"Stream frames=%0d err=%h pf=%0d offset=%0d blocks=%0d queued=%0d countdown=%0d",
            history_count-hist_start,dut.u_core.error_flags,dut.u_core.prefetch_state,
            dut.u_core.block_offset,dut.u_core.block_count,dut.u_core.stream_frames,dut.u_core.countdown);
        for (n=0;n<6;n=n+1)
            if (history[hist_start+n]!=(8'h81+n)) $fatal(1,"Stream frame order");
        check_pattern({50{1'b1}},'h86);
        read_reg('hc,value); if (!value[0]) $fatal(1,"Underflow not reported");
        read_reg('h74,value); if (value==0) $fatal(1,"Underflow frame not recorded");
        simple_command('h50,0); wait_state(2);
        upload(0,'h91); upload(1,'h92);
        command('h40,1,0,0,2,id); completion(id,1);
        simple_command('h20,0); wait_state(7); check_pattern({50{1'b1}},'h92);
        simple_command('h50,0); simple_command('h31,0);
        if (!oe_n) $fatal(1,"Output disable failed");
        simple_command('h30,0); if (oe_n) $fatal(1,"Output re-enable failed");

        $display("TEST: invalid configuration and command state rejection");
        write_reg('h40,1); command('h11,0,0,0,0,id); completion(id,2);
        read_reg('h7c,value); if (value!=256) $fatal(1,"Bad config changed active timing");
        command('h22,0,0,0,0,id); completion(id,2);

        $display("TEST: clear-all, incomplete publication and duplicate ownership");
        simple_command('h2,0);
        for (n=0;n<50;n=n+1) begin
            expected[n]=0;
            if (q[n]!==0) $fatal(1,"Clear-all did not latch zero");
        end
        simple_command('h41,0);
        prepare_words('hab); burst_write(32'h41201000,16,7,2,1,0,0,0);
        write_reg('h10,'h40); write_reg('h14,next_id); next_id=next_id+1;
        write_reg('h18,0); write_reg('h1c,1);
        words[0]=1; burst_write(32'h41200028,1,15,2,1,0,0,2);
        upload(0,'hab); command('h40,0,0,0,1,id); completion(id,1);
        write_reg('h14,next_id); next_id=next_id+1;
        words[0]=1; burst_write(32'h41200028,1,15,2,1,0,0,2);
        simple_command('h41,0);

        $display("TEST: queue saturation, urgent barrier and reset preemption");
        write_reg('h40,2000); write_reg('h5c,64); simple_command('h11,0);
        stage_frame('h42); command(1,0,{50{1'b1}},0,0,id);
        for (n=0;n<4;n=n+1) command(1,0,{50{1'b1}},0,0,queued_ids[n]);
        write_reg('h14,next_id); next_id=next_id+1;
        words[0]=1; burst_write(32'h41200028,1,15,2,1,0,0,2);
        command('h23,0,0,0,0,id2);
        completion(id,1);
        for (n=0;n<4;n=n+1) completion(queued_ids[n],3);
        completion(id2,1); check_pattern({50{1'b1}},'h42);
        stage_frame('h53); command(1,0,{50{1'b1}},0,0,id);
        command('h10,0,0,1,0,id2);
        command('h7f,0,0,0,0,id3);
        completion(id2,3); completion(id,3); completion(id3,1);
        wait_state(2);
        if (!oe_n) $fatal(1,"Reset preemption did not leave outputs disabled");
        for (n=0;n<50;n=n+1) begin expected[n]=0; if(q[n]!==0) $fatal(1,"Reset zero initialization"); end

        $display("TEST: 1 MHz complete-frame cadence in the 100 MHz clock domain");
        upload(0,'hb1); upload(1,'hb2);
        command('h40,0,0,0,2,id); completion(id,1);
        write_reg('h5c,4); write_reg('h60,4); write_reg('h64,4); write_reg('h68,4);
        set_config(100,0,2,1,{50{1'b1}});
        simple_command('h10,1); before_count=updates[0]; simple_command('h20,0);
        wait_updates(before_count+8);
        if (last_latch[0]-previous_latch[0]!=1000.0) $fatal(1,"1 MHz frame cadence failed");
        simple_command('h23,0); wait_state(2);
        if (!oe_n) $fatal(1,"Playback enabled outputs without OUTPUT_ENABLE");

        $display("TEST: internal timing-state fault disables output and reports failed commands");
        write_reg('h40,2000); write_reg('h5c,64); simple_command('h11,0);
        simple_command('h30,0); stage_frame('h99);
        command(1,0,{50{1'b1}},0,0,id);
        command(1,0,{50{1'b1}},0,0,id2);
        @(negedge clk); force dut.u_core.u_array.state=4'hf;
        @(posedge clk); @(negedge clk); release dut.u_core.u_array.state;
        wait_state(7);
        if (!oe_n) $fatal(1,"Internal fault did not disable OE");
        completion(id,4); completion(id2,4);
        simple_command('h7f,0); wait_state(2);
        if (FRAME_SLOTS>16) begin
            $display("TEST: publication reductions across 16-slot groups and last slot");
            upload(15,'h25);
            write_reg('h10,'h40); write_reg('h14,next_id); next_id=next_id+1;
            write_reg('h18,15); write_reg('h1c,2);
            words[0]=1; burst_write(32'h41200028,1,15,2,1,0,0,2);
            simple_command('h50,0);
            upload(16,'h26);
            // High bits must not alias valid low-bit BRAM slot addresses.
            write_reg('h10,'h40); write_reg('h14,next_id); next_id=next_id+1;
            write_reg('h18,32'h1000000f); write_reg('h1c,2);
            words[0]=1; burst_write(32'h41200028,1,15,2,1,0,0,2);
            write_reg('h18,15); write_reg('h1c,32'h10000002);
            words[0]=1; burst_write(32'h41200028,1,15,2,1,0,0,2);
            simple_command('h50,0);
            command('h40,0,0,15,2,id); completion(id,1);
            upload(FRAME_SLOTS-1,'h27);
            command('h40,0,0,FRAME_SLOTS-1,1,id); completion(id,1);
            words[0]=0;
            burst_write(32'h41201000+16*64,1,15,2,1,0,0,2);
            burst_write(32'h41201000+(FRAME_SLOTS-1)*64,1,15,2,1,0,0,2);
            simple_command('h50,0);
            simple_command('h41,0);
            write_reg('h4c,32'h10000000); write_reg('h50,1);
            command('h11,0,0,0,0,id); completion(id,2); simple_command('h50,0);
            write_reg('h4c,0); write_reg('h50,32'h10000001);
            command('h11,0,0,0,0,id); completion(id,2); simple_command('h50,0);
            write_reg('h50,0);
            $display("TEST: synchronous BRAM minimum period admission and continuous playback");
            write_reg('h5c,1); write_reg('h60,1); write_reg('h64,1); write_reg('h68,1);
            write_reg('h40,27);
            command('h11,0,0,0,0,id); completion(id,2); simple_command('h50,0);
            write_reg('h40,28); simple_command('h11,0);
            upload(0,'h34); upload(1,'h35);
            command('h40,0,0,0,2,id); completion(id,1);
            set_config(28,0,2,1,{50{1'b1}}); simple_command('h10,1);
            before_count=updates[0]; simple_command('h20,0); wait_updates(before_count+8);
            read_reg('hc,value);
            if (value!=0) $fatal(1,"BRAM minimum-period playback underrun");
            simple_command('h23,0);
        end
        $display("RIS_AXI_TEST_PASS: AXI4, 50 lanes, snapshots, groups, commands, sequence, stream, transitions, errors");
        $finish;
    end
    initial begin #20000000; $fatal(1,"AXI controller watchdog expired"); end
endmodule
