`timescale 1ns/1ps

module tb_kosei_audio_chip;
    reg clk = 0;
    reg reset_n = 0;
    always #5 clk = ~clk; // 100 MHz

    // I2S stub
    reg i2s_bclk=0, i2s_lrclk=0, i2s_sd=0;
    // SPDIF/USB
    reg spdif_in=0, usb_dp=0, usb_dm=0;

    // Parallel PCM test input
    reg        pcm_valid;
    reg [23:0] pcm_l, pcm_r;

    // CSR
    reg        csr_write, csr_read;
    reg [7:0]  csr_addr;
    reg [31:0] csr_wdata;
    wire [31:0] csr_rdata;
    wire        csr_ready;

    wire sdm_out_l, sdm_out_r;

    kosei_audio_chip dut (
        .clk(clk), .reset_n(reset_n),
        .i2s_bclk(i2s_bclk), .i2s_lrclk(i2s_lrclk), .i2s_sd(i2s_sd),
        .spdif_in(spdif_in), .usb_dp(usb_dp), .usb_dm(usb_dm),
        .pcm_test_valid(pcm_valid), .pcm_test_l(pcm_l), .pcm_test_r(pcm_r),
        .csr_write(csr_write), .csr_read(csr_read), .csr_addr(csr_addr), .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata), .csr_ready(csr_ready),
        .sdm_out_l(sdm_out_l), .sdm_out_r(sdm_out_r)
    );

    initial begin
        // Reset
        #1 reset_n = 0; csr_write=0; csr_read=0; csr_addr=0; csr_wdata=0;
        pcm_valid=0; pcm_l=0; pcm_r=0;
        #50 reset_n = 1;

        // Configure: input_sel=0 (test), osr=4x, volume=unity, soft_mute=0
        @(posedge clk);
        csr_write=1; csr_addr=8'h04; csr_wdata=32'h0000_0011; // osr_sel=1 (4x), input_sel=1? -> fix: set to 0 test
        @(posedge clk); csr_write=1; csr_addr=8'h04; csr_wdata=32'h0000_0010; // osr=1, input_sel=0
        @(posedge clk); csr_write=1; csr_addr=8'h08; csr_wdata=32'h0000_7FFF;
        @(posedge clk); csr_write=0;

        // Feed a ramp
        repeat (200) begin
            @(posedge clk);
            pcm_valid <= 1'b1;
            pcm_l <= pcm_l + 24'd1000;
            pcm_r <= pcm_r + 24'd2000;
        end
        pcm_valid <= 1'b0;

        // Soft mute
        @(posedge clk); csr_write=1; csr_addr=8'h0C; csr_wdata=32'h1; @(posedge clk); csr_write=0;
        repeat (200) @(posedge clk);

        $display("TB done");
        $finish;
    end
endmodule
