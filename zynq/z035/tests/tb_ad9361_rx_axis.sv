`timescale 1ns/1ps
module tb_ad9361_rx_axis;
    parameter integer PACKET_WORDS=7;
    reg rx_clk=0, ref_clk=0, axis_clk=0, resetn=0, arm=0;
    reg rx_running=1;
    always #2.0345 if(rx_running) rx_clk=~rx_clk;
    always #2.5 ref_clk=~ref_clk;
    always #5 axis_clk=~axis_clk;
    reg [5:0] data=0;
    reg frame=0;
    wire [63:0] axis_data;
    wire [7:0] keep;
    wire valid,last,ready_status,locked,active,overflow,frame_error,delay_error;
    reg ready=1;
    reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
    reg [15:0] awaddr=0,araddr=0;
    reg [31:0] wdata=0;
    wire awready,wready,bvalid,arready,rvalid;
    wire [31:0] rdata;
    wire [1:0] bresp,rresp;
    ad9361_rx_axis #(.FIFO_DEPTH(64),.PACKET_SAMPLES(PACKET_WORDS)) dut(
        .rx_clk_p(rx_clk),.rx_clk_n(~rx_clk),.rx_frame_p(frame),.rx_frame_n(~frame),
        .rx_data_p(data),.rx_data_n(~data),.ref_clk200(ref_clk),.aresetn(resetn),
        .m_axis_aclk(axis_clk),.capture_arm(arm),.rx_ready(ready_status),
        .frame_locked(locked),.capture_active(active),.overflow(overflow),
        .frame_error(frame_error),.delay_error(delay_error),
        .m_axis_tdata(axis_data),.m_axis_tkeep(keep),.m_axis_tlast(last),
        .m_axis_tvalid(valid),.m_axis_tready(ready),
        .s_axi_awvalid(awvalid),.s_axi_awaddr(awaddr),.s_axi_awprot(3'd0),.s_axi_awready(awready),
        .s_axi_wvalid(wvalid),.s_axi_wdata(wdata),.s_axi_wstrb(4'hf),.s_axi_wready(wready),
        .s_axi_bvalid(bvalid),.s_axi_bresp(bresp),.s_axi_bready(bready),
        .s_axi_arvalid(arvalid),.s_axi_araddr(araddr),.s_axi_arprot(3'd0),.s_axi_arready(arready),
        .s_axi_rvalid(rvalid),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rready(rready));
    // Unmodified upstream LVDS interface is an independent oracle.
    wire oracle_valid,oracle_status;
    wire [47:0] oracle_data;
    axi_ad9361_lvds_if #(.FPGA_TECHNOLOGY(1),.IO_DELAY_GROUP("ORACLE_RX")) oracle(
        .rx_clk_in_p(rx_clk),.rx_clk_in_n(~rx_clk),.rx_frame_in_p(frame),.rx_frame_in_n(~frame),
        .rx_data_in_p(data),.rx_data_in_n(~data),.tx_clk_out_p(),.tx_clk_out_n(),
        .tx_frame_out_p(),.tx_frame_out_n(),.tx_data_out_p(),.tx_data_out_n(),.enable(),.txnrx(),
        .rst(dut.official_rst),.clk(dut.rx_clk),.l_clk(),.adc_valid(oracle_valid),
        .adc_data(oracle_data),.adc_status(oracle_status),.adc_r1_mode(dut.adc_r1_mode),
        .adc_ddr_edgesel(1'b0),.dac_valid(1'b0),.dac_data(48'd0),.dac_clksel(1'b0),.dac_r1_mode(1'b0),
        .tdd_enable(1'b0),.tdd_txnrx(1'b0),.tdd_mode(1'b0),.mmcm_rst(dut.mmcm_rst),
        .up_clk(axis_clk),.up_rstn(resetn),.up_enable(1'b0),.up_txnrx(1'b0),
        .up_adc_dld(dut.adc_dld[6:0]),.up_adc_dwdata(dut.adc_dwdata[34:0]),.up_adc_drdata(),
        .up_dac_dld(10'd0),.up_dac_dwdata(50'd0),.up_dac_drdata(),
        .delay_clk(ref_clk),.delay_rst(dut.delay_rst),.delay_locked(),.up_drp_sel(1'b0),
        .up_drp_wr(1'b0),.up_drp_addr(12'd0),.up_drp_wdata(32'd0),
        .up_drp_rdata(),.up_drp_ready(),.up_drp_locked());
    integer oracle_checks=0;
    always @(negedge rx_clk) if(resetn && ready_status) begin
        if({dut.official_valid,dut.official_data,dut.official_status} !==
            {oracle_valid,oracle_data,oracle_status}) $fatal(1,"Official LVDS oracle mismatch");
        oracle_checks=oracle_checks+1;
    end
    task automatic wr(input [15:0] address,input [31:0] value);
        bit awdone,wdone;
        begin
            @(negedge axis_clk);awaddr=address;wdata=value;awvalid=1;wvalid=1;bready=1;
            awdone=0;wdone=0;
            while(!awdone || !wdone) begin
                @(posedge axis_clk);
                if(awvalid && awready) awdone=1;
                if(wvalid && wready) wdone=1;
                @(negedge axis_clk);if(awdone)awvalid=0;if(wdone)wvalid=0;
            end
            while(!bvalid) @(negedge axis_clk);
            if(bresp) $fatal(1,"AXI write failed %h",address);
            @(negedge axis_clk);bready=0;
        end
    endtask
    task automatic rd(input [15:0] address,output [31:0] value);
        begin
            @(negedge axis_clk);araddr=address;arvalid=1;rready=1;
            do @(posedge axis_clk); while(!arready);
            @(negedge axis_clk);arvalid=0;
            while(!rvalid) @(negedge axis_clk);
            if(rresp) $fatal(1,"AXI read failed %h",address);
            value=rdata;@(negedge axis_clk);rready=0;
        end
    endtask
    task automatic configure;
        reg [31:0] value;
        integer k;
        begin
            rd(16'h1008,value);
            if(value!=32'h41445258) $fatal(1,"Missing adapter signature");
            wr(16'h0040,3);wr(16'h0044,0);
            for(k=0;k<4;k=k+1) begin
                wr(16'h0400+k*64,1);
                wr(16'h0418+k*64,32'h00090000);
            end
            wait(ready_status);
            rd(0,value);if(value==0 || value==32'hffffffff) $fatal(1,"Missing official version");
            for(k=0;k<7;k=k+1) begin
                wr(16'h0800+k*4,5);
                rd(16'h0800+k*4,value);
                if(value!=5) $fatal(1,"Official delay register readback mismatch lane %0d value %h",k,value);
            end
            #2000;
        end
    endtask
    function automatic [15:0] ext(input [11:0] x);ext={{4{x[11]}},x};endfunction
    reg pn_mode=0,pn_device=0,pn_corrupt=0,frame_corrupt=0;
    reg [23:0] pnword[0:3];
    reg [15:0] device_state[0:1];
    function automatic [11:0] reverse12(input [11:0] bits_in);
        for(integer j=0;j<12;j=j+1)reverse12[j]=bits_in[11-j];
    endfunction
    function automatic [23:0] pn_next(input [23:0] state,input integer channel);
        reg [23:0] a,outval;
        integer n,t,k;
        reg feedback;
        begin
            case(channel) 0:begin n=9;t=5;end 1:begin n=11;t=9;end
                2:begin n=15;t=14;end default:begin n=20;t=3;end endcase
            a=state;
            for(k=23;k>=0;k=k-1) begin
                feedback=a[n-1]^a[t-1];outval[k]=feedback;a={a[22:0],feedback};
            end
            pn_next=outval;
        end
    endfunction
    task automatic send_pair(input [5:0] i,input [5:0] q,input bit f,input bit bad);
        begin
            @(posedge rx_clk);#0.2;data=i;frame=f;
            @(negedge rx_clk);#0.2;data=q;frame=bad ? !f : f;
        end
    endtask
    integer physical_index=0;
    task automatic send_sample(input integer n);
        reg [11:0] a,b,c,d;
        reg bad;
        integer k;
        begin
            a=n;b=n^12'h800;c=~n;d=n^12'ha55;
            if(pn_mode) begin
                if((n&1)==0) for(k=0;k<4;k=k+1)pnword[k]=pn_next(pnword[k],k);
                a=(n&1)?pnword[0][11:0]:pnword[0][23:12];
                b=(n&1)?pnword[1][11:0]:pnword[1][23:12];
                c=(n&1)?pnword[2][11:0]:pnword[2][23:12];
                d=(n&1)?pnword[3][11:0]:pnword[3][23:12];
            end
            if(pn_device) begin
                for(k=0;k<2;k=k+1)
                    device_state[k]={device_state[k][14:0],
                        (^device_state[k][15:4])^(^device_state[k][2:1])};
                a=device_state[0][15:4];b=reverse12(device_state[0][11:0]);
                c=device_state[1][15:4];d=reverse12(device_state[1][11:0]);
            end
            if((pn_mode || pn_device) && pn_corrupt)begin a=a^1;pn_corrupt=0;end
            bad=frame_corrupt;frame_corrupt=0;
            send_pair(a[11:6],b[11:6],1,0);send_pair(a[5:0],b[5:0],1,bad);
            send_pair(c[11:6],d[11:6],0,0);send_pair(c[5:0],d[5:0],0,0);
        end
    endtask
    initial begin
        for(integer k=0;k<4;k=k+1)pnword[k]=24'hffffff;
        device_state[0]=16'hace1;device_state[1]=16'hbeef;
        forever begin send_sample(physical_index);physical_index=physical_index+1;end
    end
    reg score=1;
    integer received=0,next_index=-1,packet_index=0;
    reg [63:0] held_data;
    reg held_last,stalled=0;
    always @(posedge axis_clk) begin
        if(!resetn) begin next_index=-1;packet_index=0;stalled=0;end
        else begin
            if(stalled && (!valid || axis_data!==held_data || last!==held_last))
                $fatal(1,"AXIS beat changed under backpressure");
            stalled=valid&&!ready;held_data=axis_data;held_last=last;
            if(valid && ready && score) begin : check_tuple
                reg [11:0] n;
                n=axis_data[11:0];
                if(next_index>=0 && n!==next_index[11:0]) $fatal(1,"IQ continuity: got %h expected %h",n,next_index[11:0]);
                if(axis_data!=={ext(n^12'ha55),ext(~n),ext(n^12'h800),ext(n)})
                    $fatal(1,"Four-channel IQ/sign mismatch %h",axis_data);
                if(keep!==8'hff || last!==(packet_index==PACKET_WORDS-1))$fatal(1,"TKEEP/TLAST mismatch");
                packet_index=(packet_index+1)%PACKET_WORDS;next_index=(n+1)%4096;received=received+1;
            end
        end
    end
    reg [226:0] trace_expected[0:63];
    integer trace_next=0,trace_checks=0,trace_core_reset_checks=0;
    reg [23:0] trace_prev;
    always @(posedge dut.rx_clk) if(dut.prefifo_write)
        trace_expected[dut.prefifo_write_index]=dut.prefifo_capture_word;
    always @(negedge ref_clk or negedge resetn) begin
        if(!resetn)trace_next=0;
        else if(dut.prefifo_valid_ref)begin
            if(dut.prefifo_official_rst_ref)trace_core_reset_checks=trace_core_reset_checks+1;
            if(dut.prefifo_index_ref!==trace_next[5:0] || dut.prefifo_read_word!==trace_expected[trace_next])
                $fatal(1,"200 MHz trace CDC corruption/order mismatch");
            if(trace_next && dut.prefifo_rx_edge_counter_ref!==((trace_prev+1'b1)&24'hffffff))
                $fatal(1,"Nonconsecutive RX trace");
            trace_prev=dut.prefifo_rx_edge_counter_ref;trace_next=(trace_next+1)%64;trace_checks=trace_checks+1;
        end
    end
    reg [31:0] value;
    integer target,k;
    initial begin
        #600;@(negedge axis_clk);resetn=1;
        configure();arm=1;target=PACKET_WORDS>100?PACKET_WORDS+20:300;
        wait(received>=target);
        if(overflow || frame_error || delay_error || !active)$fatal(1,"Healthy capture failed");
        $display("PASS: official RX oracle, AXI delay control, four raw IQ, signs, TLAST, CDC");
        @(negedge axis_clk);ready=0;wait(overflow);#1000;
        @(negedge axis_clk);ready=1;#3000;
        if(!overflow || active)$fatal(1,"Overflow did not stop acquisition");
        $display("PASS: overflow stop and stable AXIS backpressure");
        @(negedge axis_clk);resetn=0;arm=0;#600;@(negedge axis_clk);resetn=1;
        configure();arm=1;wait(active);#500;frame_corrupt=1;wait(frame_error);#1000;
        if(active)$fatal(1,"FRAME fault did not stop capture");
        $display("PASS: corrupt raw FRAME reported by official interface and capture stopped");
        @(negedge axis_clk);resetn=0;arm=0;score=0;#600;@(negedge axis_clk);resetn=1;
        configure();pn_mode=1;#30000;
        for(k=0;k<4;k=k+1)wr(16'h0404+k*64,6);
        #30000;
        for(k=0;k<4;k=k+1)begin rd(16'h0404+k*64,value);if(value&6)$fatal(1,"PN did not lock channel %0d status %h",k,value);end
        rd(16'h1000,value);
        if(value<100) $fatal(1,"Valid ADC sample counter failed");
        rd(16'h1004,value);
        if(value<1000) $fatal(1,"RX edge counter failed");
        $display("PASS: official AXI-Lite and live sample/clock diagnostic registers");
        $display("PASS: all four official PN monitors lock on independent standard PRBS streams");
        pn_corrupt=1;#10000;rd(16'h0404,value);
        if(!(value&6))$fatal(1,"PN checker failed to detect data corruption");
        $display("PASS: official PN register flags injected data error");
        pn_mode=0;pn_device=1;
        for(k=0;k<4;k=k+1)wr(16'h0418+k*64,0);
        #30000;
        for(k=0;k<4;k=k+1)wr(16'h0404+k*64,6);
        #30000;
        for(k=0;k<4;k=k+1)begin
            rd(16'h0404+k*64,value);
            if(value&6)$fatal(1,"AD9361 device PN did not lock channel %0d status %h",k,value);
        end
        pn_corrupt=1;#10000;rd(16'h0404,value);
        if(!(value&6))$fatal(1,"Device PN checker missed corrupt I/Q pair");
        $display("PASS: AD9361 RX BIST device-specific PN locks all four channels and detects corrupt I/Q");
        target=trace_core_reset_checks;
        wr(16'h0040,0);#2000;wr(16'h0040,3);#2000;
        if(trace_core_reset_checks<=target)$fatal(1,"Recorder did not preserve core-reset diagnostics");
        $display("PASS: coherent 200 MHz recorder remains independent of official core reset");
        @(negedge rx_clk);rx_running=0;#100;resetn=0;#600;
        if(valid)$fatal(1,"AXIS valid survived reset with stopped RX clock");
        rx_running=1;#600;@(negedge axis_clk);resetn=1;pn_mode=0;pn_device=0;
        configure();
        if(trace_checks<128 || oracle_checks<1000)$fatal(1,"Insufficient oracle/trace checks");
        $display("AD9361_OFFICIAL_RX_TEST_PASS PACKET=%0d ORACLE=%0d TRACE=%0d",PACKET_WORDS,oracle_checks,trace_checks);
        $finish;
    end
    initial begin #1000000;$fatal(1,"Test timed out");end
endmodule
