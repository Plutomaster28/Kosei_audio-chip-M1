`timescale 1ns/1ps
module tb_digital_frontend;
    reg clk=0, rst_n=0; always #5 clk=~clk;
    reg [1:0] input_sel; reg i2s_bclk=0,i2s_lrclk=0,i2s_sd=0; reg spdif_in=0, usb_dp=0, usb_dm=0;
    reg test_valid; reg [23:0] test_l, test_r; wire pcm_valid; wire [23:0] pcm_l, pcm_r;
    digital_frontend u(.clk(clk),.rst_n(rst_n),.input_sel(input_sel),.i2s_bclk(i2s_bclk),.i2s_lrclk(i2s_lrclk),.i2s_sd(i2s_sd),.spdif_in(spdif_in),.usb_dp(usb_dp),.usb_dm(usb_dm),.test_valid(test_valid),.test_l(test_l),.test_r(test_r),.pcm_valid(pcm_valid),.pcm_l(pcm_l),.pcm_r(pcm_r));
    initial begin
        rst_n=0; input_sel=0; test_valid=0; test_l=0; test_r=0; #50 rst_n=1;
        // test mode
        repeat(10) begin @(posedge clk); test_valid=1; test_l=test_l+24'd1; test_r=test_r-24'd1; end
        test_valid=0; input_sel=2'd1; // i2s
        repeat(10) begin @(posedge clk); i2s_lrclk=~i2s_lrclk; i2s_sd=$random; end
        $finish; end
endmodule
