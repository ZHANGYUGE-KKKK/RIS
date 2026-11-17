`timescale 1ns / 1ps

// PS SPI master through EMIO. Keep the PS output-enable signals at the pads.
module rfmc_spi_io (
    input wire sclk_o, input wire sclk_t, output wire sclk_i,
    input wire mosi_o, input wire mosi_t, output wire mosi_i,
    input wire ss_o, input wire ss_t,
    input wire rf_spi_miso, output wire miso_i,
    output wire rf_spi_sclk, output wire rf_spi_mosi,
    output wire rf_spi_csn
);
    OBUFT sclk_buf (.I(sclk_o), .T(sclk_t), .O(rf_spi_sclk));
    OBUFT mosi_buf (.I(mosi_o), .T(mosi_t), .O(rf_spi_mosi));
    OBUFT cs_buf   (.I(ss_o),   .T(ss_t),   .O(rf_spi_csn));
    assign sclk_i = sclk_o;
    assign mosi_i = mosi_o;
    assign miso_i = rf_spi_miso;
endmodule
