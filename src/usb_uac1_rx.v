// USB Audio Class 1.0 RX stub — placeholder
`timescale 1ns/1ps
module usb_uac1_rx(
    input  wire clk,
    input  wire rst_n,
    input  wire usb_dp,
    input  wire usb_dm,
    output wire        pcm_valid,
    output wire [23:0] pcm_l,
    output wire [23:0] pcm_r
);
    assign pcm_valid = 1'b0;
    assign pcm_l = 24'd0;
    assign pcm_r = 24'd0;
endmodule
