/*
 * Clock Management Module for Kosei Audio Chip M1
 * High-Precision PLL, Jitter Attenuator, FIFO Buffering, and Reclocking
 */

module clock_management (
    // External reference clocks
    input wire clk_ref_external,     // External 10 MHz reference
    input wire clk_crystal,          // Crystal oscillator input
    input wire clk_mclk_in,          // Master clock input (various rates)
    
    // System control
    input wire rst_n,
    input wire power_enable,
    
    // Configuration
    input wire [7:0] config_pll_mode,       // PLL configuration
    input wire [7:0] config_jitter_filter,  // Jitter attenuation settings
    input wire [7:0] config_clock_source,   // Clock source selection
    input wire [17:0] config_sample_rate,   // Target sample rate
    input wire [7:0] config_fifo_depth,     // FIFO buffer depth
    
    // Generated clocks
    output wire clk_sys,            // 50 MHz system clock
    output wire clk_audio_master,   // Audio master clock (24.576 MHz)
    output wire clk_audio_bit,      // Audio bit clock (variable)
    output wire clk_dac_hs,         // High-speed DAC clock (196.608 MHz)
    output wire clk_calibration,    // Slow calibration clock (1 MHz)
    output wire clk_analog,         // Analog control clock (100 kHz)
    
    // FIFO and reclocking interface
    input wire [31:0] async_audio_left,
    input wire [31:0] async_audio_right,
    input wire async_audio_valid,
    output wire [31:0] reclocked_audio_left,
    output wire [31:0] reclocked_audio_right,
    output wire reclocked_audio_valid,
    
    // Status and monitoring
    output wire pll_locked,
    output wire [15:0] jitter_measurement,
    output wire [7:0] clock_status_flags,
    output wire [15:0] fifo_fill_level
);

    // Internal clock signals
    wire pll_clk_vco;
    wire pll_clk_feedback;
    wire jitter_filtered_clk;
    wire reclocked_master;
    
    // ============================================================================
    // High-Precision PLL for Audio Clock Generation
    // ============================================================================
    
    high_precision_pll audio_pll (
        .clk_ref(clk_ref_external),
        .clk_crystal(clk_crystal),
        .rst_n(rst_n),
        .power_enable(power_enable),
        .config_pll_mode(config_pll_mode),
        .config_clock_source(config_clock_source),
        .config_sample_rate(config_sample_rate),
        .pll_clk_vco(pll_clk_vco),
        .pll_clk_feedback(pll_clk_feedback),
        .pll_locked(pll_locked),
        .clk_sys(clk_sys),
        .clk_audio_master(clk_audio_master),
        .clk_dac_hs(clk_dac_hs),
        .clk_calibration(clk_calibration),
        .clk_analog(clk_analog)
    );
    
    // ============================================================================
    // Jitter Attenuator and Clock Cleaning
    // ============================================================================
    
    jitter_attenuator jitter_filter (
        .clk_in(clk_mclk_in),
        .clk_ref(clk_audio_master),
        .rst_n(rst_n),
        .power_enable(power_enable),
        .config_jitter_filter(config_jitter_filter),
        .clk_cleaned(jitter_filtered_clk),
        .jitter_measurement(jitter_measurement)
    );
    
    // ============================================================================
    // Audio Bit Clock Generator
    // ============================================================================
    
    audio_bit_clock_generator bit_clk_gen (
        .clk_master(clk_audio_master),
        .rst_n(rst_n),
        .config_sample_rate(config_sample_rate),
        .clk_audio_bit(clk_audio_bit)
    );
    
    // ============================================================================
    // FIFO Buffer and Reclocking
    // ============================================================================
    
    fifo_reclocking_buffer fifo_reclock (
        .clk_write(jitter_filtered_clk),
        .clk_read(clk_audio_master),
        .rst_n(rst_n),
        .config_fifo_depth(config_fifo_depth),
        .async_audio_left(async_audio_left),
        .async_audio_right(async_audio_right),
        .async_audio_valid(async_audio_valid),
        .reclocked_audio_left(reclocked_audio_left),
        .reclocked_audio_right(reclocked_audio_right),
        .reclocked_audio_valid(reclocked_audio_valid),
        .fifo_fill_level(fifo_fill_level)
    );
    
    // ============================================================================
    // Clock Status and Monitoring
    // ============================================================================
    
    clock_status_monitor status_mon (
        .clk_sys(clk_sys),
        .rst_n(rst_n),
        .pll_locked(pll_locked),
        .clk_audio_master(clk_audio_master),
        .clk_dac_hs(clk_dac_hs),
        .jitter_measurement(jitter_measurement),
        .fifo_fill_level(fifo_fill_level),
        .clock_status_flags(clock_status_flags)
    );

