`timescale 1ns/1ps
module tb_dsp_engine;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg in_valid; reg [23:0] in_l, in_r; reg [3:0] osr_sel; reg [15:0] volume_q15; reg soft_mute;
    wire out_valid; wire [23:0] out_l, out_r;
    dsp_engine u(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_l(in_l),.in_r(in_r),.osr_sel(osr_sel),.volume_q15(volume_q15),.soft_mute(soft_mute),.out_valid(out_valid),.out_l(out_l),.out_r(out_r));
    initial begin
        rst_n=0; in_valid=0; in_l=0; in_r=0; osr_sel=4'd1; volume_q15=16'h7FFF; soft_mute=0;
        #50 rst_n=1;
        repeat (8) begin @(posedge clk); in_valid=1; in_l=in_l+24'd100; in_r=in_r+24'd200; end
        in_valid=0; repeat(50) @(posedge clk);
        soft_mute=1; repeat(100) @(posedge clk);
        $finish; end
endmodule
