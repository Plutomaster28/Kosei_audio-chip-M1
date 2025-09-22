`timescale 1ns/1ps
module tb_dac_core;
    reg clk=0, rst_n=0; always #5 clk=~clk;
    reg in_valid; reg [23:0] in_l, in_r; wire sdm_out_l, sdm_out_r;
    dac_core u(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_l(in_l),.in_r(in_r),.sdm_out_l(sdm_out_l),.sdm_out_r(sdm_out_r));
    integer i;
    initial begin
        rst_n=0; in_valid=0; in_l=0; in_r=0; #50 rst_n=1;
        in_valid=1;
        for (i=0;i<200;i=i+1) begin @(posedge clk); in_l <= 24'sd500000; in_r <= -24'sd500000; end
        in_valid=0; repeat(20) @(posedge clk); $finish; end
endmodule
