/*
 * Analog Output Module for Kosei Audio Chip M1
 * Class-A Differential Buffers, Low-Noise Op-Amps, and Multiple Output Modes
 */

module analog_output (
    // System interface
    input wire clk_dac_hs,
    input wire clk_analog,       // Slower clock for analog control
    input wire rst_n,
    
    // DAC inputs (differential)
    input wire dac_left_pos,
    input wire dac_left_neg,
    input wire dac_right_pos,
    input wire dac_right_neg,
    
    // Configuration
    input wire [7:0] config_output_mode,   // 0=line, 1=balanced, 2=headphone
    input wire [7:0] config_analog_filter, // Reconstruction filter settings
    input wire [7:0] config_preamp_gain,   // Optional preamp gain
    input wire [7:0] config_volume,        // Analog volume control
    
    // Power management
    input wire analog_power_enable,
    input wire class_a_bias_enable,
    
    // Multiple output modes
    output wire audio_out_line_left_pos,
    output wire audio_out_line_left_neg,
    output wire audio_out_line_right_pos,
    output wire audio_out_line_right_neg,
    
    output wire audio_out_balanced_left_pos,
    output wire audio_out_balanced_left_neg,
    output wire audio_out_balanced_right_pos,
    output wire audio_out_balanced_right_neg,
    
    output wire audio_out_headphone_left,
    output wire audio_out_headphone_right,
    output wire audio_out_headphone_gnd,
    
    // Analog control signals
    output wire [7:0] analog_status_flags,
    output wire [11:0] bias_current_monitor,
    output wire [11:0] thermal_monitor
);

    // Internal analog signals
    wire filtered_left_pos, filtered_left_neg;
    wire filtered_right_pos, filtered_right_neg;
    wire preamp_left_pos, preamp_left_neg;
    wire preamp_right_pos, preamp_right_neg;
    wire volume_left_pos, volume_left_neg;
    wire volume_right_pos, volume_right_neg;
    
    // ============================================================================
    // Analog Reconstruction Filters
    // ============================================================================
    
    analog_reconstruction_filter recon_filter (
        .clk_analog(clk_analog),
        .rst_n(rst_n),
        .config_analog_filter(config_analog_filter),
        .dac_left_pos(dac_left_pos),
        .dac_left_neg(dac_left_neg),
        .dac_right_pos(dac_right_pos),
        .dac_right_neg(dac_right_neg),
        .analog_power_enable(analog_power_enable),
        .filtered_left_pos(filtered_left_pos),
        .filtered_left_neg(filtered_left_neg),
        .filtered_right_pos(filtered_right_pos),
        .filtered_right_neg(filtered_right_neg)
    );
    
    // ============================================================================
    // Optional Analog Preamp Stage
    // ============================================================================
    
    analog_preamp_stage preamp (
        .clk_analog(clk_analog),
        .rst_n(rst_n),
        .config_preamp_gain(config_preamp_gain),
        .analog_power_enable(analog_power_enable),
        .class_a_bias_enable(class_a_bias_enable),
        .audio_left_pos_in(filtered_left_pos),
        .audio_left_neg_in(filtered_left_neg),
        .audio_right_pos_in(filtered_right_pos),
        .audio_right_neg_in(filtered_right_neg),
        .audio_left_pos_out(preamp_left_pos),
        .audio_left_neg_out(preamp_left_neg),
        .audio_right_pos_out(preamp_right_pos),
        .audio_right_neg_out(preamp_right_neg),
        .bias_current_monitor(bias_current_monitor)
    );
    
    // ============================================================================
    // Analog Volume Control
    // ============================================================================
    
    analog_volume_control volume_ctrl (
        .clk_analog(clk_analog),
        .rst_n(rst_n),
        .config_volume(config_volume),
        .analog_power_enable(analog_power_enable),
        .audio_left_pos_in(preamp_left_pos),
        .audio_left_neg_in(preamp_left_neg),
        .audio_right_pos_in(preamp_right_pos),
        .audio_right_neg_in(preamp_right_neg),
        .audio_left_pos_out(volume_left_pos),
        .audio_left_neg_out(volume_left_neg),
        .audio_right_pos_out(volume_right_pos),
        .audio_right_neg_out(volume_right_neg)
    );
    
    // ============================================================================
    // Class-A Differential Buffer Stages
    // ============================================================================
    
    class_a_differential_buffers buffers (
        .clk_analog(clk_analog),
        .rst_n(rst_n),
        .config_output_mode(config_output_mode),
        .analog_power_enable(analog_power_enable),
        .class_a_bias_enable(class_a_bias_enable),
        .audio_left_pos_in(volume_left_pos),
        .audio_left_neg_in(volume_left_neg),
        .audio_right_pos_in(volume_right_pos),
        .audio_right_neg_in(volume_right_neg),
        
        // Line outputs
        .line_left_pos_out(audio_out_line_left_pos),
        .line_left_neg_out(audio_out_line_left_neg),
        .line_right_pos_out(audio_out_line_right_pos),
        .line_right_neg_out(audio_out_line_right_neg),
        
        // Balanced outputs
        .balanced_left_pos_out(audio_out_balanced_left_pos),
        .balanced_left_neg_out(audio_out_balanced_left_neg),
        .balanced_right_pos_out(audio_out_balanced_right_pos),
        .balanced_right_neg_out(audio_out_balanced_right_neg),
        
        // Headphone outputs
        .headphone_left_out(audio_out_headphone_left),
        .headphone_right_out(audio_out_headphone_right),
        .headphone_gnd_out(audio_out_headphone_gnd),
        
        .thermal_monitor(thermal_monitor),
        .status_flags(analog_status_flags)
    );

