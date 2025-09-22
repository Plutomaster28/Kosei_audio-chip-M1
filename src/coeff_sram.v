// Simple coefficient SRAM with 32-bit words, 256-depth
`timescale 1ns/1ps
module coeff_sram (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wen,
    input  wire [7:0]  addr,
    input  wire [31:0] wdata,
    input  wire        ren,
    output reg  [31:0] rdata
);
    reg [31:0] mem [0:255];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rdata <= 32'd0; end
        else begin
            if (wen) mem[addr] <= wdata;
            if (ren) rdata <= mem[addr];
        end
    end
endmodule
