// Simple synchronous FIFO (unused initially, provided for future buffering)
`timescale 1ns/1ps

module fifo_sync #(
    parameter WIDTH = 24,
    parameter DEPTH = 16
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             wr_en,
    input  wire [WIDTH-1:0] wr_data,
    input  wire             rd_en,
    output reg  [WIDTH-1:0] rd_data,
    output wire             full,
    output wire             empty
);
    localparam ADDR_W = $clog2(DEPTH);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_W:0] wptr, rptr; // extra bit for full/empty differentiation

    assign full  = (wptr[ADDR_W] != rptr[ADDR_W]) && (wptr[ADDR_W-1:0] == rptr[ADDR_W-1:0]);
    assign empty = (wptr == rptr);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= { (ADDR_W+1){1'b0} };
        end else if (wr_en && !full) begin
            mem[wptr[ADDR_W-1:0]] <= wr_data;
            wptr <= wptr + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rptr <= { (ADDR_W+1){1'b0} };
            rd_data <= {WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            rd_data <= mem[rptr[ADDR_W-1:0]];
            rptr <= rptr + 1'b1;
        end
    end
endmodule
