`timescale 1ns/1ps
`default_nettype none

// Reset-free, byte-write-enabled BRAM with independent synchronous read ports.
// Two identical copies provide one write plus two reads without a LUTRAM mux.
// Publication flags live in the controller; unused locations need no reset value.
module ris_frame_ram #(
    parameter integer WORDS=4096,
    parameter integer ADDR_WIDTH=$clog2(WORDS)
) (
    input wire clk, resetn, write_enable,
    input wire [ADDR_WIDTH-1:0] write_address, bus_address, play_address,
    input wire [31:0] write_data,
    input wire [3:0] write_strobe,
    output reg [31:0] bus_data, play_data
);
    // Register all write controls synchronously. The AXI bridge returns B before
    // accepting the next AW, so this single write stage drains before COMMIT.
    // A reset can finish an already accepted RAM write; publication flags reset
    // separately and prevent exposing partially written storage afterward.
    reg write_pending;
    reg [ADDR_WIDTH-1:0] pending_address;
    reg [31:0] pending_data;
    reg [3:0] pending_strobe;
    always @(posedge clk) begin
        if (!resetn) begin
            write_pending<=0; pending_address<=0; pending_data<=0; pending_strobe<=0;
        end else begin
            write_pending<=write_enable;
            pending_address<=write_address;
            pending_data<=write_data;
            pending_strobe<=write_strobe;
        end
    end
    genvar b;
    generate for (b=0;b<4;b=b+1) begin: byte_bank
        (* ram_style="block" *) reg [7:0] memory_bus [0:WORDS-1];
        (* ram_style="block" *) reg [7:0] memory_play [0:WORDS-1];
        always @(posedge clk) begin
            if (write_pending && pending_strobe[b]) begin
                memory_bus[pending_address]<=pending_data[b*8+:8];
                memory_play[pending_address]<=pending_data[b*8+:8];
            end
            bus_data[b*8+:8]<=memory_bus[bus_address];
            play_data[b*8+:8]<=memory_play[play_address];
        end
    end endgenerate
endmodule
`default_nettype wire
