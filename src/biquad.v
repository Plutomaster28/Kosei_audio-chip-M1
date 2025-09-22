// Biquad IIR filter (Direct Form I, transposed) for audio, 24-bit data, Q1.15 coeffs
`timescale 1ns/1ps
module biquad (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_sample,
    input  wire signed [15:0] b0,
    input  wire signed [15:0] b1,
    input  wire signed [15:0] b2,
    input  wire signed [15:0] a1,
    input  wire signed [15:0] a2,
    output reg         out_valid,
    output reg  [23:0] out_sample
);
    // DF1 transposed state
    reg signed [39:0] s1, s2; // internal states
    wire signed [24:0] x = {in_sample[23], in_sample};

    // y = b0*x + s1; s1' = b1*x - a1*y + s2; s2' = b2*x - a2*y
    wire signed [40:0] b0x = $signed({1'b0,b0}) * x;  // Q1.15 * Q1.23 -> Q2.38
    wire signed [40:0] b1x = $signed({1'b0,b1}) * x;
    wire signed [40:0] b2x = $signed({1'b0,b2}) * x;

    wire signed [39:0] y_acc = (b0x >>> 15) + s1; // align back to Q1.23
    wire signed [40:0] a1y = $signed({1'b0,a1}) * (y_acc >>> 0);
    wire signed [40:0] a2y = $signed({1'b0,a2}) * (y_acc >>> 0);

    wire signed [39:0] s1_n = (b1x >>> 15) - (a1y >>> 15) + s2;
    wire signed [39:0] s2_n = (b2x >>> 15) - (a2y >>> 15);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin s1<=0; s2<=0; out_valid<=1'b0; out_sample<=24'd0; end
        else begin
            out_valid <= in_valid;
            if (in_valid) begin
                s1 <= s1_n;
                s2 <= s2_n;
                out_sample <= y_acc[39:16];
            end
        end
    end
endmodule
