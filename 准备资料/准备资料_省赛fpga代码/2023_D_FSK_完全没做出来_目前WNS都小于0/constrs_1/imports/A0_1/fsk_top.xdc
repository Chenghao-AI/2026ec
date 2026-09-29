
# ============================================================================
# FSK Demodulation - Pin and Timing Constraints
# FPGA: Xilinx Zynq-7000 XC7Z020-2CLG400I
# Board: ALINX AX7020
# ============================================================================

# ---- Primary Clock: 50 MHz (U18) ----
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m -waveform {0 10} [get_ports clk_50m]

# ============================================================================
# ADC A Channel (AD9226)
# ============================================================================
set_property PACKAGE_PIN P14 [get_ports adc_aclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_aclk]

set_property PACKAGE_PIN P16 [get_ports adc_a_ora]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_ora]

# ADC A Data Bus
set_property PACKAGE_PIN R14 [get_ports {adc_a_data[0]}]
set_property PACKAGE_PIN Y16 [get_ports {adc_a_data[1]}]
set_property PACKAGE_PIN Y17 [get_ports {adc_a_data[2]}]
set_property PACKAGE_PIN V15 [get_ports {adc_a_data[3]}]
set_property PACKAGE_PIN W15 [get_ports {adc_a_data[4]}]
set_property PACKAGE_PIN W14 [get_ports {adc_a_data[5]}]
set_property PACKAGE_PIN Y14 [get_ports {adc_a_data[6]}]
set_property PACKAGE_PIN N17 [get_ports {adc_a_data[7]}]
set_property PACKAGE_PIN P18 [get_ports {adc_a_data[8]}]
set_property PACKAGE_PIN U14 [get_ports {adc_a_data[9]}]
set_property PACKAGE_PIN U15 [get_ports {adc_a_data[10]}]
set_property PACKAGE_PIN P15 [get_ports {adc_a_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[*]}]

# ============================================================================
# User Keys (PL Keys - low-active with pull-up)
# ============================================================================
set_property PACKAGE_PIN N15 [get_ports key1_n]
set_property PACKAGE_PIN N16 [get_ports key2_n]
set_property IOSTANDARD LVCMOS33 [get_ports {key1_n key2_n}]
set_property PULLUP true [get_ports {key1_n key2_n}]

# ============================================================================
# PL LEDs (low-active)
# ============================================================================
set_property PACKAGE_PIN M14 [get_ports led1]
set_property PACKAGE_PIN M15 [get_ports led2]
set_property PACKAGE_PIN K16 [get_ports led3]
set_property PACKAGE_PIN J16 [get_ports led4]
set_property IOSTANDARD LVCMOS33 [get_ports {led1 led2 led3 led4}]

# ============================================================================
# DAC A Channel (AD9764)
# ============================================================================
set_property PACKAGE_PIN G19 [get_ports dac_a_clk]
set_property IOSTANDARD LVCMOS33 [get_ports dac_a_clk]
set_property SLEW SLOW [get_ports dac_a_clk]
set_property DRIVE 4 [get_ports dac_a_clk]

# DAC A Data Bus
set_property PACKAGE_PIN L16 [get_ports {dac_a_data[0]}]
set_property PACKAGE_PIN H20 [get_ports {dac_a_data[1]}]
set_property PACKAGE_PIN J20 [get_ports {dac_a_data[2]}]
set_property PACKAGE_PIN J19 [get_ports {dac_a_data[3]}]
set_property PACKAGE_PIN K19 [get_ports {dac_a_data[4]}]
set_property PACKAGE_PIN K18 [get_ports {dac_a_data[5]}]
set_property PACKAGE_PIN K17 [get_ports {dac_a_data[6]}]
set_property PACKAGE_PIN M20 [get_ports {dac_a_data[7]}]
set_property PACKAGE_PIN M19 [get_ports {dac_a_data[8]}]
set_property PACKAGE_PIN L20 [get_ports {dac_a_data[9]}]
set_property PACKAGE_PIN L19 [get_ports {dac_a_data[10]}]
set_property PACKAGE_PIN H18 [get_ports {dac_a_data[11]}]
set_property PACKAGE_PIN J18 [get_ports {dac_a_data[12]}]
set_property PACKAGE_PIN G20 [get_ports {dac_a_data[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_a_data[*]}]
set_property SLEW SLOW [get_ports {dac_a_data[*]}]
set_property DRIVE 4 [get_ports {dac_a_data[*]}]

# ============================================================================
# Configuration
# ============================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# ============================================================================
# Timing Constraints
# ============================================================================

# ADC Clock (internally generated through fabric)
create_clock -period 16.667 -name adc_clk_int -waveform {0 8.333} [get_ports adc_aclk]

# ADC Input Setup/Hold
set_input_delay -clock adc_clk_int -max 4.0 [get_ports {adc_a_data[*]}]
set_input_delay -clock adc_clk_int -min 2.0 [get_ports {adc_a_data[*]}]
set_input_delay -clock adc_clk_int -max 4.0 [get_ports adc_a_ora]
set_input_delay -clock adc_clk_int -min 2.0 [get_ports adc_a_ora]

# DAC Output Constraints
set_output_delay -clock sys_clk_50m -max 4.0 [get_ports {dac_a_data[*]}]
set_output_delay -clock sys_clk_50m -min 2.0 [get_ports {dac_a_data[*]}]

# Key inputs - async but synchronized in design
set_false_path -from [get_ports {key1_n key2_n}]

# Clock domain crossing constraints
set_max_delay -datapath_only -from [get_pins u_dut/u_core/*/C] -to [get_pins u_dut/rc_code_50m[*]/D] 20.0
set_max_delay -datapath_only -from [get_pins u_dut/u_core/*/C] -to [get_pins u_dut/led_logic_50m[*]/D] 20.0
set_max_delay -datapath_only -from [get_pins u_dut/u_core/*/C] -to [get_pins u_dut/dac_data_50m[*]/D] 20.0

# MMCM related
set_max_delay -datapath_only -from [get_clocks sys_clk_50m] -to [get_clocks adc_clk_int] 16.667
set_max_delay -datapath_only -from [get_clocks adc_clk_int] -to [get_clocks sys_clk_50m] 20.0
