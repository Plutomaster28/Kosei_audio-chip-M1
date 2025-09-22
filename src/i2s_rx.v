// I2S Receiver (24-bit) in I2S BCLK domain
`timescale 1ns/1ps

module i2s_rx (
    input  wire        bclk,      // bit clock
    input  wire        lrclk,     // word select: 0=Left, 1=Right (I2S typically changes one bclk before MSB)
    input  wire        sd,        // serial data
    input  wire        rst_n,
    output reg  [23:0] pcm_l,
    output reg  [23:0] pcm_r,
    output reg         frame_valid // pulses high for 1 bclk at end of right word
);
    reg        lr_d;
    reg [4:0]  bit_cnt;
    reg [23:0] shreg;
    reg        curr_is_right;

    always @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            lr_d <= 1'b0; bit_cnt <= 5'd0; shreg <= 24'd0; curr_is_right <= 1'b0; frame_valid <= 1'b0; pcm_l<=0; pcm_r<=0;
        end else begin
            lr_d <= lrclk;
            frame_valid <= 1'b0;

            // Detect LRCLK edge to change channel
            if (lr_d != lrclk) begin
                bit_cnt <= 5'd0;
                curr_is_right <= lrclk; // assume lrclk=1 means Right
            end else begin
                // Shift in MSB-first
                if (bit_cnt < 5'd24) begin
                    shreg <= {shreg[22:0], sd};
                    bit_cnt <= bit_cnt + 1'b1;
                end
                if (bit_cnt == 5'd23) begin
                    if (curr_is_right) begin
                        pcm_r <= {shreg[22:0], sd};
                        frame_valid <= 1'b1; // Right completes frame
                    end else begin
                        pcm_l <= {shreg[22:0], sd};
                    end
                end
            end
        end
    end
endmodule
