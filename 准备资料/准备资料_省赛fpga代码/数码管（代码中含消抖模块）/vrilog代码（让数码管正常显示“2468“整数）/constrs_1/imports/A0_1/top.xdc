# ============================================================================
# Clock Constraint (50MHz)
# ============================================================================
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk -waveform {0.000 10.000} [get_ports clk_50m]

set_property PACKAGE_PIN Y14 [get_ports {dig_sel[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dig_sel[0]}]

# DIG2 -> J10 PIN13 -> P18
set_property PACKAGE_PIN P18 [get_ports {dig_sel[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dig_sel[1]}]

# DIG3 -> J10 PIN15 -> U15
set_property PACKAGE_PIN U15 [get_ports {dig_sel[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dig_sel[2]}]

set_property PACKAGE_PIN P16 [get_ports {dig_sel[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dig_sel[3]}]

set_property PACKAGE_PIN R14 [get_ports {seg[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]

set_property PACKAGE_PIN P14 [get_ports {seg[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]

set_property PACKAGE_PIN Y17 [get_ports {seg[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]

set_property PACKAGE_PIN Y16 [get_ports {seg[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]

set_property PACKAGE_PIN W15 [get_ports {seg[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]

set_property PACKAGE_PIN V15 [get_ports {seg[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]

set_property PACKAGE_PIN W14 [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

set_property PACKAGE_PIN N17 [get_ports {seg[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[7]}]
