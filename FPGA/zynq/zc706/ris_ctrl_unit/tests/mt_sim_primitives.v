`timescale 1ns/1fs
// Functional-only Icarus models for the fixed 100->300 MHz clock and IOB DDR.
// No device delay/setup/hold model: implementation timing is checked by Vivado.
module BUFG(input I, output O); assign O=I; endmodule
module MMCME2_BASE #(
    parameter CLKIN1_PERIOD=10.0, CLKFBOUT_MULT_F=6.0, DIVCLK_DIVIDE=1,
    CLKOUT0_DIVIDE_F=2.0, STARTUP_WAIT="FALSE"
) (input CLKIN1, CLKFBIN, PWRDWN, RST, output CLKFBOUT,
   output reg CLKOUT0=0, output reg LOCKED=0);
    localparam real HALF=CLKIN1_PERIOD*DIVCLK_DIVIDE*CLKOUT0_DIVIDE_F/CLKFBOUT_MULT_F/2;
    assign CLKFBOUT=CLKIN1;
    always #(HALF) CLKOUT0=~CLKOUT0;
    integer stable=0;
    always @(posedge CLKIN1 or posedge RST) begin
        if (RST || PWRDWN) begin stable=0;LOCKED<=0;end
        else begin stable=stable+1;if(stable>=12)LOCKED<=1;end
    end
endmodule
module ODDR #(parameter DDR_CLK_EDGE="SAME_EDGE", SRTYPE="ASYNC")
    (input C,CE,D1,D2,R,S, output reg Q=0);
    reg second=0;
    always @(posedge C or posedge R or posedge S) begin
        if(R)begin Q<=0;second<=0;end
        else if(S)begin Q<=1;second<=1;end
        else if(CE)begin Q<=D1;second<=D2;end
    end
    always @(negedge C) if(!R && !S && CE) Q<=second;
endmodule
