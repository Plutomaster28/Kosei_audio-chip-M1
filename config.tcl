# OpenLane Configuration for Kosei Audio Chip M1
# Simplified to a single top-level RTL and one primary clock

set ::env(DESIGN_NAME) "kosei_audio_top"

# PDK Configuration
set ::env(PDK) "sky130A"
set ::env(STD_CELL_LIBRARY) "sky130_fd_sc_hd"

# Design Source (only the current top-level RTL)
set ::env(VERILOG_FILES) "\
	$::env(DESIGN_DIR)/src/kosei_audio_chip.v \
	$::env(DESIGN_DIR)/src/kosei_audio_top.v \
	$::env(DESIGN_DIR)/src/usb_to_i2s_lite.v"

# Clock Configuration - match RTL (10 MHz reference clock)
set ::env(CLOCK_PERIOD) "100.0" ;# ns (10 MHz)
set ::env(CLOCK_PORT) "clk_ref_external"
set ::env(RESET_PORT) "rst_n"
set ::env(RESET_POLARITY) 0

# No extra SDC; all additional clocks are treated as async inputs in RTL
# set ::env(BASE_SDC_FILE) "$::env(DESIGN_DIR)/constraints/audio_chip.sdc"

# Die size and utilization
set ::env(FP_CORE_UTIL) 22
set ::env(FP_ASPECT_RATIO) 1
set ::env(FP_PDN_CORE_RING) 1

# Placement configuration for mixed-signal design
set ::env(PL_BASIC_PLACEMENT) 1
set ::env(PL_TARGET_DENSITY) 0.25

# Routing configuration
# Let the router use more capacity (lower adjustment) and all layers
# Define as empty string instead of unsetting to satisfy OpenLane scripts
set ::env(GRT_LAYER_ADJUSTMENTS) ""
set ::env(GRT_ADJUSTMENT) 0.15
set ::env(GRT_MAX_LAYER) met5
set ::env(RT_MAX_LAYER) met5
set ::env(RT_MIN_LAYER) met2

# Power grid
# Relax PDN strap blockage to open routing channels
set ::env(FP_PDN_VWIDTH) 1.6
set ::env(FP_PDN_HWIDTH) 1.6
set ::env(FP_PDN_VSPACING) 30.0
set ::env(FP_PDN_HSPACING) 30.0

# Placement/timing settings
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 0
set ::env(CTS_TOLERANCE) 100
set ::env(PL_ROUTABILITY_DRIVEN) 1
set ::env(CELL_PAD) 4

# Memory configuration for SRAM (disabled; no SRAM macros used)
set ::env(SRAM_ENABLE) 0

# DRC and LVS settings
set ::env(MAGIC_DRC_USE_GDS) 1
set ::env(QUIT_ON_MAGIC_DRC) 0
set ::env(QUIT_ON_LVS_ERROR) 0

# Floor planning
set ::env(FP_IO_MODE) 0
set ::env(FP_PDN_AUTO_WRAPPER) 1
set ::env(FP_PIN_ORDER_CFG) "$::env(DESIGN_DIR)/constraints/pin_order.cfg"

# Synthesis settings - Conservative for analog compatibility
set ::env(SYNTH_STRATEGY) "AREA 0"
set ::env(SYNTH_BUFFERING) 0
set ::env(SYNTH_SIZING) 0

# Detailed routing - Extra care for mixed-signal
set ::env(DETAILED_ROUTER) "tritonroute"
set ::env(DRT_OPT_ITERS) 96

# Set library files
set ::env(LIB_SYNTH) "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set ::env(LIB_FASTEST) "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_n40C_1v95.lib"
set ::env(LIB_SLOWEST) "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib"
set ::env(LIB_TYPICAL) "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"