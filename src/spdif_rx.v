// S/PDIF Receiver stub — replace with a real decoder later
`timescale 1ns/1ps
module spdif_rx(
    input  wire clk,
    input  wire rst_n,
    input  wire spdif_in,
    output wire        pcm_valid,
    output wire [23:0] pcm_l,
    output wire [23:0] pcm_r
);
    assign pcm_valid = 1'b0;
    assign pcm_l = 24'd0;
    assign pcm_r = 24'd0;
endmodule
