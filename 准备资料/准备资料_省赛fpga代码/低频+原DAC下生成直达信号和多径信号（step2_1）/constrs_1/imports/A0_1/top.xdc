set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m -waveform {0.000 10.000} [get_ports clk_50m]

# ---- DAC8571 I2C ----
set_property PACKAGE_PIN H15 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property PACKAGE_PIN H16 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]

# KEY1 = N15, KEY2 = N16, KEY3 = T17, KEY4 = R17
set_property PACKAGE_PIN N15 [get_ports key1]
set_property IOSTANDARD LVCMOS33 [get_ports key1]
set_property PACKAGE_PIN N16 [get_ports key2]
set_property IOSTANDARD LVCMOS33 [get_ports key2]
set_property PACKAGE_PIN T17 [get_ports key3]
set_property IOSTANDARD LVCMOS33 [get_ports key3]
set_property PACKAGE_PIN R17 [get_ports key4]
set_property IOSTANDARD LVCMOS33 [get_ports key4]

set_property PACKAGE_PIN M14 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN M15 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN K16 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN J16 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_false_path -to [get_ports {scl led[*]}]
set_false_path -from [get_ports {sda key1 key2 key3 key4}]