// Programmable EQ engine: up to 4 biquads per channel
`timescale 1ns/1ps
module eq_engine #(
    parameter N_SECTIONS = 4
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_l,
    input  wire [23:0] in_r,
    input  wire        enable,
    // Flattened coeff bus: {sec0_b0,b1,b2,a1,a2, sec1_..., ...}
    input  wire [N_SECTIONS*5*16-1:0] coeff_bus,
    output reg         out_valid,
    output reg  [23:0] out_l,
    output reg  [23:0] out_r
);
    integer i;
    // Chain left
    wire [23:0] l_samp [0:N_SECTIONS];
    wire        l_val  [0:N_SECTIONS];
    assign l_samp[0] = in_l; assign l_val[0] = in_valid;
    genvar gi;
    generate for (gi=0; gi<N_SECTIONS; gi=gi+1) begin: SEC_L
        wire [23:0] y; wire v;
        wire signed [15:0] b0 = coeff_bus[(gi*5+0)*16 +: 16];
        wire signed [15:0] b1 = coeff_bus[(gi*5+1)*16 +: 16];
        wire signed [15:0] b2 = coeff_bus[(gi*5+2)*16 +: 16];
        wire signed [15:0] a1 = coeff_bus[(gi*5+3)*16 +: 16];
        wire signed [15:0] a2 = coeff_bus[(gi*5+4)*16 +: 16];
        biquad u_bq(
            .clk(clk), .rst_n(rst_n), .in_valid(l_val[gi]), .in_sample(l_samp[gi]),
            .b0(b0), .b1(b1), .b2(b2), .a1(a1), .a2(a2),
            .out_valid(v), .out_sample(y)
        );
        assign l_samp[gi+1] = enable ? y : l_samp[gi];
        assign l_val[gi+1]  = l_val[gi];
    end endgenerate

    // Chain right
    wire [23:0] r_samp [0:N_SECTIONS];
    wire        r_val  [0:N_SECTIONS];
    assign r_samp[0] = in_r; assign r_val[0] = in_valid;
    genvar gj;
    generate for (gj=0; gj<N_SECTIONS; gj=gj+1) begin: SEC_R
        wire [23:0] y; wire v;
        wire signed [15:0] b0r = coeff_bus[(gj*5+0)*16 +: 16];
        wire signed [15:0] b1r = coeff_bus[(gj*5+1)*16 +: 16];
        wire signed [15:0] b2r = coeff_bus[(gj*5+2)*16 +: 16];
        wire signed [15:0] a1r = coeff_bus[(gj*5+3)*16 +: 16];
        wire signed [15:0] a2r = coeff_bus[(gj*5+4)*16 +: 16];
        biquad u_bq(
            .clk(clk), .rst_n(rst_n), .in_valid(r_val[gj]), .in_sample(r_samp[gj]),
            .b0(b0r), .b1(b1r), .b2(b2r), .a1(a1r), .a2(a2r),
            .out_valid(v), .out_sample(y)
        );
        assign r_samp[gj+1] = enable ? y : r_samp[gj];
        assign r_val[gj+1]  = r_val[gj];
    end endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin out_valid<=1'b0; out_l<=24'd0; out_r<=24'd0; end
        else begin
            out_valid <= r_val[N_SECTIONS] & l_val[N_SECTIONS];
            out_l <= l_samp[N_SECTIONS];
            out_r <= r_samp[N_SECTIONS];
        end
    end
endmodule
