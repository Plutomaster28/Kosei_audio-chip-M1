# SDC Constraints for Kosei Audio Chip M1
# Multiple clock domains for audio processing

# System clock - 50 MHz
create_clock -period 20.0 -name clk_sys [get_ports clk_sys]

# Audio master clock - 24.576 MHz (512 * 48kHz)
create_clock -period 40.69 -name clk_audio_master [get_ports clk_audio_master]

# Audio bit clock - varies with sample rate
create_clock -period 325.52 -name clk_audio_bit [get_ports clk_audio_bit]

# High-speed DAC clock - 196.608 MHz (for oversampling)
create_clock -period 5.09 -name clk_dac_hs [get_ports clk_dac_hs]

# PLL reference clock - 10 MHz
create_clock -period 100.0 -name clk_ref [get_ports clk_ref]

# Clock domain crossing constraints
set_clock_groups -asynchronous \
    -group [get_clocks clk_sys] \
    -group [get_clocks clk_audio_master] \
    -group [get_clocks clk_audio_bit] \
    -group [get_clocks clk_dac_hs] \
    -group [get_clocks clk_ref]

# Input delays for audio interfaces
set_input_delay -clock clk_audio_bit -max 5.0 [get_ports i2s_*]
set_input_delay -clock clk_audio_bit -min 1.0 [get_ports i2s_*]

set_input_delay -clock clk_sys -max 10.0 [get_ports spdif_in]
set_input_delay -clock clk_sys -min 2.0 [get_ports spdif_in]

# Output delays for DAC interface
set_output_delay -clock clk_dac_hs -max 2.0 [get_ports dac_*]
set_output_delay -clock clk_dac_hs -min 0.5 [get_ports dac_*]

# False paths for configuration registers
set_false_path -from [get_ports config_*]
set_false_path -to [get_ports status_*]

# Multi-cycle paths for DSP operations
set_multicycle_path -setup 4 -from [get_cells dsp_engine/*] -to [get_cells dac_core/*]
set_multicycle_path -hold 3 -from [get_cells dsp_engine/*] -to [get_cells dac_core/*]

# Maximum transition and capacitance for analog-sensitive signals
set_max_transition 0.5 [get_nets dac_*]
set_max_capacitance 0.1 [get_nets dac_*]

# Load constraints for output pads
set_load 10.0 [get_ports audio_out_*]
set_load 5.0 [get_ports digital_out_*]