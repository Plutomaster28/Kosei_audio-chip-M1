// Wrapper top expected by some flows; instantiates kosei_audio_chip
`timescale 1ns/1ps

module kosei_audio_top (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        ext_mclk,

    // I2S
    input  wire        i2s_bclk,
    input  wire        i2s_lrclk,
    input  wire        i2s_sd,

    // SPDIF
    input  wire        spdif_in,

    // USB
    input  wire        usb_dp,
    input  wire        usb_dm,

    // Parallel PCM test input
    input  wire        pcm_test_valid,
    input  wire [23:0] pcm_test_l,
    input  wire [23:0] pcm_test_r,

    // CSR bus
    input  wire        csr_write,
    input  wire        csr_read,
    input  wire [7:0]  csr_addr,
    input  wire [31:0] csr_wdata,
    output wire [31:0] csr_rdata,
    output wire        csr_ready,

    // DAC bitstreams
    output wire        sdm_out_l,
    output wire        sdm_out_r
);
    kosei_audio_chip u_core (
        .clk(clk), .reset_n(reset_n), .ext_mclk(ext_mclk),
        .i2s_bclk(i2s_bclk), .i2s_lrclk(i2s_lrclk), .i2s_sd(i2s_sd),
        .spdif_in(spdif_in), .usb_dp(usb_dp), .usb_dm(usb_dm),
        .pcm_test_valid(pcm_test_valid), .pcm_test_l(pcm_test_l), .pcm_test_r(pcm_test_r),
        .csr_write(csr_write), .csr_read(csr_read), .csr_addr(csr_addr), .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata), .csr_ready(csr_ready),
        .sdm_out_l(sdm_out_l), .sdm_out_r(sdm_out_r)
    );
endmodule
