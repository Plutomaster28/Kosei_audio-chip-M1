/*
 * usb_to_i2s_lite
 * Serialize 24-bit USB audio samples into simple I2S (bclk/lrclk/data).
 * Synthesis-friendly: single clock domain, counters and shifts only.
 */

module usb_to_i2s_lite (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] usb_left,
    input  wire [23:0] usb_right,
    input  wire        usb_valid,

    output reg         i2s_bclk,
    output reg         i2s_lrclk,
    output reg         i2s_data
);

    // Simple clock divider for BCLK generation
    // With clk=10MHz and DIV=2 -> ~2.5MHz BCLK (close to 48k*24*2=2.304MHz)
    localparam integer DIV = 2;
    reg [$clog2(DIV)-1:0] div_cnt;

    // Serialization state
    reg [5:0] bit_idx;      // 0..47 (24 left + 24 right)
    reg       busy;         // Active serialization
    reg [23:0] sh_left, sh_right;

    // Generate bclk by dividing input clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt  <= 0;
            i2s_bclk <= 1'b0;
        end else begin
            if (div_cnt == DIV-1) begin
                div_cnt  <= 0;
                i2s_bclk <= ~i2s_bclk;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end
    end

    // Serialize on rising edge of bclk
    always @(posedge i2s_bclk or negedge rst_n) begin
        if (!rst_n) begin
            bit_idx   <= 6'd0;
            busy      <= 1'b0;
            i2s_lrclk <= 1'b0;
            i2s_data  <= 1'b0;
            sh_left   <= 24'b0;
            sh_right  <= 24'b0;
        end else begin
            if (!busy) begin
                // Load new frame when usb_valid is asserted
                if (usb_valid) begin
                    sh_left   <= usb_left;
                    sh_right  <= usb_right;
                    bit_idx   <= 6'd0;
                    busy      <= 1'b1;
                    i2s_lrclk <= 1'b1; // Left channel first (lrclk=1)
                end
            end else begin
                // Output MSB first
                if (bit_idx < 6'd24) begin
                    i2s_data <= sh_left[23];
                    sh_left  <= {sh_left[22:0], 1'b0};
                    i2s_lrclk <= 1'b1;
                end else begin
                    i2s_data <= sh_right[23];
                    sh_right <= {sh_right[22:0], 1'b0};
                    i2s_lrclk <= 1'b0; // Right channel
                end

                bit_idx <= bit_idx + 1'b1;

                if (bit_idx == 6'd47) begin
                    busy <= 1'b0; // Done with this frame
                end
            end
        end
    end

endmodule
