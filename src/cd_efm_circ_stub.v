// CD input with EFM demodulation + CIRC error correction (stub)
`timescale 1ns/1ps
module cd_efm_circ_stub (
    input  wire clk,
    input  wire rst_n,
    input  wire cd_rf_in,           // raw EFM channel input (stub)
    output wire        pcm_valid,
    output wire [23:0] pcm_l,
    output wire [23:0] pcm_r,
    output wire        deemph_flag  // indicates pre-emphasis flagged
);
    assign pcm_valid = 1'b0;
    assign pcm_l = 24'd0;
    assign pcm_r = 24'd0;
    assign deemph_flag = 1'b0;
endmodule
