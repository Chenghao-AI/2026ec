# ============================================================================
# B2.1 XDC — ADC 双通道同步采样 (40 MHz MMCM, 极简 JTAG-ILA 验证版)
# ============================================================================
# FPGA: Xilinx Zynq-7000 XC7Z020-2CLG400I
# 板:   ALINX AX7020 (BANK34 + BANK35, 3.3V)
# ============================================================================

# ---- 主时钟: 50 MHz 板载晶振 (U18) ----
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m -waveform {0.000 10.000} [get_ports clk_50m]

# ============================================================================
# ADC 通道 A — 数据/溢出/采样时钟
# ============================================================================
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

# ACK -> P14
set_property PACKAGE_PIN P14 [get_ports adc_aclk_p14]
set_property IOSTANDARD LVCMOS33 [get_ports adc_aclk_p14]

# ORA -> P16
set_property PACKAGE_PIN P16 [get_ports adc_a_ora]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_ora]

# ============================================================================
# ADC 通道 B — 数据/溢出/采样时钟
# ============================================================================
set_property PACKAGE_PIN U17 [get_ports {adc_b_data[0]}]
set_property PACKAGE_PIN V17 [get_ports {adc_b_data[1]}]
set_property PACKAGE_PIN V18 [get_ports {adc_b_data[2]}]
set_property PACKAGE_PIN T14 [get_ports {adc_b_data[3]}]
set_property PACKAGE_PIN T15 [get_ports {adc_b_data[4]}]
set_property PACKAGE_PIN U13 [get_ports {adc_b_data[5]}]
set_property PACKAGE_PIN V13 [get_ports {adc_b_data[6]}]
set_property PACKAGE_PIN V12 [get_ports {adc_b_data[7]}]
set_property PACKAGE_PIN W13 [get_ports {adc_b_data[8]}]
set_property PACKAGE_PIN T12 [get_ports {adc_b_data[9]}]
set_property PACKAGE_PIN U12 [get_ports {adc_b_data[10]}]
set_property PACKAGE_PIN T11 [get_ports {adc_b_data[11]}]

# BCK -> T16
set_property PACKAGE_PIN T16 [get_ports adc_bck_t16]
set_property IOSTANDARD LVCMOS33 [get_ports adc_bck_t16]

# ORB -> T10
set_property PACKAGE_PIN T10 [get_ports adc_b_orb]
set_property IOSTANDARD LVCMOS33 [get_ports adc_b_orb]

# I/O 电平: 全部 LVCMOS33
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[*]}]

# ---- 时序例外 ----
set_false_path -from [get_ports {adc_a_ora adc_b_orb}]

# ============================================================================
# ILA 调试
# ============================================================================

# ILA 时钟: MMCM 输出的 40 MHz (经 BUFG 后)

# probe0: 通道 A 12-bit 数据

# probe1: 通道 B 12-bit 数据

# probe2: 通道 A 溢出

# probe3: 通道 B 溢出

# dbg_hub 配置




create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list u_mmcm/io_clk_40m]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {u_core/core/io_adc_data_a[0]} {u_core/core/io_adc_data_a[1]} {u_core/core/io_adc_data_a[2]} {u_core/core/io_adc_data_a[3]} {u_core/core/io_adc_data_a[4]} {u_core/core/io_adc_data_a[5]} {u_core/core/io_adc_data_a[6]} {u_core/core/io_adc_data_a[7]} {u_core/core/io_adc_data_a[8]} {u_core/core/io_adc_data_a[9]} {u_core/core/io_adc_data_a[10]} {u_core/core/io_adc_data_a[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {u_core/core/io_adc_data_b[0]} {u_core/core/io_adc_data_b[1]} {u_core/core/io_adc_data_b[2]} {u_core/core/io_adc_data_b[3]} {u_core/core/io_adc_data_b[4]} {u_core/core/io_adc_data_b[5]} {u_core/core/io_adc_data_b[6]} {u_core/core/io_adc_data_b[7]} {u_core/core/io_adc_data_b[8]} {u_core/core/io_adc_data_b[9]} {u_core/core/io_adc_data_b[10]} {u_core/core/io_adc_data_b[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list u_core/core/io_ora]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list u_core/core/io_orb]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_40m]
