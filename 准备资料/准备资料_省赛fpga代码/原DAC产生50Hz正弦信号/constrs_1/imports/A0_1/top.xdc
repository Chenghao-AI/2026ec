
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m -waveform {0.000 10.000} [get_ports clk_50m]

set_property PACKAGE_PIN H15 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports scl]

set_property PACKAGE_PIN H16 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]


set_property PACKAGE_PIN J16 [get_ports dac_led]
set_property IOSTANDARD LVCMOS33 [get_ports dac_led]

set_property PACKAGE_PIN K16 [get_ports ack_led]
set_property IOSTANDARD LVCMOS33 [get_ports ack_led]

set_false_path -to [get_ports {scl dac_led ack_led}]
set_false_path -from [get_ports {sda}]
