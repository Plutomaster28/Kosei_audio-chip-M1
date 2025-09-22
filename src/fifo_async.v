// Dual-clock asynchronous FIFO for CDC between I2S BCLK and core clk
`timescale 1ns/1ps

module fifo_async #(
    parameter WIDTH = 48,   // 24-bit L + 24-bit R per frame
    parameter DEPTH = 16
) (
    input  wire             wclk,
    input  wire             wrst_n,
    input  wire             w_en,
    input  wire [WIDTH-1:0] w_data,
    output wire             w_full,

    input  wire             rclk,
    input  wire             rrst_n,
    input  wire             r_en,
    output reg  [WIDTH-1:0] r_data,
    output wire             r_empty
);
    localparam AW = $clog2(DEPTH);

    // Memory
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // Binary and Gray pointers
    reg [AW:0] wptr_bin, rptr_bin;
    reg [AW:0] wptr_gray, rptr_gray;
    reg [AW:0] wptr_gray_rclk1, wptr_gray_rclk2;
    reg [AW:0] rptr_gray_wclk1, rptr_gray_wclk2;

    // Gray conversion
    function [AW:0] bin2gray(input [AW:0] b); bin2gray = (b >> 1) ^ b; endfunction
    function [AW:0] gray2bin(input [AW:0] g);
        integer i; begin gray2bin[AW] = g[AW]; for (i=AW-1;i>=0;i=i-1) gray2bin[i] = gray2bin[i+1]^g[i]; end
    endfunction

    // Write domain
    wire [AW:0] rptr_bin_sync_w = gray2bin(rptr_gray_wclk2);
    assign w_full = ( (wptr_gray[AW]     != rptr_gray_wclk2[AW]) &&
                      (wptr_gray[AW-1]   != rptr_gray_wclk2[AW-1]) &&
                      (wptr_gray[AW-2:0] == rptr_gray_wclk2[AW-2:0]) );

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin <= 0; wptr_gray <= 0;
            rptr_gray_wclk1 <= 0; rptr_gray_wclk2 <= 0;
        end else begin
            rptr_gray_wclk1 <= rptr_gray;
            rptr_gray_wclk2 <= rptr_gray_wclk1;
            if (w_en && !w_full) begin
                mem[wptr_bin[AW-1:0]] <= w_data;
                wptr_bin <= wptr_bin + 1'b1;
                wptr_gray <= bin2gray(wptr_bin + 1'b1);
            end
        end
    end

    // Read domain
    wire [AW:0] wptr_bin_sync_r = gray2bin(wptr_gray_rclk2);
    assign r_empty = (wptr_gray_rclk2 == rptr_gray);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin <= 0; rptr_gray <= 0; r_data <= {WIDTH{1'b0}};
            wptr_gray_rclk1 <= 0; wptr_gray_rclk2 <= 0;
        end else begin
            wptr_gray_rclk1 <= wptr_gray;
            wptr_gray_rclk2 <= wptr_gray_rclk1;
            if (r_en && !r_empty) begin
                r_data <= mem[rptr_bin[AW-1:0]];
                rptr_bin <= rptr_bin + 1'b1;
                rptr_gray <= bin2gray(rptr_bin + 1'b1);
            end
        end
    end
endmodule
