// Digital Front-End
// Selects between input sources, provides simple I2S receiver (stub),
// S/PDIF and USB stubs. Outputs 24-bit PCM in core clock domain.
`timescale 1ns/1ps

module digital_frontend (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  input_sel, // 0=test,1=i2s,2=spdif,3=usb

    // I2S signals (separate domain in reality; here sampled simply)
    input  wire        i2s_bclk,
    input  wire        i2s_lrclk,
    input  wire        i2s_sd,

    // S/PDIF
    input  wire        spdif_in,

    // USB (stub)
    input  wire        usb_dp,
    input  wire        usb_dm,

    // Parallel test input (clk domain)
    input  wire        test_valid,
    input  wire [23:0] test_l,
    input  wire [23:0] test_r,

    // Output normalized PCM
    output reg         pcm_valid,
    output reg  [23:0] pcm_l,
    output reg  [23:0] pcm_r
);

    // Proper I2S RX in i2s_bclk domain + CDC via async FIFO
    wire [23:0] i2s_pcm_l_bclk, i2s_pcm_r_bclk;
    wire        i2s_frame_valid_bclk;
    i2s_rx u_i2s_rx (
        .bclk(i2s_bclk), .lrclk(i2s_lrclk), .sd(i2s_sd), .rst_n(rst_n),
        .pcm_l(i2s_pcm_l_bclk), .pcm_r(i2s_pcm_r_bclk), .frame_valid(i2s_frame_valid_bclk)
    );

    // Pack L/R into 48-bit and push to async FIFO
    wire        i2s_fifo_w_en = i2s_frame_valid_bclk;
    wire [47:0] i2s_fifo_wdata = {i2s_pcm_l_bclk, i2s_pcm_r_bclk};
    wire        i2s_fifo_full;
    wire        i2s_fifo_empty;
    wire [47:0] i2s_fifo_rdata;

    fifo_async #(.WIDTH(48), .DEPTH(16)) u_i2s_fifo (
        .wclk(i2s_bclk), .wrst_n(rst_n), .w_en(i2s_fifo_w_en), .w_data(i2s_fifo_wdata), .w_full(i2s_fifo_full),
        .rclk(clk), .rrst_n(rst_n), .r_en(1'b1), .r_data(i2s_fifo_rdata), .r_empty(i2s_fifo_empty)
    );

    reg [23:0] i2s_l, i2s_r; reg i2s_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i2s_l <= 24'd0; i2s_r <= 24'd0; i2s_valid <= 1'b0;
        end else begin
            if (!i2s_fifo_empty) begin
                {i2s_l, i2s_r} <= i2s_fifo_rdata;
                i2s_valid <= 1'b1;
            end else begin
                i2s_valid <= 1'b0;
            end
        end
    end

    // S/PDIF and USB UAC1 receivers (stubs for now)
    wire        spdif_valid; wire [23:0] spdif_l, spdif_r;
    spdif_rx u_spdif(.clk(clk), .rst_n(rst_n), .spdif_in(spdif_in), .pcm_valid(spdif_valid), .pcm_l(spdif_l), .pcm_r(spdif_r));

    wire        usb_valid; wire [23:0] usb_l, usb_r;
    usb_uac1_rx u_usb(.clk(clk), .rst_n(rst_n), .usb_dp(usb_dp), .usb_dm(usb_dm), .pcm_valid(usb_valid), .pcm_l(usb_l), .pcm_r(usb_r));

    // Mux sources
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcm_l <= 24'd0;
            pcm_r <= 24'd0;
            pcm_valid <= 1'b0;
        end else begin
            case (input_sel)
                2'd0: begin // test
                    pcm_l <= test_l;
                    pcm_r <= test_r;
                    pcm_valid <= test_valid;
                end
                2'd1: begin // i2s
                    pcm_l <= i2s_l;
                    pcm_r <= i2s_r;
                    pcm_valid <= i2s_valid;
                end
                2'd2: begin // spdif
                    pcm_l <= spdif_l;
                    pcm_r <= spdif_r;
                    pcm_valid <= spdif_valid;
                end
                default: begin // usb
                    pcm_l <= usb_l;
                    pcm_r <= usb_r;
                    pcm_valid <= usb_valid;
                end
            endcase
        end
    end

endmodule