endmodule

// ============================================================================
// High-Precision PLL for Audio Applications
// ============================================================================

module high_precision_pll (
    input wire clk_ref,
    input wire clk_crystal,
    input wire rst_n,
    input wire power_enable,
    input wire [7:0] config_pll_mode,
    input wire [7:0] config_clock_source,
    input wire [17:0] config_sample_rate,
    output reg pll_clk_vco,
    output reg pll_clk_feedback,
    output reg pll_locked,
    output reg clk_sys,
    output reg clk_audio_master,
    output reg clk_dac_hs,
    output reg clk_calibration,
    output reg clk_analog
);

    // PLL parameters
    reg [17:0] pll_n_divider;      // Feedback divider (expanded for larger values)
    reg [7:0] pll_m_divider;       // Reference divider
    reg [7:0] pll_p_divider;       // Post divider
    reg [31:0] pll_vco_freq;
    
    // Phase detector and loop filter
    reg [15:0] phase_error;
    reg [31:0] loop_filter_integrator;
    reg [15:0] vco_control_voltage;
    
    // Lock detection
    reg [15:0] lock_counter;
    reg phase_locked;
    
    // Clock dividers for output generation
    reg [7:0] sys_clk_div_counter;
    reg [7:0] audio_master_div_counter;
    reg [7:0] dac_hs_div_counter;
    reg [15:0] calibration_div_counter;
    reg [15:0] analog_div_counter;
    
    // Input clock selection
    reg selected_ref_clk;
    
    always @(posedge selected_ref_clk or negedge rst_n) begin
        if (!rst_n) begin
            pll_n_divider <= 18'd49;      // Default for 24.576 MHz from 10 MHz
            pll_m_divider <= 8'd20;       // Reference divider
            pll_p_divider <= 8'd1;        // Post divider
            phase_error <= 16'b0;
            loop_filter_integrator <= 32'b0;
            vco_control_voltage <= 16'h8000;
            lock_counter <= 16'b0;
            phase_locked <= 1'b0;
            pll_locked <= 1'b0;
        end else if (power_enable) begin
            // Configure PLL based on target sample rate
            case (config_sample_rate)
                18'd44100: begin // CD quality
                    pll_n_divider <= 18'd451;   // 44.1 kHz * 512 = 22.5792 MHz
                    pll_m_divider <= 8'd10;
                end
                18'd48000: begin // Standard digital audio
                    pll_n_divider <= 18'd49;    // 48 kHz * 512 = 24.576 MHz
                    pll_m_divider <= 8'd10;
                end
                18'd96000: begin // High-res audio
                    pll_n_divider <= 18'd98;    // 96 kHz * 512 = 49.152 MHz
                    pll_m_divider <= 8'd10;
                end
                18'd192000: begin // Ultra high-res
                    pll_n_divider <= 18'd196;   // 192 kHz * 512 = 98.304 MHz
                    pll_m_divider <= 8'd10;
                end
                default: begin
                    pll_n_divider <= 18'd49;    // Default to 48 kHz
                    pll_m_divider <= 8'd10;
                end
            endcase
            
            // Phase frequency detector (simplified)
            phase_error <= pll_clk_feedback - (selected_ref_clk / pll_m_divider);
            
            // Loop filter (proportional + integral)
            loop_filter_integrator <= loop_filter_integrator + {{16{phase_error[15]}}, phase_error};
            vco_control_voltage <= phase_error + loop_filter_integrator[31:16];
            
            // VCO (voltage controlled oscillator) - simplified model
            if (vco_control_voltage > 16'h8000) begin
                pll_vco_freq <= 32'd200000000 + (vco_control_voltage - 16'h8000) * 32'd1000;
            end else begin
                pll_vco_freq <= 32'd200000000 - (16'h8000 - vco_control_voltage) * 32'd1000;
            end
            
            // Lock detection
            if (phase_error < 16'd100 && phase_error > -16'd100) begin
                lock_counter <= lock_counter + 1;
                if (lock_counter > 16'hF000) begin
                    phase_locked <= 1'b1;
                    pll_locked <= 1'b1;
                end
            end else begin
                lock_counter <= 16'b0;
                phase_locked <= 1'b0;
                if (lock_counter == 16'b0) pll_locked <= 1'b0;
            end
            
            // Feedback divider
            pll_clk_feedback <= pll_clk_vco / pll_n_divider;
        end
    end
    
    // Clock source selection
    always @(*) begin
        case (config_clock_source[1:0])
            2'b00: selected_ref_clk = clk_ref;     // External reference
            2'b01: selected_ref_clk = clk_crystal; // Crystal
            2'b10: selected_ref_clk = clk_ref;     // Auto-select best
            2'b11: selected_ref_clk = clk_crystal; // Default crystal
            default: selected_ref_clk = clk_crystal;
        endcase
    end
    
    // Output clock generation with dividers
    always @(posedge pll_clk_vco or negedge rst_n) begin
        if (!rst_n) begin
            sys_clk_div_counter <= 8'b0;
            audio_master_div_counter <= 8'b0;
            dac_hs_div_counter <= 8'b0;
            calibration_div_counter <= 16'b0;
            analog_div_counter <= 16'b0;
            clk_sys <= 1'b0;
            clk_audio_master <= 1'b0;
            clk_dac_hs <= 1'b0;
            clk_calibration <= 1'b0;
            clk_analog <= 1'b0;
        end else if (pll_locked) begin
            // System clock (50 MHz) - divide by 4 from 200 MHz VCO
            sys_clk_div_counter <= sys_clk_div_counter + 1;
            if (sys_clk_div_counter == 8'd3) begin
                clk_sys <= ~clk_sys;
                sys_clk_div_counter <= 8'b0;
            end
            
            // Audio master clock (24.576 MHz) - divide by 8
            audio_master_div_counter <= audio_master_div_counter + 1;
            if (audio_master_div_counter == 8'd7) begin
                clk_audio_master <= ~clk_audio_master;
                audio_master_div_counter <= 8'b0;
            end
            
            // DAC high-speed clock (196.608 MHz) - divide by 1 (use VCO directly)
            clk_dac_hs <= pll_clk_vco;
            
            // Calibration clock (1 MHz) - divide by 200
            calibration_div_counter <= calibration_div_counter + 1;
            if (calibration_div_counter == 16'd199) begin
                clk_calibration <= ~clk_calibration;
                calibration_div_counter <= 16'b0;
            end
            
            // Analog control clock (100 kHz) - divide by 2000
            analog_div_counter <= analog_div_counter + 1;
            if (analog_div_counter == 16'd1999) begin
                clk_analog <= ~clk_analog;
                analog_div_counter <= 16'b0;
            end
        end
    end

endmodule

// ============================================================================
// Jitter Attenuator for Clock Cleaning
// ============================================================================

module jitter_attenuator (
    input wire clk_in,
    input wire clk_ref,
    input wire rst_n,
    input wire power_enable,
    input wire [7:0] config_jitter_filter,
    output reg clk_cleaned,
    output reg [15:0] jitter_measurement
);

    // Jitter measurement and filtering
    reg [31:0] edge_timer;
    reg [31:0] expected_period;
    reg [31:0] actual_period;
    reg [15:0] jitter_accumulator;
    reg [7:0] measurement_counter;
    
    // Clock cleaning PLL
    reg [15:0] clean_phase_error;
    reg [31:0] clean_integrator;
    reg [15:0] clean_vco_control;
    
    always @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n) begin
            edge_timer <= 32'b0;
            expected_period <= 32'd1000; // 1 MHz reference period
            actual_period <= 32'b0;
            jitter_accumulator <= 16'b0;
            measurement_counter <= 8'b0;
            jitter_measurement <= 16'b0;
            clean_phase_error <= 16'b0;
            clean_integrator <= 32'b0;
            clean_vco_control <= 16'h8000;
        end else if (power_enable) begin
            edge_timer <= edge_timer + 1;
            
            // Measure period and jitter on input clock transitions
            if (clk_in && (edge_timer > 32'd100)) begin // Edge detected
                actual_period <= edge_timer;
                edge_timer <= 32'b0;
                
                // Calculate jitter (deviation from expected)
                if (actual_period > expected_period) begin
                    jitter_accumulator <= jitter_accumulator + ((actual_period - expected_period) & 16'hFFFF);
                end else begin
                    jitter_accumulator <= jitter_accumulator + ((expected_period - actual_period) & 16'hFFFF);
                end
                
                measurement_counter <= measurement_counter + 1;
                if (measurement_counter == 8'hFF) begin
                    jitter_measurement <= jitter_accumulator >> 8; // Average
                    jitter_accumulator <= 16'b0;
                end
            end
            
            // Clock cleaning PLL
            clean_phase_error <= clk_in - clk_cleaned;
            clean_integrator <= clean_integrator + {{16{clean_phase_error[15]}}, clean_phase_error};
            clean_vco_control <= clean_phase_error + clean_integrator[31:16];
        end
    end
    
    // Generate cleaned clock based on filter configuration
    always @(posedge clk_ref) begin
        if (power_enable) begin
            case (config_jitter_filter[2:0])
                3'b000: clk_cleaned <= clk_in; // No filtering
                3'b001: clk_cleaned <= (clean_vco_control > 16'h8000) ? 1'b1 : 1'b0; // Light filtering
                3'b010: clk_cleaned <= (clean_integrator[31:16] > 16'h8000) ? 1'b1 : 1'b0; // Medium filtering
                3'b011: clk_cleaned <= clk_ref; // Heavy filtering (use reference)
                default: clk_cleaned <= clk_in;
            endcase
        end else begin
            clk_cleaned <= 1'b0;
        end
    end

endmodule

// ============================================================================
// Audio Bit Clock Generator
// ============================================================================

module audio_bit_clock_generator (
    input wire clk_master,
    input wire rst_n,
    input wire [17:0] config_sample_rate,
    output reg clk_audio_bit
);

    reg [8:0] bit_clk_divider;  // Increased to 9 bits for value 256
    reg [8:0] bit_clk_counter;
    
    always @(posedge clk_master or negedge rst_n) begin
        if (!rst_n) begin
            bit_clk_divider <= 9'd64;  // Default for 48kHz (24.576MHz / 64 = 384kHz)
            bit_clk_counter <= 9'b0;
            clk_audio_bit <= 1'b0;
        end else begin
            // Calculate bit clock divider based on sample rate
            case (config_sample_rate)
                18'd44100: bit_clk_divider <= 9'd64;  // 22.5792MHz / 64 = 352.8kHz
                18'd48000: bit_clk_divider <= 9'd64;  // 24.576MHz / 64 = 384kHz
                18'd96000: bit_clk_divider <= 9'd128; // 49.152MHz / 128 = 384kHz
                18'd192000: bit_clk_divider <= 9'd256; // 98.304MHz / 256 = 384kHz
                default: bit_clk_divider <= 9'd64;
            endcase
            
            bit_clk_counter <= bit_clk_counter + 1;
            if (bit_clk_counter >= (bit_clk_divider >> 1)) begin
                clk_audio_bit <= ~clk_audio_bit;
                bit_clk_counter <= 9'b0;
            end
        end
    end

endmodule

// ============================================================================
// FIFO Buffer and Reclocking
// ============================================================================

module fifo_reclocking_buffer (
    input wire clk_write,
    input wire clk_read,
    input wire rst_n,
    input wire [7:0] config_fifo_depth,
    input wire [31:0] async_audio_left,
    input wire [31:0] async_audio_right,
    input wire async_audio_valid,
    output reg [31:0] reclocked_audio_left,
    output reg [31:0] reclocked_audio_right,
    output reg reclocked_audio_valid,
    output reg [15:0] fifo_fill_level
);

    // FIFO parameters
    parameter FIFO_DEPTH = 1024;
    
    // FIFO memory
    reg [63:0] fifo_memory [0:FIFO_DEPTH-1]; // 64-bit for stereo pair
    reg [9:0] write_pointer;
    reg [9:0] read_pointer;
    reg [10:0] fill_count;
    
    // Synchronizers for clock domain crossing
    reg [9:0] write_pointer_sync1, write_pointer_sync2;
    reg [9:0] read_pointer_sync1, read_pointer_sync2;
    
    // Write domain (async input)
    always @(posedge clk_write or negedge rst_n) begin
        if (!rst_n) begin
            write_pointer <= 10'b0;
            fifo_memory[0] <= 64'b0; // Initialize first location
        end else if (async_audio_valid && (fill_count < FIFO_DEPTH)) begin
            fifo_memory[write_pointer] <= {async_audio_left, async_audio_right};
            write_pointer <= (write_pointer + 1) % FIFO_DEPTH;
        end
    end
    
    // Read domain (reclocked output)
    always @(posedge clk_read or negedge rst_n) begin
        if (!rst_n) begin
            read_pointer <= 10'b0;
            reclocked_audio_left <= 32'b0;
            reclocked_audio_right <= 32'b0;
            reclocked_audio_valid <= 1'b0;
        end else if (fill_count > 10'd4) begin // Ensure minimum fill level
            {reclocked_audio_left, reclocked_audio_right} <= fifo_memory[read_pointer];
            read_pointer <= (read_pointer + 1) % FIFO_DEPTH;
            reclocked_audio_valid <= 1'b1;
        end else begin
            reclocked_audio_valid <= 1'b0;
        end
    end
    
    // Synchronize pointers across clock domains
    always @(posedge clk_read) begin
        write_pointer_sync1 <= write_pointer;
        write_pointer_sync2 <= write_pointer_sync1;
    end
    
    always @(posedge clk_write) begin
        read_pointer_sync1 <= read_pointer;
        read_pointer_sync2 <= read_pointer_sync1;
    end
    
    // Calculate fill level
    always @(posedge clk_read) begin
        if (write_pointer_sync2 >= read_pointer) begin
            fill_count <= write_pointer_sync2 - read_pointer;
        end else begin
            fill_count <= FIFO_DEPTH - (read_pointer - write_pointer_sync2);
        end
        
        fifo_fill_level <= fill_count[15:0];
    end

endmodule

// ============================================================================
// Clock Status Monitor
// ============================================================================

module clock_status_monitor (
    input wire clk_sys,
    input wire rst_n,
    input wire pll_locked,
    input wire clk_audio_master,
    input wire clk_dac_hs,
    input wire [15:0] jitter_measurement,
    input wire [15:0] fifo_fill_level,
    output reg [7:0] clock_status_flags
);

    reg [15:0] audio_master_counter;
    reg [15:0] dac_hs_counter;
    reg clock_health_check;
    
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clock_status_flags <= 8'b0;
            audio_master_counter <= 16'b0;
            dac_hs_counter <= 16'b0;
            clock_health_check <= 1'b0;
        end else begin
            // Monitor clock activity
            if (clk_audio_master) audio_master_counter <= audio_master_counter + 1;
            if (clk_dac_hs) dac_hs_counter <= dac_hs_counter + 1;
            
            // Update status flags
            clock_status_flags[0] <= pll_locked;
            clock_status_flags[1] <= (audio_master_counter > 16'd100); // Audio master active
            clock_status_flags[2] <= (dac_hs_counter > 16'd1000);      // DAC clock active
            clock_status_flags[3] <= (jitter_measurement < 16'd100);   // Low jitter
            clock_status_flags[4] <= (fifo_fill_level > 16'd10) && (fifo_fill_level < 16'd1000); // FIFO healthy
            clock_status_flags[5] <= (fifo_fill_level > 16'd900);      // FIFO nearly full
            clock_status_flags[6] <= (fifo_fill_level < 16'd10);       // FIFO nearly empty
            clock_status_flags[7] <= clock_health_check;               // Overall health
            
            // Overall health check
            clock_health_check <= clock_status_flags[0] && clock_status_flags[1] && 
                                 clock_status_flags[2] && clock_status_flags[3] && 
                                 clock_status_flags[4];
        end
    end

endmodule
