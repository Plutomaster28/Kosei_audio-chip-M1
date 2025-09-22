// 2x Interpolating FIR (halfband-like) - simplified skeleton
`timescale 1ns/1ps

module fir_interp_2x #(
    parameter TAPS = 16
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         in_valid,
    input  wire [23:0]  in_sample,
    output reg          out_valid,
    output reg  [23:0]  out_sample
);
    // Delay line
    reg [23:0] x[TAPS-1:0];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i; for (i=0;i<TAPS;i=i+1) x[i] <= 24'd0;
        end else if (in_valid) begin
            integer j; for (j=TAPS-1;j>0;j=j-1) x[j] <= x[j-1];
            x[0] <= in_sample;
        end
    end

    // Simple placeholder coefficients (halfband-ish: many zeros) — replace with real design
    reg signed [15:0] h[TAPS-1:0];
    initial begin
        integer k; for (k=0;k<TAPS;k=k+1) h[k]=16'sd0;
        h[0]=16'sd4096; // small impulse energy
        h[8]=16'sd12288; // center tap (0.375)
    end

    reg phase; // 0=zero-stuff phase, 1=filter output on inserted sample
    reg signed [47:0] acc_comb;

    integer m;
    always @* begin
        acc_comb = 48'sd0;
        for (m=0; m<TAPS; m=m+1) begin
            acc_comb = acc_comb + $signed({{8{x[m][23]}}, x[m]}) * $signed(h[m]);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 1'b0; out_valid <= 1'b0; out_sample <= 24'd0;
        end else begin
            if (in_valid) begin
                // First output: original sample path
                out_valid  <= 1'b1;
                out_sample <= in_sample;
                phase      <= 1'b1;
            end else if (phase) begin
                // Second output: filtered (inserted) sample
                out_valid  <= 1'b1;
                out_sample <= acc_comb[39:16];
                phase      <= 1'b0;
            end else begin
                out_valid <= 1'b0;
            end
        end
    end
endmodule
