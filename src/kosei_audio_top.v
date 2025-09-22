/*
 * Kosei Audio Top Wrapper
 * Exposes a superset of I/O for future integration while instantiating the
 * synthesis-friendly core (kosei_audio_chip) internally.
 */

module kosei_audio_top (
    // Clocks and reset
    input  wire clk_ref_external,   // Used by core
    input  wire clk_crystal,        // Reserved / unused in core
    input  wire rst_n,              // Active-low reset

    // Optional/system clocks (for future expansion; currently unused)
    input  wire clk_sys,
    input  wire clk_audio_master,
    input  wire clk_audio_bit,
    input  wire clk_dac_hs,

    // Power (kept as ports for padframe planning; not used in RTL)
    input  wire vdd_digital,
    input  wire vdd_analog,
    input  wire vss_digital,
    input  wire vss_analog,

    // Digital audio inputs (core-supported)
    input  wire cd_data,
    input  wire cd_clock,
    input  wire cd_valid,
    input  wire i2s_bclk,
    input  wire i2s_lrclk,
    input  wire i2s_data,
    input  wire spdif_in,

    // Extended inputs for future integration (not used by core yet)
    input  wire cd_efm_data,
    input  wire cd_efm_clock,
    input  wire cd_channel_clock,
    input  wire usb_clk,
    input  wire [23:0] usb_audio_left,
    input  wire [23:0] usb_audio_right,
    input  wire usb_audio_valid,

    // Configuration (core-supported)
    input  wire [2:0] input_select,
    input  wire [3:0] volume_control,
    input  wire [2:0] eq_preset,
    input  wire [1:0] sample_rate,

    // Outputs from core
    output wire audio_out_left_pos,
    output wire audio_out_left_neg,
    output wire audio_out_right_pos,
    output wire audio_out_right_neg,
    output wire line_out_left,
    output wire line_out_right,
    output wire [7:0] status_leds,
    output wire audio_present,
    output wire [1:0] current_sample_rate,

    // Extended outputs for future DAC integration (tied-off for now)
    output wire dac_left_pos,
    output wire dac_left_neg,
    output wire dac_right_pos,
    output wire dac_right_neg,
    output wire sigma_delta_left,
    output wire sigma_delta_right
);

    // ---------------------------------------------------------------------
    // Internal I2S mux: either pass external I2S or generate from USB
    // ---------------------------------------------------------------------
    wire i2s_bclk_int, i2s_lrclk_int, i2s_data_int;

    // Simple USB-to-I2S generator (runs off reference clock)
    // Add an input register slice to ease routing from IO to core
    reg [23:0] usb_left_r, usb_right_r;
    reg        usb_valid_r;
    always @(posedge clk_ref_external or negedge rst_n) begin
        if (!rst_n) begin
            usb_left_r  <= 24'b0;
            usb_right_r <= 24'b0;
            usb_valid_r <= 1'b0;
        end else begin
            usb_left_r  <= usb_audio_left;
            usb_right_r <= usb_audio_right;
            usb_valid_r <= usb_audio_valid;
        end
    end

    wire i2s_bclk_usb, i2s_lrclk_usb, i2s_data_usb;
    usb_to_i2s_lite u_usb2i2s (
        .clk(clk_ref_external),
        .rst_n(rst_n),
        .usb_left(usb_left_r),
        .usb_right(usb_right_r),
        .usb_valid(usb_valid_r),
        .i2s_bclk(i2s_bclk_usb),
        .i2s_lrclk(i2s_lrclk_usb),
        .i2s_data(i2s_data_usb)
    );

    // Select source based on input_select encoding in the core (reuse 2'b11 as USB)
    wire use_usb_i2s = (input_select == 3'b011);
    assign i2s_bclk_int  = use_usb_i2s ? i2s_bclk_usb  : i2s_bclk;
    assign i2s_lrclk_int = use_usb_i2s ? i2s_lrclk_usb : i2s_lrclk;
    assign i2s_data_int  = use_usb_i2s ? i2s_data_usb  : i2s_data;

    // Remap input_select so the core selects I2S path when USB is chosen at the top
    wire [2:0] core_input_select = use_usb_i2s ? 3'b001 : input_select;

    // Instantiate the synthesis-friendly core
    kosei_audio_chip u_core (
        .clk_ref_external(clk_ref_external),
        .clk_crystal(clk_crystal),
        .rst_n(rst_n),
        .vdd_digital(vdd_digital),
        .vdd_analog(vdd_analog),
        .vss_digital(vss_digital),
        .vss_analog(vss_analog),
        .cd_data(cd_data),
        .cd_clock(cd_clock),
        .cd_valid(cd_valid),
    .i2s_bclk(i2s_bclk_int),
    .i2s_lrclk(i2s_lrclk_int),
    .i2s_data(i2s_data_int),
        .spdif_in(spdif_in),
    .input_select(core_input_select),
        .volume_control(volume_control),
        .eq_preset(eq_preset),
        .sample_rate(sample_rate),
        .audio_out_left_pos(audio_out_left_pos),
        .audio_out_left_neg(audio_out_left_neg),
        .audio_out_right_pos(audio_out_right_pos),
        .audio_out_right_neg(audio_out_right_neg),
        .line_out_left(line_out_left),
        .line_out_right(line_out_right),
        .status_leds(status_leds),
        .audio_present(audio_present),
        .current_sample_rate(current_sample_rate)
    );

    // Tie off extended outputs (not driven by core yet)
    assign dac_left_pos = 1'b0;
    assign dac_left_neg = 1'b0;
    assign dac_right_pos = 1'b0;
    assign dac_right_neg = 1'b0;
    assign sigma_delta_left = 1'b0;
    assign sigma_delta_right = 1'b0;

endmodule
