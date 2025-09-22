// DSP Engine
// - Oversampling control (stubbed passthrough with hold for >1x)
// - Volume apply (Q1.15)
// - Soft mute ramp
// - Simple FIR placeholder (single-tap)
// - Dither via LFSR (triangular PDF)
`timescale 1ns/1ps

module dsp_engine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_l,
    input  wire [23:0] in_r,
    input  wire [3:0]  osr_sel,      // 0=1x,1=4x,2=8x,3=16x
    input  wire [15:0] volume_q15,   // Q1.15
    input  wire        soft_mute,
    input  wire        deemp_enable,
    input  wire signed [15:0] balance_q15,
    input  wire [15:0] crossfeed_q15,
    output reg         out_valid,
    output reg  [23:0] out_l,
    output reg  [23:0] out_r
);

    // Hold registers for oversampling (nearest-hold)
    reg [23:0] hold_l, hold_r;
    reg [4:0]  osr_cnt;
    reg [4:0]  osr_max;

    always @(*) begin
        case (osr_sel)
            4'd1: osr_max = 5'd3;   // 4x
            4'd2: osr_max = 5'd7;   // 8x
            4'd3: osr_max = 5'd15;  // 16x
            default: osr_max = 5'd0; // 1x
        endcase
    end

    // Soft-mute ramp generator
    reg [15:0] mute_gain; // Q1.15
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mute_gain <= 16'h7FFF; // 1.0
        else if (soft_mute) begin
            if (mute_gain > 16'd64) mute_gain <= mute_gain - 16'd64; // slow ramp down
            else mute_gain <= 16'd0;
        end else begin
            if (mute_gain < 16'h7FFF-16'd64) mute_gain <= mute_gain + 16'd64; // ramp up to 1.0
            else mute_gain <= 16'h7FFF;
        end
    end

    // Dither using two LFSRs to approximate TPDF
    wire [15:0] lfsr_a, lfsr_b;
    lfsr16 u_lfsr_a (.clk(clk), .rst_n(rst_n), .rnd(lfsr_a));
    lfsr16 u_lfsr_b (.clk(clk), .rst_n(rst_n), .rnd(lfsr_b));
    wire signed [16:0] tpdf = {1'b0,lfsr_a} + {1'b0,lfsr_b};

    // Combine volume and mute into an effective Q1.15 gain
    wire [31:0] gain_tmp = volume_q15 * mute_gain; // 16x16=32
    wire [15:0] eff_gain_q15 = gain_tmp[30:15];    // approximate (>>15)

    // Apply effective gain and add dither
    wire signed [24:0] s_in_l = {in_l[23], in_l};
    wire signed [24:0] s_in_r = {in_r[23], in_r};
    wire signed [40:0] mul_l = s_in_l * $signed({1'b0, eff_gain_q15});
    wire signed [40:0] mul_r = s_in_r * $signed({1'b0, eff_gain_q15});

    // Scale back to 24-bit: take high bits (>>17 ~ Q1.15 -> int24)
    wire signed [23:0] vol_l = mul_l[40:17];
    wire signed [23:0] vol_r = mul_r[40:17];

    // Add small dither (shift down tpdf)
    wire signed [23:0] vol_l_d = vol_l + {{8{tpdf[16]}}, tpdf[16:1]};
    wire signed [23:0] vol_r_d = vol_r + {{8{tpdf[16]}}, tpdf[16:1]};

    // De-emphasis stage (optional)
    wire deemp_valid;
    wire [23:0] deemp_l, deemp_r;
    deemphasis_44k1 u_deemp(
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_l(vol_l_d), .in_r(vol_r_d), .enable(deemp_enable), .out_valid(deemp_valid), .out_l(deemp_l), .out_r(deemp_r)
    );

    // Balance + Crossfeed stage
    wire bc_valid; wire [23:0] bc_l, bc_r;
    balance_crossfeed u_bc(
        .clk(clk), .rst_n(rst_n), .in_valid(deemp_valid), .in_l(deemp_l), .in_r(deemp_r), .balance_q15(balance_q15), .crossfeed_q15(crossfeed_q15), .out_valid(bc_valid), .out_l(bc_l), .out_r(bc_r)
    );

    // Interpolators: 2x and 4x structures
    reg          fir4_in_valid;
    reg  [23:0]  fir4_in_l;
    reg  [23:0]  fir4_in_r;
    always @* begin
        case (osr_sel)
            4'd2: begin // 8x: feed 2x output into 4x
                fir4_in_valid = v2a_l & v2a_r;
                fir4_in_l = s2a_l;
                fir4_in_r = s2a_r;
            end
            4'd3: begin // 16x: feed second 2x output into 4x
                fir4_in_valid = v2b_l & v2b_r;
                fir4_in_l = s2b_l;
                fir4_in_r = s2b_r;
            end
            default: begin // 1x/4x
                fir4_in_valid = bc_valid;
                fir4_in_l = bc_l;
                fir4_in_r = bc_r;
            end
        endcase
    end
    wire         fir4_out_valid_l, fir4_out_valid_r; wire [23:0]  fir4_out_l, fir4_out_r;
    fir_interp_4x u_fir4_l(
        .clk(clk), .rst_n(rst_n), .in_valid(fir4_in_valid), .in_sample(fir4_in_l), .out_valid(fir4_out_valid_l), .out_sample(fir4_out_l)
    );
    fir_interp_4x u_fir4_r(
        .clk(clk), .rst_n(rst_n), .in_valid(fir4_in_valid), .in_sample(fir4_in_r), .out_valid(fir4_out_valid_r), .out_sample(fir4_out_r)
    );

    // 2x interpolators for cascading to reach 8x/16x
    wire v2a_l, v2a_r, v2b_l, v2b_r; wire [23:0] s2a_l, s2a_r, s2b_l, s2b_r;
    fir_interp_2x u_2x_a_l(.clk(clk), .rst_n(rst_n), .in_valid(bc_valid), .in_sample(bc_l), .out_valid(v2a_l), .out_sample(s2a_l));
    fir_interp_2x u_2x_a_r(.clk(clk), .rst_n(rst_n), .in_valid(bc_valid), .in_sample(bc_r), .out_valid(v2a_r), .out_sample(s2a_r));
    fir_interp_2x u_2x_b_l(.clk(clk), .rst_n(rst_n), .in_valid(v2a_l),   .in_sample(s2a_l), .out_valid(v2b_l), .out_sample(s2b_l));
    fir_interp_2x u_2x_b_r(.clk(clk), .rst_n(rst_n), .in_valid(v2a_r),   .in_sample(s2a_r), .out_valid(v2b_r), .out_sample(s2b_r));

    // Oversampling: use FIR for 4x; hold for others as placeholder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hold_l <= 24'd0;
            hold_r <= 24'd0;
            osr_cnt <= 5'd0;
            out_valid <= 1'b0;
            out_l <= 24'd0;
            out_r <= 24'd0;
        end else begin
            if (osr_sel==4'd1) begin
                // 4x path via FIR: output every cycle
                out_valid <= fir4_out_valid_l & fir4_out_valid_r;
                out_l <= fir4_out_l;
                out_r <= fir4_out_r;
            end else if (osr_sel==4'd2) begin
                // 8x via 2x then 4x: feed 2x output into 4x
                // Reuse instantiated 4x by switching its inputs via combinational nets above
                // For clarity, override fir4 inputs
                // Note: since fir4 modules are already fed by fir4_in_*, we rely on continuous assignments below
                out_valid <= fir4_out_valid_l & fir4_out_valid_r;
                out_l <= fir4_out_l;
                out_r <= fir4_out_r;
            end else if (osr_sel==4'd3) begin
                // 16x via 2x -> 2x -> 4x
                out_valid <= fir4_out_valid_l & fir4_out_valid_r;
                out_l <= fir4_out_l;
                out_r <= fir4_out_r;
            end else begin
                // Hold-based oversampling for other ratios
                if (bc_valid) begin
                    hold_l <= bc_l;
                    hold_r <= bc_r;
                    osr_cnt <= osr_max;
                    out_valid <= 1'b1;
                    out_l <= bc_l;
                    out_r <= bc_r;
                end else if (osr_cnt != 5'd0) begin
                    osr_cnt <= osr_cnt - 5'd1;
                    out_valid <= 1'b1;
                    out_l <= hold_l; // nearest hold for oversampling
                    out_r <= hold_r;
                end else begin
                    out_valid <= 1'b0;
                end
            end
        end
    end

endmodule

// 16-bit maximal LFSR for dither
module lfsr16 (
    input  wire clk,
    input  wire rst_n,
    output reg [15:0] rnd
);
    wire fb = rnd[15] ^ rnd[13] ^ rnd[12] ^ rnd[10];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rnd <= 16'hACE1;
        else rnd <= {rnd[14:0], fb};
    end
endmodule
