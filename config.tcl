# OpenLane Configuration for Kosei Audio Chip M1 (clean minimal config)

# Design identity
set ::env(DESIGN_NAME) "kosei_audio_top"
set ::env(TOP_MODULE)  "kosei_audio_top"

# PDK
set ::env(PDK) "sky130A"

# RTL sources (explicit list to avoid path ambiguity)
set ::env(VERILOG_FILES) "\
	$::env(DESIGN_DIR)/src/kosei_audio_top.v \
	$::env(DESIGN_DIR)/src/kosei_audio_chip.v \
	$::env(DESIGN_DIR)/src/digital_frontend.v \
	$::env(DESIGN_DIR)/src/dsp_engine.v \
	$::env(DESIGN_DIR)/src/dac_core.v \
	$::env(DESIGN_DIR)/src/registers.v \
	$::env(DESIGN_DIR)/src/fifo_sync.v \
	$::env(DESIGN_DIR)/src/fifo_async.v \
	$::env(DESIGN_DIR)/src/i2s_rx.v \
	$::env(DESIGN_DIR)/src/fir_interp_4x.v \
	$::env(DESIGN_DIR)/src/spdif_rx.v \
	$::env(DESIGN_DIR)/src/usb_uac1_rx.v \
	$::env(DESIGN_DIR)/src/usb_to_i2s_lite.v"

# Clocking
set ::env(CLOCK_PORT)   "clk"
set ::env(CLOCK_PERIOD) "10.0" ;# ns (100 MHz)

# Constraints
set ::env(SDC_FILE) "$::env(DESIGN_DIR)/constraints/top.sdc"

# Synthesis and floorplanning (simple defaults)
set ::env(SYNTH_STRATEGY)        "AREA 0"
set ::env(PL_TARGET_DENSITY)     0.52   ;# suggested by GPL error
set ::env(FP_CORE_UTIL)          25      ;# enlarge core area
set ::env(FP_ASPECT_RATIO)       1.0

# Run tag
set ::env(RUN_TAG) "m1_iter2"