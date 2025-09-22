// Stub: usb_to_i2s_lite expected by some flows; produce no output
`timescale 1ns/1ps
module usb_to_i2s_lite(
    input  wire clk,
    input  wire rst_n,
    input  wire usb_dp,
    input  wire usb_dm,
    output wire i2s_bclk,
    output wire i2s_lrclk,
    output wire i2s_sd
);
    assign i2s_bclk = 1'b0;
    assign i2s_lrclk = 1'b0;
    assign i2s_sd = 1'b0;
endmodule
