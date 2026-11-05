`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/09 16:28:04
// Design Name: 
// Module Name: key_ctrl_55
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// GPIO configuration is synchronous to clk (AXI GPIO uses the same FCLK).
// gpio_cfg[31:29]: 100=key monitor, 101=PS values, 111=1 MHz auto.
// gpio_cfg[28:25]: reserved, ignored.
// gpio_cfg[24:0]: bit 0=out_1_1, bit 24=out_5_5, in row-major order.
// Monitor mode preserves the synchronized, debounced key-level behavior.
// Active-low asynchronous reset clears all outputs.
module key_ctrl_55 #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
) (
    input wire clk,
    input wire rst_n,
    input wire key,
    input wire [31:0] gpio_cfg,
    output wire out_1_1,
    output wire out_1_2,
    output wire out_1_3,
    output wire out_1_4,
    output wire out_1_5,
    output wire out_2_1,
    output wire out_2_2,
    output wire out_2_3,
    output wire out_2_4,
    output wire out_2_5,
    output wire out_3_1,
    output wire out_3_2,
    output wire out_3_3,
    output wire out_3_4,
    output wire out_3_5,
    output wire out_4_1,
    output wire out_4_2,
    output wire out_4_3,
    output wire out_4_4,
    output wire out_4_5,
    output wire out_5_1,
    output wire out_5_2,
    output wire out_5_3,
    output wire out_5_4,
    output wire out_5_5
);

    // Set CLK_FREQ_HZ to the actual input clock frequency.
    // Divide first to avoid overflow with typical FPGA clock frequencies.
    localparam integer RAW_DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam integer DEBOUNCE_CYCLES =
        (RAW_DEBOUNCE_CYCLES < 1) ? 1 : RAW_DEBOUNCE_CYCLES;
    localparam integer COUNTER_WIDTH =
        (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);

    localparam [2:0] MODE_MONITOR = 3'b100;
    localparam [2:0] MODE_PS      = 3'b101;
    localparam [2:0] MODE_AUTO    = 3'b111;
    // 1 MHz is a complete square-wave cycle: flip every 0.5 us.
    // CLK_FREQ_HZ must match clk and be a multiple of 2 MHz for exact timing.
    // At the board's 100 MHz clock, each half-period lasts 50 clock cycles.
    localparam integer RAW_AUTO_HALF_CYCLES = CLK_FREQ_HZ / 2_000_000;
    localparam integer AUTO_HALF_CYCLES =
        (RAW_AUTO_HALF_CYCLES < 1) ? 1 : RAW_AUTO_HALF_CYCLES;
    localparam integer AUTO_COUNTER_WIDTH =
        (AUTO_HALF_CYCLES <= 1) ? 1 : $clog2(AUTO_HALF_CYCLES);

    wire [2:0] mode = gpio_cfg[31:29];
    reg [24:0] output_state;
    reg [AUTO_COUNTER_WIDTH-1:0] auto_count;
    reg auto_level;
    reg auto_active;

    // Least significant bit drives the first output, out_1_1.
    assign {out_5_5, out_5_4, out_5_3, out_5_2, out_5_1,
            out_4_5, out_4_4, out_4_3, out_4_2, out_4_1,
            out_3_5, out_3_4, out_3_3, out_3_2, out_3_1,
            out_2_5, out_2_4, out_2_3, out_2_2, out_2_1,
            out_1_5, out_1_4, out_1_3, out_1_2, out_1_1} = output_state;

    (* ASYNC_REG = "TRUE" *) reg key_meta;
    (* ASYNC_REG = "TRUE" *) reg key_sync;
    reg key_debounced;
    reg [COUNTER_WIDTH-1:0] debounce_count;

//    ila_0 ila_0_1 (
//        .clk(clk),
//        .probe0(key_meta),
//        .probe1(out_1_1),
//        .probe2(out_1_2),
//        .probe3(out_1_3),
//        .probe4(out_1_4)
//    );

    // Two flip-flops bring the asynchronous button into the clk domain.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_meta <= 1'b0;
            key_sync <= 1'b0;
        end else begin
            key_meta <= key;
            key_sync <= key_meta;
        end
    end

    // Accept both rising and falling levels only after a stable interval.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_debounced <= 1'b0;
            debounce_count <= {COUNTER_WIDTH{1'b0}};
        end else if (key_sync == key_debounced) begin
            debounce_count <= {COUNTER_WIDTH{1'b0}};
        end else if (debounce_count == DEBOUNCE_CYCLES - 1) begin
            key_debounced <= key_sync;
            debounce_count <= {COUNTER_WIDTH{1'b0}};
        end else begin
            debounce_count <= debounce_count + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_state <= 25'b0;
            auto_count <= {AUTO_COUNTER_WIDTH{1'b0}};
            auto_level <= 1'b0;
            auto_active <= 1'b0;
        end else begin
            auto_active <= (mode == MODE_AUTO);
            if (mode != MODE_AUTO) begin
                auto_count <= {AUTO_COUNTER_WIDTH{1'b0}};
                auto_level <= 1'b0;
            end

            case (mode)
                MODE_MONITOR: output_state <= {25{key_debounced}};
                MODE_PS:      output_state <= gpio_cfg[24:0];
                MODE_AUTO: begin
                    if (!auto_active) begin
                        // Each entry into AUTO starts low with a full half-period.
                        auto_count <= {AUTO_COUNTER_WIDTH{1'b0}};
                        auto_level <= 1'b0;
                        output_state <= 25'b0;
                    end else if (auto_count == AUTO_HALF_CYCLES - 1) begin
                        auto_count <= {AUTO_COUNTER_WIDTH{1'b0}};
                        auto_level <= ~auto_level;
                        output_state <= {25{~auto_level}};
                    end else begin
                        auto_count <= auto_count + 1'b1;
                        output_state <= {25{auto_level}};
                    end
                end
                default: output_state <= 25'b0;
            endcase
        end
    end

endmodule
