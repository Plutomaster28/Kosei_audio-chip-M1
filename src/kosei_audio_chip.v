// Kosei Audio Chip M1 - Top Level
// Synthesizable RTL skeleton suitable for OpenLane/Yosys
// Notes:
// - Multi-domain clocks and true analog are stubbed. All core logic runs on `clk`.
// - I2S/SPDIF/USB receivers are simplified stubs; parallel PCM test input provided.
// - Configuration interface: simple CSR bus synchronous to `clk`.

`timescale 1ns/1ps

module kosei_audio_chip (
    input  wire        clk,          // core clock
    input  wire        reset_n,      // async active-low reset
    input  wire        ext_mclk,     // optional external master clock (async to clk)

    // I2S input (optional external clock domain)
    input  wire        i2s_bclk,
    input  wire        i2s_lrclk,
    input  wire        i2s_sd,

    // S/PDIF input (stub)
    input  wire        spdif_in,

    // USB Audio input (stub)
    input  wire        usb_dp,
    input  wire        usb_dm,

    // Parallel PCM test input (synchronous)
    input  wire        pcm_test_valid,
    input  wire [23:0] pcm_test_l,
    input  wire [23:0] pcm_test_r,

    // Control/Status Register simple bus (synchronous)
    input  wire        csr_write,
    input  wire        csr_read,
    input  wire [7:0]  csr_addr,
    input  wire [31:0] csr_wdata,
    output wire [31:0] csr_rdata,
    output wire        csr_ready,

    // Sigma-delta DAC bitstreams out (digital)
    output wire        sdm_out_l,
    output wire        sdm_out_r
);

    // ------------------------------------------------------------------
    // Reset sync
    // ------------------------------------------------------------------
    reg [1:0] rst_sync;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) rst_sync <= 2'b00;
        else rst_sync <= {rst_sync[0], 1'b1};
    end
    wire rst_n = rst_sync[1];

    // ------------------------------------------------------------------
    // CSR register block
    // ------------------------------------------------------------------
    // Map:
    // 0x00: ID/version
    // 0x04: control: [1:0] input_sel (0=PCM test,1=I2S,2=SPDIF,3=USB), [7:4] osr_sel (0=1x,1=4x,2=8x,3=16x)
    // 0x08: volume (Q1.15) applied to both channels
    // 0x0C: soft-mute enable
    // 0x10.. presets/coeff select (not fully implemented)
    
    wire        reg_wen  = csr_write;
    wire        reg_ren  = csr_read;
    wire [7:0]  reg_addr = csr_addr;
    wire [31:0] reg_wdata= csr_wdata;
    wire [31:0] reg_rdata;
    wire        reg_ready;

    assign csr_rdata = reg_rdata;
    assign csr_ready = reg_ready;

    // Default values
    localparam [31:0] ID_VALUE = 32'h4B4F5345; // 'KOSE'

    // Registers
    reg [1:0]  input_sel; // 0=test,1=i2s,2=spdif,3=usb
    reg [3:0]  osr_sel;   // 0=1x,1=4x,2=8x,3=16x
    reg [15:0] volume_q15; // Q1.15
    reg        soft_mute_en;

    // CSR implementation
    registers #(
        .ADDR_WIDTH(8),
        .READONLY_MASK(32'h0000_0001) // 0x00 readonly (bit0=addr0 RO indicator in this simple scheme)
    ) u_regs (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(reg_wen),
        .read_en(reg_ren),
        .addr(reg_addr),
        .wdata(reg_wdata),
        .rdata(reg_rdata),
        .ready(reg_ready),
        // sideband access via callbacks below
        .ro0(ID_VALUE),
        .rsvd()
    );

    // Decode writes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_sel    <= 2'd0;
            osr_sel      <= 4'd1; // default 4x
            volume_q15   <= 16'h7FFF; // unity
            soft_mute_en <= 1'b0;
        end else if (reg_wen) begin
            case (reg_addr)
                8'h04: begin
                    input_sel <= reg_wdata[1:0];
                    osr_sel   <= reg_wdata[7:4];
                end
                8'h08: volume_q15 <= reg_wdata[15:0];
                8'h0C: soft_mute_en <= reg_wdata[0];
                default: ;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Digital front-end: choose and normalize PCM to core
    // ------------------------------------------------------------------
    wire        fe_valid;
    wire [23:0] fe_l;
    wire [23:0] fe_r;

    digital_frontend u_fe (
        .clk(clk),
        .rst_n(rst_n),
        .input_sel(input_sel),
        // I2S
        .i2s_bclk(i2s_bclk),
        .i2s_lrclk(i2s_lrclk),
        .i2s_sd(i2s_sd),
        // SPDIF
        .spdif_in(spdif_in),
        // USB
        .usb_dp(usb_dp),
        .usb_dm(usb_dm),
        // Parallel test
        .test_valid(pcm_test_valid),
        .test_l(pcm_test_l),
        .test_r(pcm_test_r),
        // Normalized output in core clock domain
        .pcm_valid(fe_valid),
        .pcm_l(fe_l),
        .pcm_r(fe_r)
    );

    // ------------------------------------------------------------------
    // DSP Engine: oversampling, filters, volume, dither
    // ------------------------------------------------------------------
    wire        dsp_valid;
    wire [23:0] dsp_l;
    wire [23:0] dsp_r;

    dsp_engine u_dsp (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(fe_valid),
        .in_l(fe_l),
        .in_r(fe_r),
        .osr_sel(osr_sel),
        .volume_q15(volume_q15),
        .soft_mute(soft_mute_en),
        .out_valid(dsp_valid),
        .out_l(dsp_l),
        .out_r(dsp_r)
    );

    // ------------------------------------------------------------------
    // DAC core: sigma-delta modulators
    // ------------------------------------------------------------------
    dac_core u_dac (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(dsp_valid),
        .in_l(dsp_l),
        .in_r(dsp_r),
        .sdm_out_l(sdm_out_l),
        .sdm_out_r(sdm_out_r)
    );

endmodule
