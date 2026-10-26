// Single-outstanding AXI4 memory test. No DMA or RF dependencies.
module ddr_bist #(
    parameter [31:0] FULL_BYTES = 32'h80000000,
    parameter [31:0] QUICK_BYTES = 32'h00800000
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK", X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXI, ASSOCIATED_RESET aresetn" *)
    input wire aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST", X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire aresetn,
    input wire [31:0] command,
    input wire calib_complete, mmcm_locked, ui_reset,
    output wire [31:0] status,
    output reg [31:0] first_bad_address,
    output reg [31:0] first_expected,
    output reg [31:0] first_actual,
    output reg [31:0] error_words,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR", X_INTERFACE_PARAMETER = "PROTOCOL AXI4, DATA_WIDTH 512, ADDR_WIDTH 31, ID_WIDTH 1, MAX_BURST_LENGTH 1, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1" *)
    output wire [30:0] m_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWID" *)
    output wire [0:0] m_axi_awid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *)
    output wire [7:0] m_axi_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *)
    output wire [2:0] m_axi_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *)
    output wire [1:0] m_axi_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLOCK" *)
    output wire m_axi_awlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWCACHE" *)
    output wire [3:0] m_axi_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)
    output wire [2:0] m_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
    output wire m_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
    input wire m_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
    output wire [511:0] m_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
    output wire [63:0] m_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WLAST" *)
    output wire m_axi_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
    output wire m_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
    input wire m_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BID" *)
    input wire [0:0] m_axi_bid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
    input wire [1:0] m_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
    input wire m_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
    output wire m_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
    output wire [30:0] m_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARID" *)
    output wire [0:0] m_axi_arid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *)
    output wire [7:0] m_axi_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *)
    output wire [2:0] m_axi_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *)
    output wire [1:0] m_axi_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLOCK" *)
    output wire m_axi_arlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARCACHE" *)
    output wire [3:0] m_axi_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *)
    output wire [2:0] m_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
    output wire m_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
    input wire m_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RID" *)
    input wire [0:0] m_axi_rid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
    input wire [511:0] m_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)
    input wire [1:0] m_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RLAST" *)
    input wire m_axi_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
    input wire m_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
    output wire m_axi_rready
);
    localparam IDLE=0, WRITE_ADDR=1, WRITE_DATA=2, WRITE_RESP=3,
               READ_ADDR=4, READ_DATA=5;
    reg [3:0] state;
    reg [31:0] address, start_address, last_address;
    reg [2:0] pattern;
    reg busy, done, bus_error, seen;
    (* ASYNC_REG = "TRUE" *) reg [31:0] command_meta, command_sync;
    (* ASYNC_REG = "TRUE" *) reg start_meta, start_sync, start_delay;
    wire ready = calib_complete && mmcm_locked && !ui_reset;
    wire event_start = start_delay != seen;

    function automatic [31:0] word_pattern(input [31:0] addr,
                                           input integer lane,
                                           input [2:0] mode);
        reg [31:0] x;
        begin
            // All transfers are 64-byte aligned: concatenate the word offset
            // instead of building sixteen redundant 32-bit address adders.
            x = {addr[31:6],6'b0} | (lane*4);
            case (mode)
                0: word_pattern = 32'h00000000;
                1: word_pattern = 32'hffffffff;
                2: word_pattern = 32'haa55aa55;
                3: word_pattern = x ^ 32'h6d3a92c7;
                default: word_pattern = ~(x ^ 32'h6d3a92c7);
            endcase
        end
    endfunction

    genvar g;
    generate for (g=0; g<16; g=g+1) begin: GEN_WORD
        assign m_axi_wdata[g*32+:32] = word_pattern(address,g,pattern);
    end endgenerate
    assign m_axi_awaddr=address[30:0], m_axi_araddr=address[30:0];
    assign m_axi_awid=0, m_axi_arid=0;
    assign m_axi_awlen=0, m_axi_arlen=0;
    assign m_axi_awsize=6, m_axi_arsize=6;
    assign m_axi_awburst=1, m_axi_arburst=1;
    assign m_axi_awlock=0, m_axi_arlock=0;
    assign m_axi_awcache=0, m_axi_arcache=0;
    assign m_axi_awprot=0, m_axi_arprot=0;
    assign m_axi_wstrb={64{1'b1}}, m_axi_wlast=1;
    assign m_axi_awvalid=(state==WRITE_ADDR);
    assign m_axi_wvalid=(state==WRITE_DATA);
    assign m_axi_bready=(state==WRITE_RESP);
    assign m_axi_arvalid=(state==READ_ADDR);
    assign m_axi_rready=(state==READ_DATA);
    reg [31:0] status_snapshot;
    always @(posedge aclk) begin
        if (!aresetn) status_snapshot<=0;
        else status_snapshot <= {4'ha,seen,address[30:20],state,ui_reset,mmcm_locked,
                          calib_complete,bus_error,(state==READ_ADDR || state==READ_DATA),
                          pattern,ready,(bus_error || error_words!=0),done,busy};
    end
    assign status = status_snapshot;

    integer i;
    reg [4:0] mismatches;
    reg [31:0] mismatch_addr, mismatch_expected, mismatch_actual;
    always @* begin
        mismatches=0; mismatch_addr=32'hffffffff;
        mismatch_expected=0; mismatch_actual=0;
        for (i=0;i<16;i=i+1) begin
            if (m_axi_rdata[i*32+:32] != word_pattern(address,i,pattern)) begin
                if (mismatches==0) begin
                    mismatch_addr={address[31:6],6'b0} | (i*4);
                    mismatch_expected=word_pattern(address,i,pattern);
                    mismatch_actual=m_axi_rdata[i*32+:32];
                end
                mismatches=mismatches+1'b1;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            command_meta<=0; command_sync<=0;
            start_meta<=0; start_sync<=0; start_delay<=0;
        end else begin
            command_meta<=command; command_sync<=command_meta;
            start_meta<=command[0]; start_sync<=start_meta; start_delay<=start_sync;
        end
    end
    always @(posedge aclk) begin
        if (!aresetn) begin
            state<=IDLE; address<=0; start_address<=0; last_address<=0;
            pattern<=0; busy<=0; done<=0; bus_error<=0; seen<=0;
            error_words<=0; first_bad_address<=32'hffffffff;
            first_expected<=0; first_actual<=0;
        end else begin
            // Commands must only change after the preceding test completes.
            if (event_start) seen<=start_delay;
            case (state)
                IDLE: if (event_start && ready) begin
                    pattern<=command_sync[3:1]; busy<=1; done<=0; bus_error<=0;
                    error_words<=0; first_bad_address<=32'hffffffff;
                    first_expected<=0; first_actual<=0;
                    if (command_sync[4]) begin
                        start_address<=command_sync[5] ? FULL_BYTES/2 : 0;
                        address<=command_sync[5] ? FULL_BYTES/2 : 0;
                        last_address<=(command_sync[5] ? FULL_BYTES/2 : 0)+QUICK_BYTES-64;
                    end else begin
                        start_address<=0; address<=0; last_address<=FULL_BYTES-64;
                    end
                    state<=WRITE_ADDR;
                end
                WRITE_ADDR: if (m_axi_awready) state<=WRITE_DATA;
                WRITE_DATA: if (m_axi_wready) state<=WRITE_RESP;
                WRITE_RESP: if (m_axi_bvalid) begin
                    if (m_axi_bresp!=0 || m_axi_bid!=0) begin
                        bus_error<=1; first_bad_address<=address;
                        first_actual<={30'b0,m_axi_bresp};
                        busy<=0; done<=1; state<=IDLE;
                    end else if (address==last_address) begin
                        address<=start_address; state<=READ_ADDR;
                    end else begin address<=address+64; state<=WRITE_ADDR; end
                end
                READ_ADDR: if (m_axi_arready) state<=READ_DATA;
                READ_DATA: if (m_axi_rvalid) begin
                    if (m_axi_rresp!=0 || m_axi_rid!=0 || !m_axi_rlast) begin
                        bus_error<=1; first_bad_address<=address;
                        first_actual<={29'b0,m_axi_rlast,m_axi_rresp};
                        busy<=0; done<=1; state<=IDLE;
                    end else begin
                        if (mismatches!=0) begin
                            error_words<=error_words+mismatches;
                            if (error_words==0) begin
                                first_bad_address<=mismatch_addr;
                                first_expected<=mismatch_expected;
                                first_actual<=mismatch_actual;
                            end
                        end
                        if (address==last_address) begin
                            busy<=0; done<=1; state<=IDLE;
                        end else begin address<=address+64; state<=READ_ADDR; end
                    end
                end
                default: begin state<=IDLE; busy<=0; end
            endcase
        end
    end
endmodule
