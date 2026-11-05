`timescale 1ns/1ps
module tb_ddr_bist;
    reg aclk=0; always #3 aclk=~aclk;
    reg aresetn=0, calib_complete=1, mmcm_locked=1, ui_reset=0;
    reg [31:0] command=0;
    wire [31:0] status,first_bad_address,first_expected,first_actual,error_words;
    wire [30:0] awaddr, araddr;
    wire [0:0] awid,arid;
    wire [7:0] awlen,arlen;
    wire [2:0] awsize,arsize,awprot,arprot;
    wire [1:0] awburst,arburst;
    wire awlock,arlock;
    wire [3:0] awcache,arcache;
    wire awvalid,wvalid,wlast,bready,arvalid,rready;
    wire [511:0] wdata;
    wire [63:0] wstrb;
    reg awready=0,wready=0,arready=0,bvalid=0,rvalid=0;
    reg [1:0] bresp=0,rresp=0;
    reg [511:0] rdata=0;
    ddr_bist #(.FULL_BYTES(2048),.QUICK_BYTES(256)) dut (
        .aclk(aclk),.aresetn(aresetn),.command(command),
        .calib_complete(calib_complete),.mmcm_locked(mmcm_locked),.ui_reset(ui_reset),
        .status(status),.first_bad_address(first_bad_address),.first_expected(first_expected),
        .first_actual(first_actual),.error_words(error_words),
        .m_axi_awaddr(awaddr),.m_axi_awid(awid),.m_axi_awlen(awlen),.m_axi_awsize(awsize),
        .m_axi_awburst(awburst),.m_axi_awlock(awlock),.m_axi_awcache(awcache),.m_axi_awprot(awprot),
        .m_axi_awvalid(awvalid),.m_axi_awready(awready),.m_axi_wdata(wdata),.m_axi_wstrb(wstrb),
        .m_axi_wlast(wlast),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bid(1'b0),.m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .m_axi_araddr(araddr),.m_axi_arid(arid),.m_axi_arlen(arlen),.m_axi_arsize(arsize),
        .m_axi_arburst(arburst),.m_axi_arlock(arlock),.m_axi_arcache(arcache),.m_axi_arprot(arprot),
        .m_axi_arvalid(arvalid),.m_axi_arready(arready),.m_axi_rid(1'b0),.m_axi_rdata(rdata),
        .m_axi_rresp(rresp),.m_axi_rlast(1'b1),.m_axi_rvalid(rvalid),.m_axi_rready(rready));

    reg [511:0] mem[0:31];
    integer cycle=0,writes=0,reads=0;
    integer b_delay=-1,r_delay=-1;
    reg [30:0] write_addr=0,read_addr=0;
    reg have_aw=0,inject_data=0,inject_bresp=0,inject_rresp=0,alias_upper=0;
    integer low_addr, high_addr;
    // Deterministic independent channel stalls; responses remain stable until accepted.
    always @(posedge aclk) begin
        cycle<=cycle+1;
        awready<=cycle%5==1; wready<=cycle%7==2; arready<=cycle%3==1;
        if (!aresetn) begin
            bvalid<=0; rvalid<=0; b_delay<=-1; r_delay<=-1; have_aw<=0;
        end else begin
            if (awvalid && awready) begin
                if (awlen!=0 || awsize!=6 || awburst!=1 || awaddr[5:0]!=0 || awaddr>=2048)
                    $fatal(1,"bad AW transaction");
                write_addr<=awaddr; have_aw<=1;
                if (awaddr<low_addr) low_addr=awaddr;
                if (awaddr>high_addr) high_addr=awaddr;
            end
            if (wvalid && wready) begin
                if (!have_aw || !wlast || wstrb!={64{1'b1}}) $fatal(1,"bad W transaction");
                mem[alias_upper ? (write_addr>>6)%16 : write_addr>>6]<=wdata;
                have_aw<=0; writes<=writes+1; b_delay<=3;
            end
            if (b_delay>0) b_delay<=b_delay-1;
            if (b_delay==0) begin bvalid<=1; bresp<=inject_bresp ? 2 : 0; b_delay<=-1; end
            if (bvalid && bready) bvalid<=0;
            if (arvalid && arready) begin
                if (arlen!=0 || arsize!=6 || arburst!=1 || araddr[5:0]!=0 || araddr>=2048)
                    $fatal(1,"bad AR transaction");
                read_addr<=araddr; r_delay<=4; reads<=reads+1;
            end
            if (r_delay>0) r_delay<=r_delay-1;
            if (r_delay==0) begin
                rdata<=mem[alias_upper ? (read_addr>>6)%16 : read_addr>>6] ^
                       ((inject_data && read_addr==128) ? 512'h1 : 512'h0);
                rresp<=inject_rresp ? 2 : 0; rvalid<=1; r_delay<=-1;
            end
            if (rvalid && rready) rvalid<=0;
        end
    end
    // AXI request payloads must not change under backpressure.
    reg aw_stall=0,w_stall=0,ar_stall=0;
    reg [30:0] old_aw,old_ar;
    reg [511:0] old_w;
    always @(posedge aclk) if (aresetn) begin
        if (aw_stall && (!awvalid || awaddr!==old_aw)) $fatal(1,"AW changed under stall");
        if (w_stall && (!wvalid || wdata!==old_w)) $fatal(1,"W changed under stall");
        if (ar_stall && (!arvalid || araddr!==old_ar)) $fatal(1,"AR changed under stall");
        aw_stall<=awvalid&&!awready; w_stall<=wvalid&&!wready; ar_stall<=arvalid&&!arready;
        old_aw<=awaddr; old_ar<=araddr; old_w<=wdata;
    end
    task run_test(input integer mode,input integer quick,input integer upper,
                  input integer expect_bad,input integer expected_writes,input integer expected_reads);
        integer w0,r0,timeout;
        begin
            @(negedge aclk); w0=writes;r0=reads;low_addr=32'h7fffffff;high_addr=0;
            command=(mode<<1)|(quick<<4)|(upper<<5)|((~command)&1);
            timeout=0;
            while (!status[0] && timeout<30) begin @(negedge aclk);timeout=timeout+1;end
            if (!status[0]) $fatal(1,"no command acceptance");
            timeout=0;
            while (!status[1] && timeout<5000) begin @(negedge aclk);timeout=timeout+1;end
            if (!status[1] || status[0]) $fatal(1,"test timeout");
            if (status[2] != expect_bad) $fatal(1,"bad verdict status=%h",status);
            if (writes-w0!=expected_writes || reads-r0!=expected_reads)
                $fatal(1,"coverage wrong writes=%0d reads=%0d",writes-w0,reads-r0);
            if (!expect_bad && (low_addr!=(upper?1024:0) || high_addr!=(quick?(upper?1216:192):1984)))
                $fatal(1,"wrong address bounds %h..%h",low_addr,high_addr);
            $display("CASE PASS mode=%0d quick=%0d upper=%0d expected_fault=%0d errors=%0d",mode,quick,upper,expect_bad,error_words);
        end
    endtask
    integer m;
    initial begin
        repeat(5) @(negedge aclk); aresetn=1;
        for (m=0;m<5;m=m+1) run_test(m,0,0,0,32,32);
        run_test(3,1,0,0,4,4); run_test(3,1,1,0,4,4);
        inject_data=1; run_test(3,0,0,1,32,32);
        if (error_words!=1 || first_bad_address!=128 || first_expected!=(128^32'h6d3a92c7) ||
            first_actual!=(first_expected^1)) $fatal(1,"incorrect first error report");
        inject_data=0; alias_upper=1; run_test(3,0,0,1,32,32);
        if (error_words!=256 || first_bad_address!=0) $fatal(1,"rank alias not detected");
        alias_upper=0; inject_bresp=1; run_test(0,0,0,1,1,0);
        if (!status[8]) $fatal(1,"B error not reported");
        inject_bresp=0; inject_rresp=1; run_test(0,0,0,1,32,1);
        if (!status[8]) $fatal(1,"R error not reported");
        inject_rresp=0; run_test(4,0,0,0,32,32);
        $display("DDR2G_BIST_SIM_PASS: 12 cases, stalls, corruption, rank alias, B/R errors, recovery");
        $finish;
    end
    initial begin #1000000; $fatal(1,"global watchdog"); end
endmodule
