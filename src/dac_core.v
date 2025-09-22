// DAC Core
// Provides simple single-bit first-order sigma-delta modulators for L/R.
// In silicon, this would feed analog reconstruction; here it's a digital stub.
`timescale 1ns/1ps

module dac_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_l,
    input  wire [23:0] in_r,
    input  wire        mode_multibit,   // 0: 1-bit, 1: multi-bit (placeholder)
    input  wire [11:0] trim_l,          // calibration trims (placeholder)
    input  wire [11:0] trim_r,
    output reg         sdm_out_l,
    output reg         sdm_out_r
);
    // Simple second-order single-loop 1-bit modulator per channel
    // y[n] = sign(v2)
    // v1[n+1] = v1[n] + (x[n] - y[n])
    // v2[n+1] = v2[n] + v1[n+1]
    reg signed [25:0] v1_l, v2_l, v1_r, v2_r; // widen by a couple bits
    // Apply simple trim offset (scaled down)
    wire signed [24:0] x_l = {in_l[23], in_l} + $signed({{13{trim_l[11]}}, trim_l});
    wire signed [24:0] x_r = {in_r[23], in_r} + $signed({{13{trim_r[11]}}, trim_r});
    wire signed [24:0] y_l = sdm_out_l ? 25'sd8388607 : -25'sd8388607;
    wire signed [24:0] y_r = sdm_out_r ? 25'sd8388607 : -25'sd8388607;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1_l<=0; v2_l<=0; v1_r<=0; v2_r<=0; sdm_out_l<=0; sdm_out_r<=0;
        end else begin
            // Left
            v1_l <= v1_l + $signed({{1{x_l[24]}}, x_l}) - $signed({{1{y_l[24]}}, y_l});
            v2_l <= v2_l + v1_l;
            // Select output mode: currently both map to sign; multi-bit path reserved for future
            sdm_out_l <= ~v2_l[25]; // sign
            // Right
            v1_r <= v1_r + $signed({{1{x_r[24]}}, x_r}) - $signed({{1{y_r[24]}}, y_r});
            v2_r <= v2_r + v1_r;
            sdm_out_r <= ~v2_r[25];
        end
    end

endmodule
