// ZC706 FMC_LPC clock and DATA pin smoke test, xc7z045ffg900-2.
// For FPGA implementation verification: all 20 outputs forward SYSCLK.
// This is not the shift/latch transaction protocol for the daughterboard.
module ris_clock_test (
    input wire sysclk_p,
    input wire sysclk_n,
    output wire SHIFT_CLK1,
    output wire LATCH_CLK1,
    output wire SHIFT_CLK2,
    output wire LATCH_CLK2,
    output wire SHIFT_CLK3,
    output wire LATCH_CLK3,
    output wire SHIFT_CLK4,
    output wire LATCH_CLK4,
    output wire SHIFT_CLK5,
    output wire LATCH_CLK5,
    output wire SHIFT_CLK6,
    output wire LATCH_CLK6,
    output wire SHIFT_CLK7,
    output wire LATCH_CLK7,
    output wire SHIFT_CLK8,
    output wire LATCH_CLK8,
    output wire SHIFT_CLK9,
    output wire LATCH_CLK9,
    output wire SHIFT_CLK10,
    output wire LATCH_CLK10,
    output wire DATA_U01,
    output wire DATA_U02,
    output wire DATA_U03,
    output wire DATA_U04,
    output wire DATA_U05,
    output wire DATA_U06,
    output wire DATA_U07,
    output wire DATA_U08,
    output wire DATA_U09,
    output wire DATA_U10,
    output wire DATA_U11,
    output wire DATA_U12,
    output wire DATA_U13,
    output wire DATA_U14,
    output wire DATA_U15,
    output wire DATA_U16,
    output wire DATA_U17,
    output wire DATA_U18,
    output wire DATA_U19,
    output wire DATA_U20,
    output wire DATA_U21,
    output wire DATA_U22,
    output wire DATA_U23,
    output wire DATA_U24,
    output wire DATA_U25,
    output wire DATA_U26,
    output wire DATA_U27,
    output wire DATA_U28,
    output wire DATA_U29,
    output wire DATA_U30,
    output wire DATA_U31,
    output wire DATA_U32,
    output wire DATA_U33,
    output wire DATA_U34,
    output wire DATA_U35,
    output wire DATA_U36,
    output wire DATA_U37,
    output wire DATA_U38,
    output wire DATA_U39,
    output wire DATA_U40,
    output wire DATA_U41,
    output wire DATA_U42,
    output wire DATA_U43,
    output wire DATA_U44,
    output wire DATA_U45,
    output wire DATA_U46,
    output wire DATA_U47,
    output wire DATA_U48,
    output wire DATA_U49,
    output wire DATA_U50
);
    wire clk_input;
    wire clk_global;
    wire [19:0] forwarded_clocks;

    IBUFDS u_sysclk_input (
        .I(sysclk_p),
        .IB(sysclk_n),
        .O(clk_input)
    );

    BUFG u_sysclk_global (
        .I(clk_input),
        .O(clk_global)
    );

    // Each pad gets its own output DDR register; P and N are independent
    // single-ended LVCMOS25 outputs, not an OBUFDS differential output.
    genvar i;
    generate
        for (i = 0; i < 20; i = i + 1) begin : gen_clock_output
            (* DONT_TOUCH = "TRUE" *)
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE"),
                .INIT(1'b0),
                .SRTYPE("SYNC")
            ) u_forward_clock (
                .Q(forwarded_clocks[i]),
                .C(clk_global),
                .CE(1'b1),
                .D1(1'b1),
                .D2(1'b0),
                .R(1'b0),
                .S(1'b0)
            );
        end
    endgenerate

    assign SHIFT_CLK1 = forwarded_clocks[0];
    assign LATCH_CLK1 = forwarded_clocks[1];
    assign SHIFT_CLK2 = forwarded_clocks[2];
    assign LATCH_CLK2 = forwarded_clocks[3];
    assign SHIFT_CLK3 = forwarded_clocks[4];
    assign LATCH_CLK3 = forwarded_clocks[5];
    assign SHIFT_CLK4 = forwarded_clocks[6];
    assign LATCH_CLK4 = forwarded_clocks[7];
    assign SHIFT_CLK5 = forwarded_clocks[8];
    assign LATCH_CLK5 = forwarded_clocks[9];
    assign SHIFT_CLK6 = forwarded_clocks[10];
    assign LATCH_CLK6 = forwarded_clocks[11];
    assign SHIFT_CLK7 = forwarded_clocks[12];
    assign LATCH_CLK7 = forwarded_clocks[13];
    assign SHIFT_CLK8 = forwarded_clocks[14];
    assign LATCH_CLK8 = forwarded_clocks[15];
    assign SHIFT_CLK9 = forwarded_clocks[16];
    assign LATCH_CLK9 = forwarded_clocks[17];
    assign SHIFT_CLK10 = forwarded_clocks[18];
    assign LATCH_CLK10 = forwarded_clocks[19];
    // Test-only data pattern; all 50 pads remain active output ports.
    // This counter does not implement the external 595 data protocol.
    reg [49:0] data_pattern = 50'd0;
    always @(posedge clk_global) begin
        data_pattern <= data_pattern + 50'd1;
    end
    assign DATA_U01 = data_pattern[0];
    assign DATA_U02 = data_pattern[1];
    assign DATA_U03 = data_pattern[2];
    assign DATA_U04 = data_pattern[3];
    assign DATA_U05 = data_pattern[4];
    assign DATA_U06 = data_pattern[5];
    assign DATA_U07 = data_pattern[6];
    assign DATA_U08 = data_pattern[7];
    assign DATA_U09 = data_pattern[8];
    assign DATA_U10 = data_pattern[9];
    assign DATA_U11 = data_pattern[10];
    assign DATA_U12 = data_pattern[11];
    assign DATA_U13 = data_pattern[12];
    assign DATA_U14 = data_pattern[13];
    assign DATA_U15 = data_pattern[14];
    assign DATA_U16 = data_pattern[15];
    assign DATA_U17 = data_pattern[16];
    assign DATA_U18 = data_pattern[17];
    assign DATA_U19 = data_pattern[18];
    assign DATA_U20 = data_pattern[19];
    assign DATA_U21 = data_pattern[20];
    assign DATA_U22 = data_pattern[21];
    assign DATA_U23 = data_pattern[22];
    assign DATA_U24 = data_pattern[23];
    assign DATA_U25 = data_pattern[24];
    assign DATA_U26 = data_pattern[25];
    assign DATA_U27 = data_pattern[26];
    assign DATA_U28 = data_pattern[27];
    assign DATA_U29 = data_pattern[28];
    assign DATA_U30 = data_pattern[29];
    assign DATA_U31 = data_pattern[30];
    assign DATA_U32 = data_pattern[31];
    assign DATA_U33 = data_pattern[32];
    assign DATA_U34 = data_pattern[33];
    assign DATA_U35 = data_pattern[34];
    assign DATA_U36 = data_pattern[35];
    assign DATA_U37 = data_pattern[36];
    assign DATA_U38 = data_pattern[37];
    assign DATA_U39 = data_pattern[38];
    assign DATA_U40 = data_pattern[39];
    assign DATA_U41 = data_pattern[40];
    assign DATA_U42 = data_pattern[41];
    assign DATA_U43 = data_pattern[42];
    assign DATA_U44 = data_pattern[43];
    assign DATA_U45 = data_pattern[44];
    assign DATA_U46 = data_pattern[45];
    assign DATA_U47 = data_pattern[46];
    assign DATA_U48 = data_pattern[47];
    assign DATA_U49 = data_pattern[48];
    assign DATA_U50 = data_pattern[49];
endmodule