endmodule

// ============================================================================
// Analog Reconstruction Filter
// ============================================================================

module analog_reconstruction_filter (
    input wire clk_analog,
    input wire rst_n,
    input wire [7:0] config_analog_filter,
    input wire dac_left_pos,
    input wire dac_left_neg,
    input wire dac_right_pos,
    input wire dac_right_neg,
    input wire analog_power_enable,
    output reg filtered_left_pos,
    output reg filtered_left_neg,
    output reg filtered_right_pos,
    output reg filtered_right_neg
);

    // Simplified analog filter model (in real chip, this would be analog circuitry)
    // This represents the digital control of analog filter characteristics
    
    reg [7:0] filter_coeff_low, filter_coeff_high;
    reg [15:0] filter_state_left_pos, filter_state_left_neg;
    reg [15:0] filter_state_right_pos, filter_state_right_neg;
    
    always @(posedge clk_analog or negedge rst_n) begin
        if (!rst_n) begin
            filter_coeff_low <= 8'h80;
            filter_coeff_high <= 8'h20;
            filter_state_left_pos <= 16'b0;
            filter_state_left_neg <= 16'b0;
            filter_state_right_pos <= 16'b0;
            filter_state_right_neg <= 16'b0;
            filtered_left_pos <= 1'b0;
            filtered_left_neg <= 1'b0;
            filtered_right_pos <= 1'b0;
            filtered_right_neg <= 1'b0;
        end else if (analog_power_enable) begin
            // Configure filter characteristics based on settings
            case (config_analog_filter[2:0])
                3'b000: begin // Sharp rolloff
                    filter_coeff_low <= 8'hA0;
                    filter_coeff_high <= 8'h10;
                end
                3'b001: begin // Moderate rolloff
                    filter_coeff_low <= 8'h80;
                    filter_coeff_high <= 8'h30;
                end
                3'b010: begin // Gentle rolloff
                    filter_coeff_low <= 8'h60;
                    filter_coeff_high <= 8'h50;
                end
                default: begin // Bypass
                    filter_coeff_low <= 8'hFF;
                    filter_coeff_high <= 8'h00;
                end
            endcase
            
            // Simplified filter model (no multipliers)
            // In real implementation, this would control analog filter components
            filter_state_left_pos <= (filter_state_left_pos >> 1) + 
                                     ({15'b0, dac_left_pos} >> 2);
            filter_state_left_neg <= (filter_state_left_neg >> 1) + 
                                     ({15'b0, dac_left_neg} >> 2);
            filter_state_right_pos <= (filter_state_right_pos >> 1) + 
                                      ({15'b0, dac_right_pos} >> 2);
            filter_state_right_neg <= (filter_state_right_neg >> 1) + 
                                      ({15'b0, dac_right_neg} >> 2);
            
            // Output filtered signals
            filtered_left_pos <= filter_state_left_pos[15];
            filtered_left_neg <= filter_state_left_neg[15];
            filtered_right_pos <= filter_state_right_pos[15];
            filtered_right_neg <= filter_state_right_neg[15];
        end else begin
            // Power down - all outputs low
            filtered_left_pos <= 1'b0;
            filtered_left_neg <= 1'b0;
            filtered_right_pos <= 1'b0;
            filtered_right_neg <= 1'b0;
        end
    end

endmodule

// ============================================================================
// Analog Preamp Stage with Class-A Bias
// ============================================================================

module analog_preamp_stage (
    input wire clk_analog,
    input wire rst_n,
    input wire [7:0] config_preamp_gain,
    input wire analog_power_enable,
    input wire class_a_bias_enable,
    input wire audio_left_pos_in,
    input wire audio_left_neg_in,
    input wire audio_right_pos_in,
    input wire audio_right_neg_in,
    output reg audio_left_pos_out,
    output reg audio_left_neg_out,
    output reg audio_right_pos_out,
    output reg audio_right_neg_out,
    output reg [11:0] bias_current_monitor
);

    // Class-A bias control
    reg [11:0] bias_current_setting;
    reg [7:0] gain_setting;
    reg [15:0] preamp_state_left_pos, preamp_state_left_neg;
    reg [15:0] preamp_state_right_pos, preamp_state_right_neg;
    
    // Thermal management
    reg [11:0] thermal_accumulator;
    
    always @(posedge clk_analog or negedge rst_n) begin
        if (!rst_n) begin
            bias_current_setting <= 12'h800; // Mid-range bias
            gain_setting <= 8'h80; // Unity gain
            bias_current_monitor <= 12'b0;
            preamp_state_left_pos <= 16'b0;
            preamp_state_left_neg <= 16'b0;
            preamp_state_right_pos <= 16'b0;
            preamp_state_right_neg <= 16'b0;
            thermal_accumulator <= 12'b0;
            audio_left_pos_out <= 1'b0;
            audio_left_neg_out <= 1'b0;
            audio_right_pos_out <= 1'b0;
            audio_right_neg_out <= 1'b0;
        end else if (analog_power_enable && class_a_bias_enable) begin
            // Set gain based on configuration
            case (config_preamp_gain[3:0])
                4'b0000: gain_setting <= 8'h40;  // 0.5x gain
                4'b0001: gain_setting <= 8'h60;  // 0.75x gain
                4'b0010: gain_setting <= 8'h80;  // 1.0x gain (unity)
                4'b0011: gain_setting <= 8'hB0;  // 1.5x gain
                4'b0100: gain_setting <= 8'hE0;  // 2.0x gain
                4'b0101: gain_setting <= 8'hFF;  // 2.5x gain
                default: gain_setting <= 8'h80;  // Default unity
            endcase
            
            // Class-A bias current control
            if (config_preamp_gain[7]) begin // High current mode
                bias_current_setting <= 12'hC00;
            end else begin // Normal current mode
                bias_current_setting <= 12'h800;
            end
            
            // Simplified preamp gain stages (no multipliers)
            if (gain_setting[7]) begin  // High gain
                preamp_state_left_pos <= {audio_left_pos_in, 8'b0};  // Left shift for gain
                preamp_state_left_neg <= {audio_left_neg_in, 8'b0};
                preamp_state_right_pos <= {audio_right_pos_in, 8'b0};
                preamp_state_right_neg <= {audio_right_neg_in, 8'b0};
            end else begin  // Normal gain
                preamp_state_left_pos <= {8'b0, audio_left_pos_in};
                preamp_state_left_neg <= {8'b0, audio_left_neg_in};
                preamp_state_right_pos <= {8'b0, audio_right_pos_in};
                preamp_state_right_neg <= {8'b0, audio_right_neg_in};
            end
            
            // Output with Class-A characteristics (rail-to-rail)
            audio_left_pos_out <= preamp_state_left_pos[15];
            audio_left_neg_out <= preamp_state_left_neg[15];
            audio_right_pos_out <= preamp_state_right_pos[15];
            audio_right_neg_out <= preamp_state_right_neg[15];
            
            // Monitor bias current
            bias_current_monitor <= bias_current_setting;
            
            // Thermal accumulation for Class-A operation
            thermal_accumulator <= thermal_accumulator + (bias_current_setting >> 8);
        end else begin
            // Power down
            audio_left_pos_out <= 1'b0;
            audio_left_neg_out <= 1'b0;
            audio_right_pos_out <= 1'b0;
            audio_right_neg_out <= 1'b0;
            bias_current_monitor <= 12'b0;
        end
    end

endmodule

// ============================================================================
// Analog Volume Control
// ============================================================================

module analog_volume_control (
    input wire clk_analog,
    input wire rst_n,
    input wire [7:0] config_volume,
    input wire analog_power_enable,
    input wire audio_left_pos_in,
    input wire audio_left_neg_in,
    input wire audio_right_pos_in,
    input wire audio_right_neg_in,
    output reg audio_left_pos_out,
    output reg audio_left_neg_out,
    output reg audio_right_pos_out,
    output reg audio_right_neg_out
);

    // Volume control using digitally controlled analog attenuators
    reg [7:0] volume_attenuation;
    reg [15:0] volume_left_pos, volume_left_neg;
    reg [15:0] volume_right_pos, volume_right_neg;
    
    always @(posedge clk_analog or negedge rst_n) begin
        if (!rst_n) begin
            volume_attenuation <= 8'hFF; // Full volume
            volume_left_pos <= 16'b0;
            volume_left_neg <= 16'b0;
            volume_right_pos <= 16'b0;
            volume_right_neg <= 16'b0;
            audio_left_pos_out <= 1'b0;
            audio_left_neg_out <= 1'b0;
            audio_right_pos_out <= 1'b0;
            audio_right_neg_out <= 1'b0;
        end else if (analog_power_enable) begin
            // Convert volume setting to attenuation
            volume_attenuation <= config_volume;
            
            // Simplified volume control using shifts
            case (config_volume[7:6])
                2'b11: begin  // Full volume
                    volume_left_pos <= {8'b0, audio_left_pos_in};
                    volume_left_neg <= {8'b0, audio_left_neg_in};
                    volume_right_pos <= {8'b0, audio_right_pos_in};
                    volume_right_neg <= {8'b0, audio_right_neg_in};
                end
                2'b10: begin  // 1/2 volume
                    volume_left_pos <= {9'b0, audio_left_pos_in[7:1]};
                    volume_left_neg <= {9'b0, audio_left_neg_in[7:1]};
                    volume_right_pos <= {9'b0, audio_right_pos_in[7:1]};
                    volume_right_neg <= {9'b0, audio_right_neg_in[7:1]};
                end
                2'b01: begin  // 1/4 volume
                    volume_left_pos <= {10'b0, audio_left_pos_in[7:2]};
                    volume_left_neg <= {10'b0, audio_left_neg_in[7:2]};
                    volume_right_pos <= {10'b0, audio_right_pos_in[7:2]};
                    volume_right_neg <= {10'b0, audio_right_neg_in[7:2]};
                end
                default: begin  // Mute
                    volume_left_pos <= 16'b0;
                    volume_left_neg <= 16'b0;
                    volume_right_pos <= 16'b0;
                    volume_right_neg <= 16'b0;
                end
            endcase
            
            // Output attenuated signals
            audio_left_pos_out <= volume_left_pos[15];
            audio_left_neg_out <= volume_left_neg[15];
            audio_right_pos_out <= volume_right_pos[15];
            audio_right_neg_out <= volume_right_neg[15];
        end else begin
            // Muted when power disabled
            audio_left_pos_out <= 1'b0;
            audio_left_neg_out <= 1'b0;
            audio_right_pos_out <= 1'b0;
            audio_right_neg_out <= 1'b0;
        end
    end

endmodule

// ============================================================================
// Class-A Differential Buffers for Multiple Output Modes
// ============================================================================

module class_a_differential_buffers (
    input wire clk_analog,
    input wire rst_n,
    input wire [7:0] config_output_mode,
    input wire analog_power_enable,
    input wire class_a_bias_enable,
    input wire audio_left_pos_in,
    input wire audio_left_neg_in,
    input wire audio_right_pos_in,
    input wire audio_right_neg_in,
    
    // Line outputs (standard)
    output reg line_left_pos_out,
    output reg line_left_neg_out,
    output reg line_right_pos_out,
    output reg line_right_neg_out,
    
    // Balanced outputs (XLR)
    output reg balanced_left_pos_out,
    output reg balanced_left_neg_out,
    output reg balanced_right_pos_out,
    output reg balanced_right_neg_out,
    
    // Headphone outputs
    output reg headphone_left_out,
    output reg headphone_right_out,
    output reg headphone_gnd_out,
    
    output reg [11:0] thermal_monitor,
    output reg [7:0] status_flags
);

    // Buffer stages for different output modes
    reg [15:0] line_buffer_left_pos, line_buffer_left_neg;
    reg [15:0] line_buffer_right_pos, line_buffer_right_neg;
    reg [15:0] balanced_buffer_left_pos, balanced_buffer_left_neg;
    reg [15:0] balanced_buffer_right_pos, balanced_buffer_right_neg;
    reg [15:0] headphone_buffer_left, headphone_buffer_right;
    
    // Class-A bias and thermal management
    reg [11:0] class_a_bias_current;
    reg [11:0] thermal_accumulator;
    reg [7:0] output_drive_strength;
    
    always @(posedge clk_analog or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs
            line_left_pos_out <= 1'b0;
            line_left_neg_out <= 1'b0;
            line_right_pos_out <= 1'b0;
            line_right_neg_out <= 1'b0;
            balanced_left_pos_out <= 1'b0;
            balanced_left_neg_out <= 1'b0;
            balanced_right_pos_out <= 1'b0;
            balanced_right_neg_out <= 1'b0;
            headphone_left_out <= 1'b0;
            headphone_right_out <= 1'b0;
            headphone_gnd_out <= 1'b0;
            
            // Reset internal states
            class_a_bias_current <= 12'h600;
            thermal_accumulator <= 12'b0;
            output_drive_strength <= 8'h80;
            thermal_monitor <= 12'b0;
            status_flags <= 8'b0;
        end else if (analog_power_enable) begin
            
            // Configure output characteristics based on mode
            case (config_output_mode[2:0])
                3'b000: begin // Line output mode
                    output_drive_strength <= 8'h60; // Lower drive for line
                    class_a_bias_current <= 12'h400;
                    
                    // Simplified line output buffers (no multipliers)
                    line_buffer_left_pos <= {audio_left_pos_in, 8'h60};  // Simple concatenation
                    line_buffer_left_neg <= {audio_left_neg_in, 8'h60};
                    line_buffer_right_pos <= {audio_right_pos_in, 8'h60};
                    line_buffer_right_neg <= {audio_right_neg_in, 8'h60};
                    
                    line_left_pos_out <= line_buffer_left_pos[15];
                    line_left_neg_out <= line_buffer_left_neg[15];
                    line_right_pos_out <= line_buffer_right_pos[15];
                    line_right_neg_out <= line_buffer_right_neg[15];
                    
                    status_flags[2:0] <= 3'b001; // Line mode active
                end
                
                3'b001: begin // Balanced output mode (XLR)
                    output_drive_strength <= 8'h80; // Higher drive for balanced
                    class_a_bias_current <= 12'h800;
                    
                    // Balanced output buffers (true differential)
                    balanced_buffer_left_pos <= ({8'b0, audio_left_pos_in} * output_drive_strength);
                    balanced_buffer_left_neg <= ({8'b0, audio_left_neg_in} * output_drive_strength);
                    balanced_buffer_right_pos <= ({8'b0, audio_right_pos_in} * output_drive_strength);
                    balanced_buffer_right_neg <= ({8'b0, audio_right_neg_in} * output_drive_strength);
                    
                    balanced_left_pos_out <= balanced_buffer_left_pos[15];
                    balanced_left_neg_out <= balanced_buffer_left_neg[15];
                    balanced_right_pos_out <= balanced_buffer_right_pos[15];
                    balanced_right_neg_out <= balanced_buffer_right_neg[15];
                    
                    status_flags[2:0] <= 3'b010; // Balanced mode active
                end
                
                3'b010: begin // Headphone output mode
                    output_drive_strength <= 8'hC0; // High drive for headphones
                    class_a_bias_current <= 12'hA00;
                    
                    // Headphone buffers (single-ended with virtual ground)
                    headphone_buffer_left <= ({8'b0, audio_left_pos_in} * output_drive_strength);
                    headphone_buffer_right <= ({8'b0, audio_right_pos_in} * output_drive_strength);
                    
                    headphone_left_out <= headphone_buffer_left[15];
                    headphone_right_out <= headphone_buffer_right[15];
                    headphone_gnd_out <= 1'b0; // Virtual ground reference
                    
                    status_flags[2:0] <= 3'b100; // Headphone mode active
                end
                
                3'b011: begin // Simultaneous outputs mode
                    output_drive_strength <= 8'hA0; // Balanced drive for all
                    class_a_bias_current <= 12'hC00; // Higher bias for multiple outputs
                    
                    // Simplified simultaneous outputs (no multipliers)
                    line_buffer_left_pos <= {audio_left_pos_in, 8'h60};
                    line_buffer_left_neg <= {audio_left_neg_in, 8'h60};
                    line_buffer_right_pos <= {audio_right_pos_in, 8'h60};
                    line_buffer_right_neg <= {audio_right_neg_in, 8'h60};
                    
                    balanced_buffer_left_pos <= {audio_left_pos_in, 8'h80};
                    balanced_buffer_left_neg <= {audio_left_neg_in, 8'h80};
                    balanced_buffer_right_pos <= {audio_right_pos_in, 8'h80};
                    balanced_buffer_right_neg <= {audio_right_neg_in, 8'h80};
                    
                    headphone_buffer_left <= ({8'b0, audio_left_pos_in} * 8'hA0);
                    headphone_buffer_right <= ({8'b0, audio_right_pos_in} * 8'hA0);
                    
                    // All outputs active
                    line_left_pos_out <= line_buffer_left_pos[15];
                    line_left_neg_out <= line_buffer_left_neg[15];
                    line_right_pos_out <= line_buffer_right_pos[15];
                    line_right_neg_out <= line_buffer_right_neg[15];
                    
                    balanced_left_pos_out <= balanced_buffer_left_pos[15];
                    balanced_left_neg_out <= balanced_buffer_left_neg[15];
                    balanced_right_pos_out <= balanced_buffer_right_pos[15];
                    balanced_right_neg_out <= balanced_buffer_right_neg[15];
                    
                    headphone_left_out <= headphone_buffer_left[15];
                    headphone_right_out <= headphone_buffer_right[15];
                    headphone_gnd_out <= 1'b0;
                    
                    status_flags[2:0] <= 3'b111; // All modes active
                end
                
                default: begin // Muted/disabled
                    line_left_pos_out <= 1'b0;
                    line_left_neg_out <= 1'b0;
                    line_right_pos_out <= 1'b0;
                    line_right_neg_out <= 1'b0;
                    balanced_left_pos_out <= 1'b0;
                    balanced_left_neg_out <= 1'b0;
                    balanced_right_pos_out <= 1'b0;
                    balanced_right_neg_out <= 1'b0;
                    headphone_left_out <= 1'b0;
                    headphone_right_out <= 1'b0;
                    headphone_gnd_out <= 1'b0;
                    
                    status_flags[2:0] <= 3'b000; // All disabled
                end
            endcase
            
            // Thermal monitoring for Class-A operation
            if (class_a_bias_enable) begin
                thermal_accumulator <= thermal_accumulator + (class_a_bias_current >> 6);
                if (thermal_accumulator > 12'hE00) begin
                    status_flags[3] <= 1'b1; // Thermal warning
                end else begin
                    status_flags[3] <= 1'b0;
                end
            end else begin
                thermal_accumulator <= thermal_accumulator >> 1; // Cool down
                status_flags[3] <= 1'b0;
            end
            
            thermal_monitor <= thermal_accumulator;
            
            // Power and bias status
            status_flags[4] <= analog_power_enable;
            status_flags[5] <= class_a_bias_enable;
            status_flags[6] <= (class_a_bias_current > 12'h800); // High bias mode
            status_flags[7] <= (thermal_accumulator > 12'hC00); // High temperature
            
        end else begin
            // Power down - disable all outputs
            line_left_pos_out <= 1'b0;
            line_left_neg_out <= 1'b0;
            line_right_pos_out <= 1'b0;
            line_right_neg_out <= 1'b0;
            balanced_left_pos_out <= 1'b0;
            balanced_left_neg_out <= 1'b0;
            balanced_right_pos_out <= 1'b0;
            balanced_right_neg_out <= 1'b0;
            headphone_left_out <= 1'b0;
            headphone_right_out <= 1'b0;
            headphone_gnd_out <= 1'b0;
            
            status_flags <= 8'b0;
            thermal_monitor <= 12'b0;
        end
    end

endmodule
