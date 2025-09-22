// Clock and Jitter Management Stub
// Placeholder for high-precision PLL, jitter attenuation, and clock selection
`timescale 1ns/1ps
module clock_mgr_stub (
    input  wire clk_in,
    input  wire rst_n,
    input  wire ext_mclk,
    input  wire sel_ext,      // 1: use ext_mclk, 0: use clk_in
    output wire clk_out,
    output wire locked,
    output wire [15:0] jitter_metric
);
    assign clk_out = sel_ext ? ext_mclk : clk_in;
    assign locked = 1'b1;
    assign jitter_metric = 16'd0;
endmodule
