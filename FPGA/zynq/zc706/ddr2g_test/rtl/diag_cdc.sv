// Bundled diagnostic records are only interpreted after the delayed DONE bit.
module diag_cdc (
    input wire clk, resetn,
    input wire [31:0] status_async, address_async, expected_async, actual_async, errors_async,
    output wire [31:0] status,
    output wire [31:0] address, expected, actual, errors
);
    (* ASYNC_REG="TRUE" *) reg [159:0] meta, sync;
    (* ASYNC_REG="TRUE" *) reg done_meta, done_sync, done_delayed;
    always @(posedge clk) begin
        if (!resetn) begin
            meta<=0; sync<=0; done_meta<=0; done_sync<=0; done_delayed<=0;
        end else begin
            meta<={errors_async,actual_async,expected_async,address_async,status_async};
            sync<=meta;
            done_meta<=status_async[1]; done_sync<=done_meta; done_delayed<=done_sync;
        end
    end
    assign status={sync[31:2],done_delayed,sync[0]};
    assign address=sync[63:32], expected=sync[95:64];
    assign actual=sync[127:96], errors=sync[159:128];
endmodule
