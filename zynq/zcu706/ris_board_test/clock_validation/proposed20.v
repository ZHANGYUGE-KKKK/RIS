module clock_probe(input sysclk_p, input sysclk_n,
output LATCH_CLK1,
output SHIFT_CLK1,
output LATCH_CLK2,
output SHIFT_CLK2,
output LATCH_CLK3,
output SHIFT_CLK3,
output LATCH_CLK4,
output SHIFT_CLK4,
output LATCH_CLK5,
output SHIFT_CLK5,
output LATCH_CLK6,
output SHIFT_CLK6,
output LATCH_CLK7,
output SHIFT_CLK7,
output LATCH_CLK8,
output SHIFT_CLK8,
output LATCH_CLK9,
output SHIFT_CLK9,
output LATCH_CLK10,
output SHIFT_CLK10);
wire clk_ibuf,clk;
IBUFDS ib (.I(sysclk_p),.IB(sysclk_n),.O(clk_ibuf));
BUFG bg (.I(clk_ibuf),.O(clk));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK1 (.Q(LATCH_CLK1), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK1 (.Q(SHIFT_CLK1), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK2 (.Q(LATCH_CLK2), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK2 (.Q(SHIFT_CLK2), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK3 (.Q(LATCH_CLK3), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK3 (.Q(SHIFT_CLK3), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK4 (.Q(LATCH_CLK4), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK4 (.Q(SHIFT_CLK4), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK5 (.Q(LATCH_CLK5), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK5 (.Q(SHIFT_CLK5), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK6 (.Q(LATCH_CLK6), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK6 (.Q(SHIFT_CLK6), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK7 (.Q(LATCH_CLK7), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK7 (.Q(SHIFT_CLK7), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK8 (.Q(LATCH_CLK8), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK8 (.Q(SHIFT_CLK8), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK9 (.Q(LATCH_CLK9), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK9 (.Q(SHIFT_CLK9), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_LATCH_CLK10 (.Q(LATCH_CLK10), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) od_SHIFT_CLK10 (.Q(SHIFT_CLK10), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
endmodule
