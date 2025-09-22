// Simple CSR register block with one readonly register at addr 0x00.
`timescale 1ns/1ps

module registers #(
    parameter ADDR_WIDTH = 8,
    parameter [31:0] READONLY_MASK = 32'h0000_0001 // bit0 indicates addr0 is RO
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 write_en,
    input  wire                 read_en,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [31:0]          wdata,
    output reg  [31:0]          rdata,
    output reg                  ready,
    input  wire [31:0]          ro0,
    input  wire [31:0]          rsvd
);
    // This is a minimal shim: it only serves reads and acknowledges writes
    // Actual write storage is handled by the parent module via its own regs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= 32'd0;
            ready <= 1'b0;
        end else begin
            ready <= 1'b0;
            if (read_en) begin
                case (addr)
                    8'h00: rdata <= ro0;
                    default: rdata <= 32'd0;
                endcase
                ready <= 1'b1;
            end else if (write_en) begin
                ready <= 1'b1; // write accepted; parent decodes and stores
            end
        end
    end
endmodule
