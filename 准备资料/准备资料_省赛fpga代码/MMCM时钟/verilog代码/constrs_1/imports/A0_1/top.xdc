# Clock Constraint (50 MHz)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m -waveform {0.000 10.000} [get_ports clk_50m]

# LED1 = M14
set_property PACKAGE_PIN M14 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports led1]

# LED2 = M15
set_property PACKAGE_PIN M15 [get_ports led2]
set_property IOSTANDARD LVCMOS33 [get_ports led2]

# LED3 = K16
set_property PACKAGE_PIN K16 [get_ports led3]
set_property IOSTANDARD LVCMOS33 [get_ports led3]

# LED4 = J16
set_property PACKAGE_PIN J16 [get_ports led4]
set_property IOSTANDARD LVCMOS33 [get_ports led4]

set_property PACKAGE_PIN G15 [get_ports osc_1khz]
set_property IOSTANDARD LVCMOS33 [get_ports osc_1khz]

set_property PACKAGE_PIN F16 [get_ports osc_2khz]
set_property IOSTANDARD LVCMOS33 [get_ports osc_2khz]

set_property PACKAGE_PIN G17 [get_ports osc_half_khz]
set_property IOSTANDARD LVCMOS33 [get_ports osc_half_khz]
