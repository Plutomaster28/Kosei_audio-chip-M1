// Temperature sensor stub providing a slowly varying temperature reading
`timescale 1ns/1ps
module temp_sensor_stub (
    input  wire clk,
    input  wire rst_n,
    output reg  [11:0] temp_code // arbitrary units
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) temp_code <= 12'd512;
        else temp_code <= temp_code + 12'd1;
    end
endmodule
