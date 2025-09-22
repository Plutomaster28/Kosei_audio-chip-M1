# Kosei Audio Chip M1 - Top-level SDC constraints

# Primary clock
create_clock -name clk -period 10.0 [get_ports clk]

# Set input/output delays (basic placeholder)
set_input_delay 2.0 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 2.0 -clock clk [all_outputs]

# False paths for asynchronous peripheral pins (treat as non-timed for now)
set_false_path -from [get_ports {i2s_bclk i2s_lrclk i2s_sd spdif_in usb_dp usb_dm ext_mclk}]
