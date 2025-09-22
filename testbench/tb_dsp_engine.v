/*
 * Testbench for Digital Signal Processing Engine
 * Tests oversampling, FIR filtering, and audio processing pipeline
 */

`timescale 1ns / 1ps

module tb_dsp_engine;

    // ========================================================================
    // TEST PARAMETERS
    // ========================================================================
    parameter CLK_PERIOD = 20.0;           // 50 MHz DSP clock (20ns)
    parameter AUDIO_CLK_PERIOD = 325.52;   // 3.072 MHz audio clock (325.52ns)
    parameter SIMULATION_TIME = 500000;     // 500us simulation time
    
    // ========================================================================
    // DUT SIGNALS
    // ========================================================================
    
    // Clocks and Reset
    reg clk_dsp;
    reg clk_audio;
    reg rst_n;
    
    // Input Audio
    reg [23:0] audio_in_left;
    reg [23:0] audio_in_right;
    reg audio_in_valid;
    
    // Configuration
    reg [7:0] oversample_ratio;    // 4, 8, or 16
    reg [3:0] eq_band_select;
    reg [15:0] eq_gain;
    reg eq_config_valid;
    reg dither_enable;
    reg [1:0] noise_shaping_order;
    
    // Outputs
    wire [23:0] audio_out_left;
    wire [23:0] audio_out_right;
    wire audio_out_valid;
    wire [7:0] dsp_status;
    wire processing_active;
    
    // ========================================================================
    // TEST VARIABLES
    // ========================================================================
    integer i, j;
    real sine_value;
    integer phase_accumulator;
    parameter SINE_FREQUENCY = 1000;       // 1kHz test tone
    parameter SAMPLE_RATE = 48000;         // 48kHz sample rate
    parameter PHASE_INCREMENT = (SINE_FREQUENCY * 65536) / SAMPLE_RATE;
    
    // ========================================================================
    // DEVICE UNDER TEST
    // ========================================================================
    dsp_engine dut (
        .clk_dsp(clk_dsp),
        .clk_audio(clk_audio),
        .rst_n(rst_n),
        
        .audio_in_left(audio_in_left),
        .audio_in_right(audio_in_right),
        .audio_in_valid(audio_in_valid),
        
        .oversample_ratio(oversample_ratio),
        .eq_band_select(eq_band_select),
        .eq_gain(eq_gain),
        .eq_config_valid(eq_config_valid),
        .dither_enable(dither_enable),
        .noise_shaping_order(noise_shaping_order),
        
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right),
        .audio_out_valid(audio_out_valid),
        .dsp_status(dsp_status),
        .processing_active(processing_active)
    );
    
    // ========================================================================
    // CLOCK GENERATION
    // ========================================================================
    
    // DSP processing clock (50 MHz)
    always begin
        clk_dsp = 1'b0;
        #(CLK_PERIOD/2);
        clk_dsp = 1'b1;
        #(CLK_PERIOD/2);
    end
    
    // Audio sample clock (3.072 MHz)
    always begin
        clk_audio = 1'b0;
        #(AUDIO_CLK_PERIOD/2);
        clk_audio = 1'b1;
        #(AUDIO_CLK_PERIOD/2);
    end
    
    // ========================================================================
    // AUDIO TEST SIGNAL GENERATION
    // ========================================================================
    
    // Generate test sine wave
    always @(posedge clk_audio) begin
        if (!rst_n) begin
            phase_accumulator <= 0;
            audio_in_left <= 24'b0;
            audio_in_right <= 24'b0;
            audio_in_valid <= 1'b0;
        end else begin
            // Generate 1kHz sine wave
            sine_value = $sin(2.0 * 3.14159 * phase_accumulator / 65536.0);
            
            // Left channel: full amplitude
            audio_in_left <= $rtoi(sine_value * 24'h7FFFFF);
            
            // Right channel: half amplitude with slight phase shift
            audio_in_right <= $rtoi(sine_value * 24'h3FFFFF);
            
            audio_in_valid <= 1'b1;
            
            // Update phase accumulator
            phase_accumulator <= phase_accumulator + PHASE_INCREMENT;
            if (phase_accumulator >= 65536) begin
                phase_accumulator <= phase_accumulator - 65536;
            end
        end
    end
    
    // ========================================================================
    // TEST STIMULUS
    // ========================================================================
    
    initial begin
        $dumpfile("tb_dsp_engine.vcd");
        $dumpvars(0, tb_dsp_engine);
        
        // Initialize signals
        rst_n = 1'b0;
        oversample_ratio = 8'd8;        // Start with 8x oversampling
        eq_band_select = 4'd0;          // Band 0 (20-100 Hz)
        eq_gain = 16'h8000;             // Unity gain (0 dB)
        eq_config_valid = 1'b0;
        dither_enable = 1'b1;           // Enable dither
        noise_shaping_order = 2'd2;     // 2nd order noise shaping
        
        $display("Starting DSP Engine Testbench");
        $display("================================");
        
        // Release reset
        #1000;
        $display("Time %0t: Releasing reset", $time);
        rst_n = 1'b1;
        
        // Wait for processing to start
        #5000;
        wait(processing_active == 1'b1);
        $display("Time %0t: DSP processing active", $time);
        
        // Test 1: Basic audio processing with 8x oversampling
        $display("Time %0t: Test 1 - 8x Oversampling", $time);
        oversample_ratio = 8'd8;
        #50000;
        
        // Check output validity
        wait(audio_out_valid == 1'b1);
        $display("Time %0t: Audio output valid, Left=%h, Right=%h", 
                 $time, audio_out_left, audio_out_right);
        
        // Test 2: Change to 16x oversampling
        $display("Time %0t: Test 2 - 16x Oversampling", $time);
        oversample_ratio = 8'd16;
        #50000;
        
        // Test 3: Configure equalizer - boost bass
        $display("Time %0t: Test 3 - EQ Bass Boost", $time);
        eq_band_select = 4'd0;          // Bass band
        eq_gain = 16'hA000;             // +3dB boost
        eq_config_valid = 1'b1;
        #1000;
        eq_config_valid = 1'b0;
        #30000;
        
        // Test 4: Configure equalizer - boost treble
        $display("Time %0t: Test 4 - EQ Treble Boost", $time);
        eq_band_select = 4'd9;          // Treble band
        eq_gain = 16'hB000;             // +6dB boost
        eq_config_valid = 1'b1;
        #1000;
        eq_config_valid = 1'b0;
        #30000;
        
        // Test 5: Disable dither
        $display("Time %0t: Test 5 - Disable Dither", $time);
        dither_enable = 1'b0;
        #30000;
        
        // Test 6: Change noise shaping order
        $display("Time %0t: Test 6 - 3rd Order Noise Shaping", $time);
        dither_enable = 1'b1;
        noise_shaping_order = 2'd3;
        #30000;
        
        // Test 7: 4x oversampling for comparison
        $display("Time %0t: Test 7 - 4x Oversampling", $time);
        oversample_ratio = 8'd4;
        #50000;
        
        // Monitor DSP status
        $display("Time %0t: DSP Status = %b", $time, dsp_status);
        $display("  Processing Active: %b", dsp_status[7]);
        $display("  Oversampling Ready: %b", dsp_status[6]);
        $display("  FIR Filter Ready: %b", dsp_status[5]);
        $display("  EQ Ready: %b", dsp_status[4]);
        $display("  Dither Active: %b", dsp_status[3]);
        $display("  Noise Shaping Active: %b", dsp_status[2]);
        
        // Run for remaining simulation time
        #(SIMULATION_TIME - $time);
        
        $display("Time %0t: Simulation completed", $time);
        $display("================================");
        $display("Final Status:");
        $display("  Processing Active: %b", processing_active);
        $display("  DSP Status: %b", dsp_status);
        $display("  Oversample Ratio: %d", oversample_ratio);
        
        $finish;
    end
    
    // ========================================================================
    // MONITORS AND PERFORMANCE ANALYSIS
    // ========================================================================
    
    // Monitor audio output
    always @(posedge audio_out_valid) begin
        $display("Time %0t: Audio sample - Left=%h (%d), Right=%h (%d)", 
                 $time, audio_out_left, $signed(audio_out_left), 
                 audio_out_right, $signed(audio_out_right));
    end
    
    // Monitor processing status changes
    always @(posedge processing_active) begin
        $display("Time %0t: DSP processing started", $time);
    end
    
    always @(negedge processing_active) begin
        $display("Time %0t: DSP processing stopped", $time);
    end
    
    // Monitor oversample ratio changes
    always @(oversample_ratio) begin
        $display("Time %0t: Oversample ratio changed to %dx", $time, oversample_ratio);
    end
    
    // Monitor EQ configuration
    always @(posedge eq_config_valid) begin
        $display("Time %0t: EQ configured - Band %d, Gain %h", 
                 $time, eq_band_select, eq_gain);
    end
    
    // Calculate THD+N (simplified)
    reg [31:0] signal_sum_left, signal_sum_right;
    reg [31:0] sample_count;
    
    always @(posedge clk_audio) begin
        if (!rst_n) begin
            signal_sum_left <= 32'b0;
            signal_sum_right <= 32'b0;
            sample_count <= 32'b0;
        end else if (audio_out_valid) begin
            signal_sum_left <= signal_sum_left + (audio_out_left[23] ? 
                                ~audio_out_left + 1 : audio_out_left);
            signal_sum_right <= signal_sum_right + (audio_out_right[23] ? 
                                ~audio_out_right + 1 : audio_out_right);
            sample_count <= sample_count + 1;
            
            // Report average signal level every 1000 samples
            if (sample_count[9:0] == 10'h3FF) begin
                $display("Time %0t: Avg signal level - Left=%d, Right=%d", 
                         $time, signal_sum_left >> 10, signal_sum_right >> 10);
            end
        end
    end
    
    // Performance counters
    reg [31:0] cycle_count;
    reg [31:0] output_count;
    
    always @(posedge clk_dsp) begin
        if (!rst_n) begin
            cycle_count <= 32'b0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
    end
    
    always @(posedge audio_out_valid) begin
        if (!rst_n) begin
            output_count <= 32'b0;
        end else begin
            output_count <= output_count + 1;
        end
    end
    
    // Report performance statistics
    always @(posedge clk_audio) begin
        if (sample_count[11:0] == 12'hFFF) begin // Every 4096 samples
            $display("Time %0t: Performance - Cycles=%d, Outputs=%d, Efficiency=%d%%", 
                     $time, cycle_count, output_count, 
                     (output_count * 100) / (cycle_count >> 10));
        end
    end

endmodule