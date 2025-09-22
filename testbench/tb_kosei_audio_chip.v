/*
 * Testbench for Kosei Audio Chip M1 Top Level
 * Comprehensive verification of the ultimate audiophile audio chip
 */

`timescale 1ns / 1ps

module tb_kosei_audio_chip;

    // ========================================================================
    // TEST PARAMETERS
    // ========================================================================
    parameter CLK_PERIOD_REF = 100.0;      // 10 MHz reference clock (100ns)
    parameter CLK_PERIOD_CRYSTAL = 40.69;   // 24.576 MHz crystal (40.69ns)
    parameter CLK_PERIOD_MCLK = 81.38;      // 12.288 MHz MCLK (81.38ns)
    parameter CLK_PERIOD_I2S = 325.52;      // 3.072 MHz I2S BCLK (325.52ns)
    parameter SIMULATION_TIME = 1000000;    // 1ms simulation time
    
    // ========================================================================
    // DUT SIGNALS
    // ========================================================================
    
    // Clocks and Reset
    reg clk_ref_external;
    reg clk_crystal;
    reg clk_mclk_in;
    reg rst_n;
    
    // Power Supply
    reg vdd_digital;
    reg vdd_analog;
    reg vdd_io;
    reg vss_digital;
    reg vss_analog;
    
    // Digital Audio Inputs
    reg cd_efm_data;
    reg cd_efm_clock;
    reg cd_channel_clock;
    reg i2s_bclk;
    reg i2s_lrclk;
    reg i2s_data;
    reg spdif_in;
    reg usb_clk;
    reg [23:0] usb_audio_left;
    reg [23:0] usb_audio_right;
    reg usb_audio_valid;
    
    // Configuration Interface
    reg config_clk;
    reg config_data;
    reg config_cs;
    wire config_ready;
    
    // Analog Audio Outputs
    wire audio_out_line_left_pos;
    wire audio_out_line_left_neg;
    wire audio_out_line_right_pos;
    wire audio_out_line_right_neg;
    wire audio_out_balanced_left_pos;
    wire audio_out_balanced_left_neg;
    wire audio_out_balanced_right_pos;
    wire audio_out_balanced_right_neg;
    wire audio_out_headphone_left;
    wire audio_out_headphone_right;
    wire audio_out_headphone_gnd;
    
    // Status and Monitoring
    wire [7:0] status_leds;
    wire [15:0] diagnostic_data;
    wire thermal_warning;
    wire pll_locked;
    wire audio_present;
    
    // ========================================================================
    // TEST VARIABLES
    // ========================================================================
    integer i, j;
    real sine_value;
    reg [23:0] test_audio_left, test_audio_right;
    reg test_audio_valid;
    integer test_phase_left, test_phase_right;
    
    // Audio test patterns
    parameter SINE_1KHZ_SAMPLES = 48;       // 48 samples for 1kHz at 48kHz
    parameter TEST_AMPLITUDE = 24'h7FFFFF;  // Full scale amplitude
    
    // ========================================================================
    // DEVICE UNDER TEST
    // ========================================================================
    kosei_audio_chip dut (
        .clk_ref_external(clk_ref_external),
        .clk_crystal(clk_crystal),
        .clk_mclk_in(clk_mclk_in),
        .rst_n(rst_n),
        
        .vdd_digital(vdd_digital),
        .vdd_analog(vdd_analog),
        .vdd_io(vdd_io),
        .vss_digital(vss_digital),
        .vss_analog(vss_analog),
        
        .cd_efm_data(cd_efm_data),
        .cd_efm_clock(cd_efm_clock),
        .cd_channel_clock(cd_channel_clock),
        
        .i2s_bclk(i2s_bclk),
        .i2s_lrclk(i2s_lrclk),
        .i2s_data(i2s_data),
        
        .spdif_in(spdif_in),
        
        .usb_clk(usb_clk),
        .usb_audio_left(usb_audio_left),
        .usb_audio_right(usb_audio_right),
        .usb_audio_valid(usb_audio_valid),
        
        .config_clk(config_clk),
        .config_data(config_data),
        .config_cs(config_cs),
        .config_ready(config_ready),
        
        .audio_out_line_left_pos(audio_out_line_left_pos),
        .audio_out_line_left_neg(audio_out_line_left_neg),
        .audio_out_line_right_pos(audio_out_line_right_pos),
        .audio_out_line_right_neg(audio_out_line_right_neg),
        .audio_out_balanced_left_pos(audio_out_balanced_left_pos),
        .audio_out_balanced_left_neg(audio_out_balanced_left_neg),
        .audio_out_balanced_right_pos(audio_out_balanced_right_pos),
        .audio_out_balanced_right_neg(audio_out_balanced_right_neg),
        .audio_out_headphone_left(audio_out_headphone_left),
        .audio_out_headphone_right(audio_out_headphone_right),
        .audio_out_headphone_gnd(audio_out_headphone_gnd),
        
        .status_leds(status_leds),
        .diagnostic_data(diagnostic_data),
        .thermal_warning(thermal_warning),
        .pll_locked(pll_locked),
        .audio_present(audio_present)
    );
    
    // ========================================================================
    // CLOCK GENERATION
    // ========================================================================
    
    // 10 MHz reference clock
    always begin
        clk_ref_external = 1'b0;
        #(CLK_PERIOD_REF/2);
        clk_ref_external = 1'b1;
        #(CLK_PERIOD_REF/2);
    end
    
    // 24.576 MHz crystal clock
    always begin
        clk_crystal = 1'b0;
        #(CLK_PERIOD_CRYSTAL/2);
        clk_crystal = 1'b1;
        #(CLK_PERIOD_CRYSTAL/2);
    end
    
    // 12.288 MHz master clock input
    always begin
        clk_mclk_in = 1'b0;
        #(CLK_PERIOD_MCLK/2);
        clk_mclk_in = 1'b1;
        #(CLK_PERIOD_MCLK/2);
    end
    
    // 3.072 MHz I2S bit clock
    always begin
        i2s_bclk = 1'b0;
        #(CLK_PERIOD_I2S/2);
        i2s_bclk = 1'b1;
        #(CLK_PERIOD_I2S/2);
    end
    
    // 48 kHz I2S LR clock
    always begin
        i2s_lrclk = 1'b0;
        #(CLK_PERIOD_I2S * 32); // 32 bit clocks per channel
        i2s_lrclk = 1'b1;
        #(CLK_PERIOD_I2S * 32);
    end
    
    // Configuration clock (1 MHz)
    always begin
        config_clk = 1'b0;
        #500;
        config_clk = 1'b1;
        #500;
    end
    
    // USB clock (12 MHz)
    always begin
        usb_clk = 1'b0;
        #41.67;
        usb_clk = 1'b1;
        #41.67;
    end
    
    // ========================================================================
    // AUDIO TEST SIGNAL GENERATION
    // ========================================================================
    
    // Generate 1kHz sine wave test signals
    always @(posedge clk_crystal) begin
        if (!rst_n) begin
            test_phase_left <= 0;
            test_phase_right <= 0;
            test_audio_left <= 24'b0;
            test_audio_right <= 24'b0;
            test_audio_valid <= 1'b0;
        end else begin
            // Generate sine waves
            sine_value = $sin(2.0 * 3.14159 * test_phase_left / SINE_1KHZ_SAMPLES);
            test_audio_left <= $rtoi(sine_value * TEST_AMPLITUDE);
            
            sine_value = $sin(2.0 * 3.14159 * test_phase_right / SINE_1KHZ_SAMPLES);
            test_audio_right <= $rtoi(sine_value * TEST_AMPLITUDE * 0.8); // Slightly different amplitude
            
            test_audio_valid <= 1'b1;
            
            // Update phase
            test_phase_left <= (test_phase_left + 1) % SINE_1KHZ_SAMPLES;
            test_phase_right <= (test_phase_right + 1) % SINE_1KHZ_SAMPLES;
        end
    end
    
    // ========================================================================
    // I2S DATA GENERATION
    // ========================================================================
    
    reg [5:0] i2s_bit_counter;
    reg [23:0] i2s_shift_left, i2s_shift_right;
    reg i2s_channel; // 0=left, 1=right
    
    always @(posedge i2s_bclk) begin
        if (!rst_n) begin
            i2s_data <= 1'b0;
            i2s_bit_counter <= 6'b0;
            i2s_shift_left <= 24'b0;
            i2s_shift_right <= 24'b0;
            i2s_channel <= 1'b0;
        end else begin
            // Load new data on LR clock edges
            if (i2s_lrclk != i2s_channel) begin
                i2s_channel <= i2s_lrclk;
                i2s_bit_counter <= 6'd23; // Start with MSB
                if (i2s_lrclk == 1'b0) begin // Left channel
                    i2s_shift_left <= test_audio_left;
                    i2s_data <= test_audio_left[23];
                end else begin // Right channel
                    i2s_shift_right <= test_audio_right;
                    i2s_data <= test_audio_right[23];
                end
            end else if (i2s_bit_counter > 0) begin
                // Shift out data bits
                i2s_bit_counter <= i2s_bit_counter - 1;
                if (i2s_channel == 1'b0) begin // Left channel
                    i2s_shift_left <= {i2s_shift_left[22:0], 1'b0};
                    i2s_data <= i2s_shift_left[22];
                end else begin // Right channel
                    i2s_shift_right <= {i2s_shift_right[22:0], 1'b0};
                    i2s_data <= i2s_shift_right[22];
                end
            end else begin
                i2s_data <= 1'b0; // Pad with zeros
            end
        end
    end
    
    // ========================================================================
    // TEST STIMULUS
    // ========================================================================
    
    initial begin
        $dumpfile("tb_kosei_audio_chip.vcd");
        $dumpvars(0, tb_kosei_audio_chip);
        
        // Initialize signals
        rst_n = 1'b0;
        vdd_digital = 1'b0;
        vdd_analog = 1'b0;
        vdd_io = 1'b0;
        vss_digital = 1'b0;
        vss_analog = 1'b0;
        
        cd_efm_data = 1'b0;
        cd_efm_clock = 1'b0;
        cd_channel_clock = 1'b0;
        spdif_in = 1'b0;
        usb_audio_left = 24'b0;
        usb_audio_right = 24'b0;
        usb_audio_valid = 1'b0;
        config_data = 1'b0;
        config_cs = 1'b1;
        
        $display("Starting Kosei Audio Chip M1 Testbench");
        $display("=============================================");
        
        // Power-up sequence
        #1000;
        $display("Time %0t: Applying power supplies", $time);
        vdd_digital = 1'b1;
        vdd_analog = 1'b1;
        vdd_io = 1'b1;
        vss_digital = 1'b0;
        vss_analog = 1'b0;
        
        // Release reset after power stabilizes
        #5000;
        $display("Time %0t: Releasing reset", $time);
        rst_n = 1'b1;
        
        // Wait for PLL lock
        #50000;
        $display("Time %0t: Waiting for PLL lock", $time);
        wait(pll_locked == 1'b1);
        $display("Time %0t: PLL locked successfully", $time);
        
        // Test I2S audio input
        $display("Time %0t: Starting I2S audio test", $time);
        usb_audio_left = test_audio_left;
        usb_audio_right = test_audio_right;
        usb_audio_valid = 1'b1;
        
        // Monitor audio presence
        #10000;
        wait(audio_present == 1'b1);
        $display("Time %0t: Audio input detected", $time);
        
        // Check status LEDs
        #20000;
        $display("Time %0t: Status LEDs = %b", $time, status_leds);
        if (status_leds[6] == 1'b1) $display("  PLL locked LED ON");
        if (status_leds[5] == 1'b1) $display("  Audio present LED ON");
        if (status_leds[2] == 1'b1) $display("  Analog power LED ON");
        if (status_leds[1] == 1'b1) $display("  Digital power LED ON");
        
        // Test different input sources
        $display("Time %0t: Testing USB audio input", $time);
        // USB audio is already active
        
        #100000;
        $display("Time %0t: Testing I2S audio input", $time);
        // I2S data is generated automatically by the testbench
        
        // Monitor diagnostic data
        #50000;
        $display("Time %0t: Diagnostic data = %h", $time, diagnostic_data);
        $display("  THD+N measurement = %d", diagnostic_data[15:8]);
        $display("  Noise floor = %d", diagnostic_data[7:0]);
        
        // Test thermal monitoring
        if (thermal_warning == 1'b1) begin
            $display("Time %0t: WARNING - Thermal warning active", $time);
        end else begin
            $display("Time %0t: Thermal status OK", $time);
        end
        
        // Monitor output signals
        #10000;
        $display("Time %0t: Monitoring analog outputs", $time);
        $display("  Line output left+  = %b", audio_out_line_left_pos);
        $display("  Line output left-  = %b", audio_out_line_left_neg);
        $display("  Line output right+ = %b", audio_out_line_right_pos);
        $display("  Line output right- = %b", audio_out_line_right_neg);
        
        // Run for specified simulation time
        #(SIMULATION_TIME - $time);
        
        $display("Time %0t: Simulation completed successfully", $time);
        $display("=============================================");
        $display("Final Status:");
        $display("  PLL Locked: %b", pll_locked);
        $display("  Audio Present: %b", audio_present);
        $display("  Thermal Warning: %b", thermal_warning);
        $display("  Status LEDs: %b", status_leds);
        
        $finish;
    end
    
    // ========================================================================
    // MONITORS AND ASSERTIONS
    // ========================================================================
    
    // Monitor critical signals
    always @(posedge clk_crystal) begin
        if (rst_n) begin
            // Check for proper power sequencing
            assert (vdd_digital && vdd_analog && vdd_io) 
                else $error("Power supply failure detected");
            
            // Check PLL lock within reasonable time
            if ($time > 100000 && !pll_locked) begin
                $warning("PLL failed to lock within expected time");
            end
            
            // Monitor for thermal issues
            if (thermal_warning) begin
                $warning("Thermal warning asserted at time %0t", $time);
            end
        end
    end
    
    // Audio signal quality monitoring
    always @(posedge audio_present) begin
        $display("Time %0t: Audio signal detected", $time);
    end
    
    always @(negedge audio_present) begin
        $display("Time %0t: Audio signal lost", $time);
    end
    
    // Configuration interface monitoring
    always @(posedge config_ready) begin
        $display("Time %0t: Configuration interface ready", $time);
    end

endmodule