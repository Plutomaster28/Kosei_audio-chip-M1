/*
 * Testbench for DAC Core
 * Tests hybrid R-2R + Sigma-Delta DAC with calibration
 */

`timescale 1ns / 1ps

module tb_dac_core;

    // ========================================================================
    // TEST PARAMETERS
    // ========================================================================
    parameter CLK_PERIOD = 10.0;           // 100 MHz DAC clock (10ns)
    parameter AUDIO_CLK_PERIOD = 81.38;    // 12.288 MHz audio clock (81.38ns)
    parameter SIMULATION_TIME = 200000;     // 200us simulation time
    
    // ========================================================================
    // DUT SIGNALS
    // ========================================================================
    
    // Clocks and Reset
    reg clk_dac;
    reg clk_audio;
    reg rst_n;
    
    // Power and References
    reg vdd_analog;
    reg vss_analog;
    reg vref_positive;
    reg vref_negative;
    reg [7:0] temperature_sensor;
    
    // Input Audio Data
    reg [23:0] audio_data_left;
    reg [23:0] audio_data_right;
    reg audio_data_valid;
    
    // Configuration
    reg [1:0] dac_mode;            // 0=R2R only, 1=Sigma-Delta only, 2=Hybrid
    reg calibration_enable;
    reg [7:0] calibration_target;
    reg [3:0] r2r_trim_left;
    reg [3:0] r2r_trim_right;
    
    // Analog Outputs
    wire audio_out_left_pos;
    wire audio_out_left_neg;
    wire audio_out_right_pos;
    wire audio_out_right_neg;
    
    // Status and Monitoring
    wire [7:0] dac_status;
    wire calibration_done;
    wire [15:0] thd_measurement;
    wire [7:0] noise_floor;
    wire thermal_warning;
    
    // ========================================================================
    // TEST VARIABLES
    // ========================================================================
    integer i, j;
    real sine_value;
    integer phase_left, phase_right;
    parameter SINE_SAMPLES = 128;           // 128 samples per cycle
    parameter TEST_AMPLITUDE_FULL = 24'h7FFFFF;
    parameter TEST_AMPLITUDE_HALF = 24'h3FFFFF;
    parameter TEST_AMPLITUDE_QUARTER = 24'h1FFFFF;
    
    // ========================================================================
    // DEVICE UNDER TEST
    // ========================================================================
    dac_core dut (
        .clk_dac(clk_dac),
        .clk_audio(clk_audio),
        .rst_n(rst_n),
        
        .vdd_analog(vdd_analog),
        .vss_analog(vss_analog),
        .vref_positive(vref_positive),
        .vref_negative(vref_negative),
        .temperature_sensor(temperature_sensor),
        
        .audio_data_left(audio_data_left),
        .audio_data_right(audio_data_right),
        .audio_data_valid(audio_data_valid),
        
        .dac_mode(dac_mode),
        .calibration_enable(calibration_enable),
        .calibration_target(calibration_target),
        .r2r_trim_left(r2r_trim_left),
        .r2r_trim_right(r2r_trim_right),
        
        .audio_out_left_pos(audio_out_left_pos),
        .audio_out_left_neg(audio_out_left_neg),
        .audio_out_right_pos(audio_out_right_pos),
        .audio_out_right_neg(audio_out_right_neg),
        
        .dac_status(dac_status),
        .calibration_done(calibration_done),
        .thd_measurement(thd_measurement),
        .noise_floor(noise_floor),
        .thermal_warning(thermal_warning)
    );
    
    // ========================================================================
    // CLOCK GENERATION
    // ========================================================================
    
    // DAC oversampling clock (100 MHz)
    always begin
        clk_dac = 1'b0;
        #(CLK_PERIOD/2);
        clk_dac = 1'b1;
        #(CLK_PERIOD/2);
    end
    
    // Audio sample clock (12.288 MHz)
    always begin
        clk_audio = 1'b0;
        #(AUDIO_CLK_PERIOD/2);
        clk_audio = 1'b1;
        #(AUDIO_CLK_PERIOD/2);
    end
    
    // ========================================================================
    // ANALOG SIGNAL SIMULATION
    // ========================================================================
    
    // Simulate power supplies and references
    always begin
        vdd_analog = 1'b1;    // +3.3V
        vss_analog = 1'b0;    // 0V (ground)
        vref_positive = 1'b1; // +2.5V reference
        vref_negative = 1'b0; // -2.5V reference (or ground)
        #100;
    end
    
    // Temperature sensor simulation (room temperature)
    always begin
        temperature_sensor = 8'd85; // ~25°C in arbitrary units
        #50000; // Update every 50us
        temperature_sensor = 8'd85 + $random % 5; // Small variations
    end
    
    // ========================================================================
    // AUDIO TEST SIGNAL GENERATION
    // ========================================================================
    
    // Generate various test signals
    always @(posedge clk_audio) begin
        if (!rst_n) begin
            phase_left <= 0;
            phase_right <= 0;
            audio_data_left <= 24'b0;
            audio_data_right <= 24'b0;
            audio_data_valid <= 1'b0;
        end else begin
            // Generate test signals based on test phase
            case (i % 5)
                0: begin // Full scale sine wave
                    sine_value = $sin(2.0 * 3.14159 * phase_left / SINE_SAMPLES);
                    audio_data_left <= $rtoi(sine_value * TEST_AMPLITUDE_FULL);
                    sine_value = $sin(2.0 * 3.14159 * phase_right / SINE_SAMPLES);
                    audio_data_right <= $rtoi(sine_value * TEST_AMPLITUDE_FULL);
                end
                1: begin // Half scale sine wave
                    sine_value = $sin(2.0 * 3.14159 * phase_left / SINE_SAMPLES);
                    audio_data_left <= $rtoi(sine_value * TEST_AMPLITUDE_HALF);
                    sine_value = $sin(2.0 * 3.14159 * phase_right / SINE_SAMPLES);
                    audio_data_right <= $rtoi(sine_value * TEST_AMPLITUDE_HALF);
                end
                2: begin // Quarter scale sine wave
                    sine_value = $sin(2.0 * 3.14159 * phase_left / SINE_SAMPLES);
                    audio_data_left <= $rtoi(sine_value * TEST_AMPLITUDE_QUARTER);
                    sine_value = $sin(2.0 * 3.14159 * phase_right / SINE_SAMPLES);
                    audio_data_right <= $rtoi(sine_value * TEST_AMPLITUDE_QUARTER);
                end
                3: begin // DC test
                    audio_data_left <= TEST_AMPLITUDE_HALF;
                    audio_data_right <= -TEST_AMPLITUDE_HALF;
                end
                4: begin // Silence
                    audio_data_left <= 24'b0;
                    audio_data_right <= 24'b0;
                end
            endcase
            
            audio_data_valid <= 1'b1;
            
            // Update phase
            phase_left <= (phase_left + 1) % SINE_SAMPLES;
            phase_right <= (phase_right + 1) % SINE_SAMPLES;
        end
    end
    
    // ========================================================================
    // TEST STIMULUS
    // ========================================================================
    
    initial begin
        $dumpfile("tb_dac_core.vcd");
        $dumpvars(0, tb_dac_core);
        
        // Initialize signals
        rst_n = 1'b0;
        dac_mode = 2'd2;                // Start in hybrid mode
        calibration_enable = 1'b1;      // Enable calibration
        calibration_target = 8'd128;    // Target for calibration
        r2r_trim_left = 4'd8;          // Center trim
        r2r_trim_right = 4'd8;         // Center trim
        i = 0;
        
        $display("Starting DAC Core Testbench");
        $display("============================");
        
        // Release reset
        #1000;
        $display("Time %0t: Releasing reset", $time);
        rst_n = 1'b1;
        
        // Wait for initial calibration
        $display("Time %0t: Waiting for calibration", $time);
        wait(calibration_done == 1'b1);
        $display("Time %0t: Calibration completed", $time);
        
        // Test 1: Hybrid mode with full scale signal
        $display("Time %0t: Test 1 - Hybrid mode, full scale", $time);
        dac_mode = 2'd2;
        i = 0;
        #20000;
        
        // Monitor THD+N
        $display("Time %0t: THD+N = %d, Noise floor = %d", 
                 $time, thd_measurement, noise_floor);
        
        // Test 2: R-2R only mode
        $display("Time %0t: Test 2 - R-2R only mode", $time);
        dac_mode = 2'd0;
        i = 1; // Half scale
        #20000;
        
        $display("Time %0t: THD+N = %d, Noise floor = %d", 
                 $time, thd_measurement, noise_floor);
        
        // Test 3: Sigma-Delta only mode
        $display("Time %0t: Test 3 - Sigma-Delta only mode", $time);
        dac_mode = 2'd1;
        i = 2; // Quarter scale
        #20000;
        
        $display("Time %0t: THD+N = %d, Noise floor = %d", 
                 $time, thd_measurement, noise_floor);
        
        // Test 4: DC linearity test
        $display("Time %0t: Test 4 - DC linearity", $time);
        dac_mode = 2'd2; // Back to hybrid
        i = 3; // DC signals
        #15000;
        
        // Test 5: Silence (noise floor measurement)
        $display("Time %0t: Test 5 - Noise floor measurement", $time);
        i = 4; // Silence
        #15000;
        
        $display("Time %0t: Final noise floor = %d", $time, noise_floor);
        
        // Test 6: Trim adjustment
        $display("Time %0t: Test 6 - R-2R trim adjustment", $time);
        dac_mode = 2'd0; // R-2R only for trim test
        i = 0; // Full scale sine
        r2r_trim_left = 4'd12;  // Increase left trim
        r2r_trim_right = 4'd4;  // Decrease right trim
        #20000;
        
        // Test 7: Recalibration
        $display("Time %0t: Test 7 - Recalibration", $time);
        calibration_enable = 1'b0;
        #1000;
        calibration_enable = 1'b1;
        wait(calibration_done == 1'b1);
        $display("Time %0t: Recalibration completed", $time);
        
        // Reset trims to center
        r2r_trim_left = 4'd8;
        r2r_trim_right = 4'd8;
        dac_mode = 2'd2; // Back to hybrid
        #10000;
        
        // Monitor DAC status
        $display("Time %0t: DAC Status = %b", $time, dac_status);
        $display("  R-2R Ready: %b", dac_status[7]);
        $display("  Sigma-Delta Ready: %b", dac_status[6]);
        $display("  Calibration Active: %b", dac_status[5]);
        $display("  Temperature OK: %b", dac_status[4]);
        $display("  References OK: %b", dac_status[3]);
        $display("  Output Valid: %b", dac_status[2]);
        
        if (thermal_warning) begin
            $display("Time %0t: WARNING - Thermal warning active", $time);
        end
        
        // Run for remaining simulation time
        #(SIMULATION_TIME - $time);
        
        $display("Time %0t: Simulation completed", $time);
        $display("============================");
        $display("Final Measurements:");
        $display("  THD+N: %d", thd_measurement);
        $display("  Noise Floor: %d", noise_floor);
        $display("  DAC Status: %b", dac_status);
        $display("  Thermal Warning: %b", thermal_warning);
        
        $finish;
    end
    
    // ========================================================================
    // MONITORS AND ANALYSIS
    // ========================================================================
    
    // Monitor calibration process
    always @(posedge calibration_done) begin
        $display("Time %0t: Calibration cycle completed", $time);
    end
    
    always @(negedge calibration_done) begin
        if (rst_n) begin
            $display("Time %0t: Calibration started", $time);
        end
    end
    
    // Monitor DAC mode changes
    always @(dac_mode) begin
        case (dac_mode)
            2'd0: $display("Time %0t: DAC mode changed to R-2R only", $time);
            2'd1: $display("Time %0t: DAC mode changed to Sigma-Delta only", $time);
            2'd2: $display("Time %0t: DAC mode changed to Hybrid", $time);
            default: $display("Time %0t: DAC mode changed to unknown", $time);
        endcase
    end
    
    // Monitor analog outputs (simplified digital representation)
    always @(posedge clk_dac) begin
        // In a real simulation, these would be analog voltages
        // Here we just monitor the digital representations
    end
    
    // Performance monitoring
    reg [15:0] thd_history [0:15];
    reg [3:0] thd_index;
    
    always @(posedge clk_audio) begin
        if (!rst_n) begin
            thd_index <= 4'b0;
        end else begin
            // Store THD measurements for trending
            thd_history[thd_index] <= thd_measurement;
            thd_index <= thd_index + 1;
            
            // Report THD trend every 16 samples
            if (thd_index == 4'hF) begin
                $display("Time %0t: THD trend analysis completed", $time);
            end
        end
    end
    
    // Thermal monitoring
    always @(temperature_sensor) begin
        if (temperature_sensor > 8'd200) begin // Hot threshold
            $warning("High temperature detected: %d", temperature_sensor);
        end
    end
    
    always @(posedge thermal_warning) begin
        $warning("Time %0t: Thermal warning asserted", $time);
    end

endmodule