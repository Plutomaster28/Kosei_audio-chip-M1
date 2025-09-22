// Balance and Crossfeed DSP stage
`timescale 1ns/1ps
module balance_crossfeed (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_l,
    input  wire [23:0] in_r,
    input  wire signed [15:0] balance_q15,  // -1.0..+1.0: <0 shift to L, >0 shift to R
    input  wire [15:0] crossfeed_q15,       // 0..1.0 feed amount from opposite channel
    output reg         out_valid,
    output reg  [23:0] out_l,
    output reg  [23:0] out_r
);
    // Apply balance by scaling channels inversely
    // gL = 1 - max(0,balance); gR = 1 + min(0,balance) in Q1.15
    wire signed [16:0] one_q15 = 17'sd32767; // 1.0 in Q1.15
    wire signed [16:0] bal = {balance_q15[15], balance_q15};
    wire signed [16:0] bal_pos = (bal > 0) ? bal : 17'sd0;
    wire signed [16:0] bal_neg = (bal < 0) ? -bal : 17'sd0;
    wire signed [16:0] gL = one_q15 - bal_pos; // reduce L when balance positive to R
    wire signed [16:0] gR = one_q15 - bal_neg; // reduce R when balance negative to L

    // Crossfeed: L' = gL*L + c*R; R' = gR*R + c*L
    wire signed [24:0] sL = {in_l[23], in_l};
    wire signed [24:0] sR = {in_r[23], in_r};
    wire signed [40:0] L_scaled = sL * gL;
    wire signed [40:0] R_scaled = sR * gR;
    wire signed [40:0] L_xfeed  = sR * $signed({1'b0,crossfeed_q15});
    wire signed [40:0] R_xfeed  = sL * $signed({1'b0,crossfeed_q15});
    wire signed [23:0] L_out = (L_scaled + L_xfeed) >>> 15;
    wire signed [23:0] R_out = (R_scaled + R_xfeed) >>> 15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin out_valid<=1'b0; out_l<=24'd0; out_r<=24'd0; end
        else begin
            out_valid <= in_valid;
            if (in_valid) begin out_l <= L_out; out_r <= R_out; end
        end
    end
endmodule
