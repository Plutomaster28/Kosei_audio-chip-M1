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
    // 0x10: de-emphasis enable (bit0)
    // 0x14: balance_q15 (signed)
    // 0x18: crossfeed_q15 (unsigned)
    // 0x1C: meters/status readback L (peak[23:0])
    // 0x20: meters/status readback R (peak[23:0])
    // 0x24: temperature code
    // 0x28: EQ enable (bit0)
    // 0x2C..2F: Coeff SRAM access: 0x2C addr, 0x30 wdata, 0x34 cmd (bit0=write, bit1=read), 0x38 rdata
    // 0x3C: DAC mode: [0]=multi-bit enable
    // 0x40: DAC trim L [11:0]
    // 0x44: DAC trim R [11:0]
    
    wire        reg_wen  = csr_write;
    wire        reg_ren  = csr_read;
    wire [7:0]  reg_addr = csr_addr;
    wire [31:0] reg_wdata= csr_wdata;
    wire [31:0] reg_rdata;
    wire        reg_ready;

    assign csr_ready = reg_ready;

    // Default values
    localparam [31:0] ID_VALUE = 32'h4B4F5345; // 'KOSE'

    // Registers
    reg [1:0]  input_sel; // 0=test,1=i2s,2=spdif,3=usb
    reg [3:0]  osr_sel;   // 0=1x,1=4x,2=8x,3=16x
    reg [15:0] volume_q15; // Q1.15
    reg        soft_mute_en;
    reg        deemp_enable;
    reg signed [15:0] balance_q15;
    reg [15:0] crossfeed_q15;
    reg        eq_enable;
    reg        dac_multibit;
    reg [11:0] dac_trim_l;
    reg [11:0] dac_trim_r;
    reg [7:0]  coeff_addr;
    reg [31:0] coeff_wdata;
    reg        coeff_wen;
    reg        coeff_ren;
    wire [31:0] coeff_rdata;

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
            deemp_enable <= 1'b0;
            balance_q15  <= 16'sd0;
            crossfeed_q15<= 16'd0;
        end else if (reg_wen) begin
            case (reg_addr)
                8'h04: begin
                    input_sel <= reg_wdata[1:0];
                    osr_sel   <= reg_wdata[7:4];
                end
                8'h08: volume_q15 <= reg_wdata[15:0];
                8'h0C: soft_mute_en <= reg_wdata[0];
                8'h10: deemp_enable <= reg_wdata[0];
                8'h14: balance_q15 <= reg_wdata[15:0];
                8'h18: crossfeed_q15 <= reg_wdata[15:0];
                8'h28: eq_enable <= reg_wdata[0];
                8'h2C: coeff_addr <= reg_wdata[7:0];
                8'h30: coeff_wdata <= reg_wdata;
                8'h34: begin coeff_wen <= reg_wdata[0]; coeff_ren <= reg_wdata[1]; end
                8'h3C: dac_multibit <= reg_wdata[0];
                8'h40: dac_trim_l   <= reg_wdata[11:0];
                8'h44: dac_trim_r   <= reg_wdata[11:0];
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
        .deemp_enable(deemp_enable),
        .balance_q15(balance_q15),
        .crossfeed_q15(crossfeed_q15),
        .out_valid(dsp_valid),
        .out_l(dsp_l),
        .out_r(dsp_r)
    );

    // EQ engine insertion between DSP and DAC
    wire        eq_valid; wire [23:0] eq_l, eq_r;
    // Pack identity EQ coefficients into a flat bus (b0=1.0, others=0)
    localparam NSEC = 4;
    wire [NSEC*5*16-1:0] coeff_bus_flat;
    genvar si;
    generate
        for (si=0; si<NSEC; si=si+1) begin: COEFF_PACK
            localparam integer O0 = (si*5+0)*16;
            localparam integer O1 = (si*5+1)*16;
            localparam integer O2 = (si*5+2)*16;
            localparam integer O3 = (si*5+3)*16;
            localparam integer O4 = (si*5+4)*16;
            assign coeff_bus_flat[O0+15:O0] = 16'h7FFF; // b0
            assign coeff_bus_flat[O1+15:O1] = 16'h0000; // b1
            assign coeff_bus_flat[O2+15:O2] = 16'h0000; // b2
            assign coeff_bus_flat[O3+15:O3] = 16'h0000; // a1
            assign coeff_bus_flat[O4+15:O4] = 16'h0000; // a2
        end
    endgenerate
    eq_engine #(.N_SECTIONS(NSEC)) u_eq(
        .clk(clk), .rst_n(rst_n), .in_valid(dsp_valid), .in_l(dsp_l), .in_r(dsp_r), .enable(eq_enable), .coeff_bus(coeff_bus_flat), .out_valid(eq_valid), .out_l(eq_l), .out_r(eq_r)
    );

    // ------------------------------------------------------------------
    // DAC core: sigma-delta modulators
    // ------------------------------------------------------------------
    dac_core u_dac (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(eq_valid),
        .in_l(eq_l),
        .in_r(eq_r),
        .mode_multibit(dac_multibit),
        .trim_l(dac_trim_l),
        .trim_r(dac_trim_r),
        .sdm_out_l(sdm_out_l),
        .sdm_out_r(sdm_out_r)
    );

    // Diagnostic meters and temperature stub
    wire [23:0] peak_l, peak_r, rms_l, rms_r;
    audio_meters u_mtr(
        .clk(clk), .rst_n(rst_n), .in_valid(dsp_valid), .in_l(dsp_l), .in_r(dsp_r), .peak_l(peak_l), .peak_r(peak_r), .rms_l(rms_l), .rms_r(rms_r)
    );
    wire [11:0] temp_code;
    temp_sensor_stub u_temp(.clk(clk), .rst_n(rst_n), .temp_code(temp_code));

    // Coefficient SRAM
    coeff_sram u_coeff(
        .clk(clk), .rst_n(rst_n), .wen(coeff_wen), .addr(coeff_addr), .wdata(coeff_wdata), .ren(coeff_ren), .rdata(coeff_rdata)
    );

    // Note: EQ engine and coefficient mapping reserved for future; coeff_sram is accessible via CSRs for host to manage

    // Extend readback via simple mux on read_en (piggyback onto registers block by shadowing rdata when read)
    // Note: keeping 'registers' module simple; we overlay read data here.
    reg [31:0] reg_rdata_ovr;
    assign csr_rdata = (reg_ren) ? reg_rdata_ovr : reg_rdata;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) reg_rdata_ovr <= 32'd0;
        else if (reg_ren) begin
            case (reg_addr)
                8'h1C: reg_rdata_ovr <= {8'd0, peak_l};
                8'h20: reg_rdata_ovr <= {8'd0, peak_r};
                8'h24: reg_rdata_ovr <= {20'd0, temp_code};
                8'h38: reg_rdata_ovr <= coeff_rdata;
                default: reg_rdata_ovr <= reg_rdata;
            endcase
        end
    end

endmodule
