// Audio meters: peak and simple moving RMS estimators
`timescale 1ns/1ps
module audio_meters #(
    parameter WINDOW_LOG2 = 8 // 256-sample approximate RMS by leaky integrator
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_l,
    input  wire [23:0] in_r,
    output reg  [23:0] peak_l,
    output reg  [23:0] peak_r,
    output reg  [23:0] rms_l,
    output reg  [23:0] rms_r
);
    // Peak hold with slow decay
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin peak_l<=0; peak_r<=0; end
        else if (in_valid) begin
            peak_l <= (abs24(in_l) > peak_l) ? abs24(in_l) : (peak_l - (peak_l>>WINDOW_LOG2));
            peak_r <= (abs24(in_r) > peak_r) ? abs24(in_r) : (peak_r - (peak_r>>WINDOW_LOG2));
        end
    end

    // Leaky integrator RMS approximation: y += (x^2 - y) >> N; output sqrt via rough shift
    reg [47:0] acc_l, acc_r; // energy accumulator
    wire [23:0] aL = abs24(in_l);
    wire [23:0] aR = abs24(in_r);
    wire [47:0] eL = aL * aL;
    wire [47:0] eR = aR * aR;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin acc_l<=0; acc_r<=0; rms_l<=0; rms_r<=0; end
        else if (in_valid) begin
            acc_l <= acc_l + ((eL - acc_l) >> WINDOW_LOG2);
            acc_r <= acc_r + ((eR - acc_r) >> WINDOW_LOG2);
            // rough sqrt: take upper bits
            rms_l <= acc_l[47:24];
            rms_r <= acc_r[47:24];
        end
    end

    function [23:0] abs24(input [23:0] x);
        abs24 = x[23] ? (~x + 1'b1) : x;
    endfunction
endmodule
