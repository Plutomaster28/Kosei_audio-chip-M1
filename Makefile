# Kosei Audio Chip M1 - Ultimate Audiophile 130nm Audio Chip

## Makefile for simulation and synthesis using OpenLane

# ========================================================================
# CONFIGURATION
# ========================================================================

PROJECT_NAME = kosei_audio_chip
TOP_MODULE = kosei_audio_chip
PDK = sky130A

# Directories
SRC_DIR = src
TB_DIR = testbench
BUILD_DIR = build
OPENLANE_DIR = $(HOME)/OpenLane

# Source files
VERILOG_SOURCES = $(wildcard $(SRC_DIR)/*.v)
TESTBENCH_SOURCES = $(wildcard $(TB_DIR)/*.v)

# Simulation tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# ========================================================================
# SIMULATION TARGETS
# ========================================================================

.PHONY: all clean sim_top sim_dsp sim_dac sim_digital_frontend sim_all view_top view_dsp view_dac

all: sim_all

# Compile and run top-level testbench
sim_top: $(BUILD_DIR)/tb_$(TOP_MODULE)
	cd $(BUILD_DIR) && ./tb_$(TOP_MODULE)

$(BUILD_DIR)/tb_$(TOP_MODULE): $(VERILOG_SOURCES) $(TB_DIR)/tb_$(TOP_MODULE).v | $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $(VERILOG_SOURCES) $(TB_DIR)/tb_$(TOP_MODULE).v

# Compile and run DSP engine testbench
sim_dsp: $(BUILD_DIR)/tb_dsp_engine
	cd $(BUILD_DIR) && ./tb_dsp_engine

$(BUILD_DIR)/tb_dsp_engine: $(SRC_DIR)/dsp_engine.v $(TB_DIR)/tb_dsp_engine.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $(SRC_DIR)/dsp_engine.v $(TB_DIR)/tb_dsp_engine.v

# Compile and run DAC core testbench
sim_dac: $(BUILD_DIR)/tb_dac_core
	cd $(BUILD_DIR) && ./tb_dac_core

$(BUILD_DIR)/tb_dac_core: $(SRC_DIR)/dac_core.v $(TB_DIR)/tb_dac_core.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $(SRC_DIR)/dac_core.v $(TB_DIR)/tb_dac_core.v

# Compile and run digital frontend testbench
sim_digital_frontend: $(BUILD_DIR)/tb_digital_frontend
	cd $(BUILD_DIR) && ./tb_digital_frontend

$(BUILD_DIR)/tb_digital_frontend: $(SRC_DIR)/digital_frontend.v $(TB_DIR)/tb_digital_frontend.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $(SRC_DIR)/digital_frontend.v $(TB_DIR)/tb_digital_frontend.v

# Run all testbenches
sim_all: sim_top sim_dsp sim_dac

# ========================================================================
# WAVEFORM VIEWING
# ========================================================================

view_top: $(BUILD_DIR)/tb_$(TOP_MODULE).vcd
	$(GTKWAVE) $< &

view_dsp: $(BUILD_DIR)/tb_dsp_engine.vcd
	$(GTKWAVE) $< &

view_dac: $(BUILD_DIR)/tb_dac_core.vcd
	$(GTKWAVE) $< &

# ========================================================================
# SYNTHESIS TARGETS
# ========================================================================

.PHONY: synthesis harden place_and_route layout clean_openlane

# Run OpenLane synthesis flow
synthesis:
	@echo "Starting OpenLane synthesis for $(PROJECT_NAME)"
	@if [ ! -d "$(OPENLANE_DIR)" ]; then \
		echo "Error: OpenLane not found at $(OPENLANE_DIR)"; \
		echo "Please install OpenLane or set OPENLANE_DIR"; \
		exit 1; \
	fi
	cd $(OPENLANE_DIR) && make mount
	docker run -it -v $(PWD):/project -v $(OPENLANE_DIR):/openlane \
		-e PDK_ROOT=/openlane/pdks \
		-w /project \
		efabless/openlane:latest \
		/bin/bash -c "cd /openlane && python3 -m openlane /project/config.tcl"

# Complete hardening flow
harden: synthesis
	@echo "Running complete OpenLane hardening flow"

# Place and route only (requires synthesis to be done)
place_and_route:
	@echo "Running place and route"
	cd $(OPENLANE_DIR) && make mount PNR_ONLY=1

# Generate final layout
layout: harden
	@echo "Layout generation completed"
	@echo "Check runs/$(PROJECT_NAME)/results/final/gds for final layout"

# ========================================================================
# ANALYSIS TARGETS
# ========================================================================

.PHONY: lint check_syntax timing_analysis power_analysis

# Syntax checking with Verilator
lint:
	@echo "Running syntax check with Verilator"
	verilator --lint-only -Wall -I$(SRC_DIR) $(VERILOG_SOURCES)

# Basic syntax check with iverilog
check_syntax:
	@echo "Running syntax check with iverilog"
	$(IVERILOG) -t null -I$(SRC_DIR) $(VERILOG_SOURCES)

# Timing analysis (requires OpenLane results)
timing_analysis:
	@echo "Running timing analysis"
	@if [ -d "runs/$(PROJECT_NAME)/results/final" ]; then \
		echo "Timing reports available in runs/$(PROJECT_NAME)/reports/"; \
	else \
		echo "Run synthesis first"; \
	fi

# Power analysis (requires OpenLane results)
power_analysis:
	@echo "Running power analysis"
	@if [ -d "runs/$(PROJECT_NAME)/results/final" ]; then \
		echo "Power reports available in runs/$(PROJECT_NAME)/reports/"; \
	else \
		echo "Run synthesis first"; \
	fi

# ========================================================================
# UTILITY TARGETS
# ========================================================================

.PHONY: info setup_dirs check_tools

# Project information
info:
	@echo "=========================================="
	@echo "Kosei Audio Chip M1 - Build Information"
	@echo "=========================================="
	@echo "Project Name: $(PROJECT_NAME)"
	@echo "Top Module: $(TOP_MODULE)"
	@echo "PDK: $(PDK)"
	@echo "Source Files: $(words $(VERILOG_SOURCES)) files"
	@echo "Testbenches: $(words $(TESTBENCH_SOURCES)) files"
	@echo ""
	@echo "Available targets:"
	@echo "  sim_all      - Run all simulations"
	@echo "  sim_top      - Run top-level simulation"
	@echo "  sim_dsp      - Run DSP engine simulation"
	@echo "  sim_dac      - Run DAC core simulation"
	@echo "  synthesis    - Run OpenLane synthesis"
	@echo "  harden       - Complete OpenLane flow"
	@echo "  lint         - Syntax checking"
	@echo "  clean        - Clean build files"
	@echo "=========================================="

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Setup project directories
setup_dirs:
	mkdir -p $(BUILD_DIR)
	mkdir -p runs
	mkdir -p reports
	@echo "Project directories created"

# Check required tools
check_tools:
	@echo "Checking required tools..."
	@which $(IVERILOG) > /dev/null || (echo "iverilog not found" && exit 1)
	@which $(VVP) > /dev/null || (echo "vvp not found" && exit 1)
	@which docker > /dev/null || (echo "docker not found (required for OpenLane)" && exit 1)
	@echo "All required tools found"

# ========================================================================
# CLEANUP TARGETS
# ========================================================================

.PHONY: clean clean_sim clean_openlane clean_all

# Clean simulation files
clean_sim:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd *.lxt *.fst

# Clean OpenLane results
clean_openlane:
	rm -rf runs/
	rm -rf reports/

# Clean everything
clean_all: clean_sim clean_openlane

clean: clean_sim

# ========================================================================
# HELP TARGET
# ========================================================================

.PHONY: help

help: info
	@echo ""
	@echo "Usage examples:"
	@echo "  make sim_all          # Run all testbenches"
	@echo "  make synthesis        # Synthesize with OpenLane"
	@echo "  make harden           # Complete ASIC flow"
	@echo "  make clean            # Clean build files"
	@echo "  make lint             # Check syntax"
	@echo ""
	@echo "For more information, see README.md"

# Default target
.DEFAULT_GOAL := help