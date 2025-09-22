/*
 * SRAM Controller Module for Kosei Audio Chip M1
 * On-chip SRAM management for buffers, EQ coefficients, and DSP routines
 */

module sram_controller (
    // System interface
    input wire clk_sys,
    input wire rst_n,
    
    // SRAM interface requests from various modules
    input wire [15:0] sram_addr_req,
    output reg [31:0] sram_data_out,
    input wire [31:0] sram_data_in,
    input wire sram_we,
    output reg sram_oe,
    output reg sram_ce
);

    // SRAM memory array - 64KB total
    // Organized as 16K x 32-bit words
    parameter SRAM_DEPTH = 16384;
    reg [31:0] sram_memory [0:SRAM_DEPTH-1];
    
    // SRAM controller state machine
    reg [2:0] sram_state;
    reg [15:0] sram_addr_internal;
    reg sram_ready;
    
    // Memory map regions
    parameter AUDIO_BUFFER_BASE   = 16'h0000;  // 0x0000-0x0FFF: Audio buffers (4KB)
    parameter EQ_COEFF_BASE       = 16'h1000;  // 0x1000-0x1FFF: EQ coefficients (4KB)
    parameter DSP_ROUTINE_BASE    = 16'h2000;  // 0x2000-0x2FFF: DSP routines (4KB)
    parameter FILTER_COEFF_BASE   = 16'h3000;  // 0x3000-0x3FFF: Filter coefficients (4KB)
    
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sram_state <= 3'b000;
            sram_addr_internal <= 16'b0;
            sram_data_out <= 32'b0;
            sram_oe <= 1'b0;
            sram_ce <= 1'b0;
            sram_ready <= 1'b1;
            
            // Initialize SRAM with default values
            for (integer i = 0; i < SRAM_DEPTH; i = i + 1) begin
                sram_memory[i] = 32'b0;
            end
            
            // Load default EQ coefficients (flat response)
            for (integer i = 0; i < 1024; i = i + 1) begin
                sram_memory[EQ_COEFF_BASE[15:2] + i] = 32'h00008000; // Unity gain
            end
            
            // Load default filter coefficients
            for (integer i = 0; i < 1024; i = i + 1) begin
                if (i == 512) begin
                    sram_memory[FILTER_COEFF_BASE[15:2] + i] = 32'h00007FFF; // Center tap
                end else begin
                    sram_memory[FILTER_COEFF_BASE[15:2] + i] = 32'h00000000; // Zeros
                end
            end
            
        end else begin
            case (sram_state)
                3'b000: begin // IDLE
                    sram_ce <= 1'b1;  // Always enabled for fast access
                    sram_oe <= 1'b1;  // Default to read mode
                    
                    if (sram_we || (sram_addr_req != sram_addr_internal)) begin
                        sram_addr_internal <= sram_addr_req;
                        sram_ready <= 1'b0;
                        
                        if (sram_we) begin
                            sram_state <= 3'b001; // WRITE
                        end else begin
                            sram_state <= 3'b010; // READ
                        end
                    end
                end
                
                3'b001: begin // WRITE
                    sram_oe <= 1'b0;  // Disable output during write
                    
                    if (sram_addr_internal < SRAM_DEPTH) begin
                        sram_memory[sram_addr_internal] <= sram_data_in;
                    end
                    
                    sram_state <= 3'b011; // WRITE_COMPLETE
                end
                
                3'b010: begin // READ
                    sram_oe <= 1'b1;  // Enable output for read
                    
                    if (sram_addr_internal < SRAM_DEPTH) begin
                        sram_data_out <= sram_memory[sram_addr_internal];
                    end else begin
                        sram_data_out <= 32'h00000000; // Return zero for invalid address
                    end
                    
                    sram_state <= 3'b011; // READ_COMPLETE
                end
                
                3'b011: begin // COMPLETE
                    sram_ready <= 1'b1;
                    sram_state <= 3'b000; // Return to IDLE
                end
                
                default: begin
                    sram_state <= 3'b000; // Default to IDLE
                end
            endcase
        end
    end

endmodule
