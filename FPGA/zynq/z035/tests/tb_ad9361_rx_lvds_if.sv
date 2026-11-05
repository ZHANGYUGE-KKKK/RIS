`timescale 1ns/1ps
// Stage 1 has no AXIS, DMA, recorder, processor or capture gating.
module tb_ad9361_rx_lvds_if;
    parameter real RX_HALF_PERIOD_NS=8.138;
    parameter integer R1_MODE=0;
    reg rx_clk=0, ref_clk=0, up_clk=0, running=1;
    always #(RX_HALF_PERIOD_NS) if(running) rx_clk=~rx_clk;
    always #2.5 ref_clk=~ref_clk;
    always #5 up_clk=~up_clk;
    reg frame=0, delay_rst=1;
    reg [5:0] data=0;
    reg [6:0] load=0;
    reg [34:0] taps=0;
    wire [34:0] readback, oracle_readback;
    wire clk, valid, status, locked;
    wire [47:0] iq;
    wire [1:0] raw_frame, previous_frame;
    wire [5:0] rise_data, fall_data;
    ad9361_rx_lvds_if #(.IO_DELAY_GROUP("STAGE1_RX")) dut (
        .rx_clk_in_p(rx_clk),.rx_clk_in_n(~rx_clk),
        .rx_frame_in_p(frame),.rx_frame_in_n(~frame),
        .rx_data_in_p(data),.rx_data_in_n(~data),.l_clk(clk),
        .adc_r1_mode(R1_MODE!=0),.adc_valid(valid),.adc_data(iq),.adc_status(status),
        .up_clk(up_clk),.up_adc_dld(load),.up_adc_dwdata(taps),.up_adc_drdata(readback),
        .delay_clk(ref_clk),.delay_rst(delay_rst),.delay_locked(locked),
        .debug_frame(raw_frame),.debug_frame_previous(previous_frame),
        .debug_data_rise(rise_data),.debug_data_fall(fall_data));
    wire oracle_valid,oracle_status,oracle_locked;
    wire [47:0] oracle_iq;
    axi_ad9361_lvds_if #(.FPGA_TECHNOLOGY(1),.IO_DELAY_GROUP("STAGE1_ORACLE")) oracle (
        .rx_clk_in_p(rx_clk),.rx_clk_in_n(~rx_clk),
        .rx_frame_in_p(frame),.rx_frame_in_n(~frame),
        .rx_data_in_p(data),.rx_data_in_n(~data),.l_clk(),.clk(clk),.rst(1'b0),
        .adc_r1_mode(R1_MODE!=0),.adc_ddr_edgesel(1'b0),
        .adc_valid(oracle_valid),.adc_data(oracle_iq),.adc_status(oracle_status),
        .tx_clk_out_p(),.tx_clk_out_n(),.tx_frame_out_p(),.tx_frame_out_n(),
        .tx_data_out_p(),.tx_data_out_n(),.enable(),.txnrx(),
        .dac_valid(1'b0),.dac_data(48'd0),.dac_clksel(1'b0),.dac_r1_mode(1'b0),
        .tdd_enable(1'b0),.tdd_txnrx(1'b0),.tdd_mode(1'b0),.mmcm_rst(1'b0),
        .up_clk(up_clk),.up_rstn(1'b1),.up_enable(1'b0),.up_txnrx(1'b0),
        .up_adc_dld(load),.up_adc_dwdata(taps),.up_adc_drdata(oracle_readback),
        .up_dac_dld(10'd0),.up_dac_dwdata(50'd0),.up_dac_drdata(),
        .delay_clk(ref_clk),.delay_rst(delay_rst),.delay_locked(oracle_locked),
        .up_drp_sel(1'b0),.up_drp_wr(1'b0),.up_drp_addr(12'd0),.up_drp_wdata(32'd0),
        .up_drp_rdata(),.up_drp_ready(),.up_drp_locked());

    integer oracle_checks=0,tuple_checks=0,cycles=0,last_tuple_cycle=-1;
    integer next_index=-1,status_lows=0;
    reg score=0;
    // Upstream comparison includes startup, tap loads and invalid frames.
    always @(negedge rx_clk) begin
        #0.1;
        cycles=cycles+1;
        if({valid,iq,status,locked,readback} !==
           {oracle_valid,oracle_iq,oracle_status,oracle_locked,oracle_readback})
            $fatal(1,"RX-only extraction differs from unmodified ADI interface");
        oracle_checks=oracle_checks+1;
        if(locked && !status)status_lows=status_lows+1;
        if(score && valid) begin : check_known_tuple
            reg [11:0] n;
            reg [47:0] expected;
            n=iq[11:0];
            expected=R1_MODE ? {24'd0,(n^12'h800),n} :
                {(n^12'ha55),(~n),(n^12'h800),n};
            if(iq!==expected)$fatal(1,"Known IQ ordering/bit reconstruction failed: %h expected %h",iq,expected);
            if(next_index>=0 && n!==next_index[11:0])$fatal(1,"Missing or repeated IQ tuple");
            if(last_tuple_cycle>=0 && cycles-last_tuple_cycle!=(R1_MODE?2:4))
                $fatal(1,"Wrong valid cadence: %0d cycles",cycles-last_tuple_cycle);
            if(!status)$fatal(1,"Clean source reports invalid FRAME");
            next_index=(n+1)%4096;last_tuple_cycle=cycles;tuple_checks=tuple_checks+1;
        end
    end

    // Model AD9361's edge-aligned output: data switches after DATA_CLK;
    // the receiver must pair the preceding falling/rising samples correctly.
    task automatic send_pair(input [5:0] i,input [5:0] q,input bit f,input bit bad);
        @(posedge rx_clk);#0.2;data=i;frame=f;
        @(negedge rx_clk);#0.2;data=q;frame=bad?!f:f;
    endtask
    task automatic send_sample(input integer index,input bit bad);
        reg [11:0] a,b,c,d;
        a=index;b=a^12'h800;c=~a;d=a^12'ha55;
        send_pair(a[11:6],b[11:6],1,0);
        send_pair(a[5:0],b[5:0],R1_MODE?0:1,bad);
        if(!R1_MODE) begin
            send_pair(c[11:6],d[11:6],0,0);
            send_pair(c[5:0],d[5:0],0,0);
        end
    endtask
    task automatic load_taps(input integer value);
        @(negedge up_clk);
        for(integer lane=0;lane<7;lane=lane+1)taps[lane*5+:5]=(value+lane)%32;
        load=7'h7f;@(negedge up_clk);load=0;repeat(2)@(negedge up_clk);
        if(readback!==taps)$fatal(1,"Seven independently loaded delays did not read back");
    endtask

    integer low_before,stopped_cycles;
    initial begin
        #600;delay_rst=0;wait(locked);#1000;
        load_taps(0);load_taps(5);load_taps(25);load_taps(31);
        @(negedge up_clk);taps=0;load=7'h7f;
        @(negedge up_clk);load=0;
        // Warm up the two registered frame/data stages before scoring.
        for(integer n=0;n<16;n=n+1)send_sample(n,0);
        score=1;
        for(integer n=16;n<1040;n=n+1)send_sample(n,0);
        score=0;
        if(tuple_checks<1020)$fatal(1,"Insufficient independent known-data checks");
        $display("PASS: 1024 known IQ tuples, exact valid cadence, upstream cycle equivalence");
        low_before=status_lows;
        send_sample(1040,1);
        for(integer n=1041;n<1057;n=n+1)send_sample(n,0);
        if(status_lows<=low_before)$fatal(1,"Corrupt DDR FRAME was not reported");
        if(!status)$fatal(1,"FRAME status did not recover on clean data");
        $display("PASS: raw FRAME corruption detected and status recovers");
        delay_rst=1;repeat(32)@(negedge rx_clk);
        if(status || locked)$fatal(1,"IDELAY reset did not invalidate status");
        delay_rst=0;wait(locked);repeat(8)@(negedge rx_clk);
        if(!status)$fatal(1,"IDELAY readiness did not recover");
        $display("PASS: seven delay controls/readback and IDELAY reset/recovery");
        @(negedge rx_clk);#0.3;running=0;stopped_cycles=cycles;#1000;
        if(cycles!=stopped_cycles)$fatal(1,"Receive pipeline advanced without DATA_CLK");
        $display("AD9361_RX_STAGE1_PASS R1=%0d HALF_NS=%0.4f ORACLE=%0d TUPLES=%0d",
                 R1_MODE,RX_HALF_PERIOD_NS,oracle_checks,tuple_checks);
        $finish;
    end
    initial begin #300000;$fatal(1,"Stage 1 timed out");end
endmodule
