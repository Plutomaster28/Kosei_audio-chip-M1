// 4x Interpolating FIR (polyphase) - simplified skeleton
`timescale 1ns/1ps

module fir_interp_4x #(
    parameter TAPS = 16
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         in_valid,
    input  wire [23:0]  in_sample,
    output reg          out_valid,
    output reg  [23:0]  out_sample
);
    // Simple structure: store last TAPS samples; compute 4 phases iteratively
    reg [23:0] x[TAPS-1:0];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer li;
            for (li=0; li<TAPS; li=li+1) x[li] <= 24'd0;
        end else if (in_valid) begin
            integer lj;
            for (lj=TAPS-1; lj>0; lj=lj-1) x[lj] <= x[lj-1];
            x[0] <= in_sample;
        end
    end

    // Coefficient ROMs for 4 phases (placeholder small coefficients)
    // In practice, populate with designed halfband/polyphase coefficients.
    reg signed [15:0] h0[TAPS-1:0];
    reg signed [15:0] h1[TAPS-1:0];
    reg signed [15:0] h2[TAPS-1:0];
    reg signed [15:0] h3[TAPS-1:0];
    initial begin
        integer im;
        for (im=0; im<TAPS; im=im+1) begin
            h0[im]=0; h1[im]=0; h2[im]=0; h3[im]=0;
        end
        // Very small prototype impulse-ish to keep output stable; replace later
        h0[0]=16'sd4096; // 0.125
        h1[0]=16'sd2048; // 0.0625
        h2[0]=16'sd4096;
        h3[0]=16'sd2048;
    end

    reg [1:0] phase;
    reg signed [47:0] acc_comb;
    reg [23:0] mac_out;

    // Combinational accumulation
    integer k;
    always @* begin
        acc_comb = 48'sd0;
        for (k=0; k<TAPS; k=k+1) begin
            case (phase)
                2'd0: acc_comb = acc_comb + $signed({{8{x[k][23]}}, x[k]}) * $signed(h0[k]);
                2'd1: acc_comb = acc_comb + $signed({{8{x[k][23]}}, x[k]}) * $signed(h1[k]);
                2'd2: acc_comb = acc_comb + $signed({{8{x[k][23]}}, x[k]}) * $signed(h2[k]);
                default: acc_comb = acc_comb + $signed({{8{x[k][23]}}, x[k]}) * $signed(h3[k]);
            endcase
        end
    end

    // Sequential register stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 2'd0; out_valid <= 1'b0; out_sample <= 24'd0; mac_out <= 24'd0;
        end else begin
            mac_out   <= acc_comb[39:16]; // scale back
            out_sample<= mac_out;
            out_valid <= 1'b1;
            phase     <= phase + 2'd1;
        end
    end
endmodule
