set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m -waveform {0.000 10.000} [get_ports clk_50m]

# ============================================================================
# ADC 通道 A 数据/溢出/采样时钟 (CHA only, CHB 全部去除)
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

set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[*]}]

# ACLK -> P14 (ODDR 4 MHz 输出)
set_property PACKAGE_PIN P14 [get_ports adc_aclk_p14]
set_property IOSTANDARD LVCMOS33 [get_ports adc_aclk_p14]

# ORA -> P16
set_property PACKAGE_PIN P16 [get_ports adc_a_ora]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_ora]

# ---- 时序例外: 异步输入 ----
set_false_path -from [get_ports adc_a_ora]

# ============================================================================
# UART (J11 扩展口, BANK35, 3.3V)
# ============================================================================
# J11 PIN4 (EX_IO2_1P) = F16 = uart_rx_from_stm
# J11 PIN3 (EX_IO2_1N) = F17 = uart_tx_to_stm
set_property PACKAGE_PIN F16 [get_ports uart_rx_from_stm]
set_property PACKAGE_PIN F17 [get_ports uart_tx_to_stm]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx_from_stm uart_tx_to_stm}]
set_property PULLUP true [get_ports uart_rx_from_stm]
set_false_path -from [get_ports uart_rx_from_stm]

# ============================================================================
# PL 用户 LED (BANK35, 低电平点亮)
# ============================================================================
# LED1=M14, LED2=M15, LED3=K16, LED4=J16
# LED0 = MMCM locked, LED1 = clk_wiz locked, LED2 = proto busy, LED3 = error
set_property PACKAGE_PIN M14 [get_ports {led_status[0]}]
set_property PACKAGE_PIN M15 [get_ports {led_status[1]}]
set_property PACKAGE_PIN K16 [get_ports {led_status[2]}]
set_property PACKAGE_PIN J16 [get_ports {led_status[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[*]}]

# ============================================================================
# 4 MHz 主数据通路时钟 clk_4m
# MMCM 8 MHz (CLKOUT0, 125 ns) 经翻转寄存器二分频 + BUFG -> 4 MHz / 250 ns
# ============================================================================
create_generated_clock -name clk_4m -divide_by 2 \
    -source [get_pins u_mmcm/mmcm_inst/CLKOUT0] \
    [get_pins u_div2/clk_div_r_reg/Q]

# ============================================================================
# 跨时钟域 (CDC) 约束
# 协议引擎使用"握手 + 多比特数据 + 多级同步器"方式在 clk_uart(14.7456 MHz)
# 与 clk_4m(4 MHz) 之间传输。所有进入目的域"第一级"同步/捕获寄存器的路径
# 按 false_path 处理:单比特信号在该级允许亚稳态(由后续同步级消除),多比特
# 数据在握手保证稳定后才被采样。各同步器的后续级仍在同一时钟域内,正常做
# 时序分析。
# ============================================================================
# clk_uart -> clk_4m: 第一级同步器 / 数据捕获
set_false_path -quiet -to [get_cells -quiet { \
    u_proto/tx_busy_meta_reg \
    u_proto/cmd_toggle_meta_reg \
    u_proto/cmd_type_meta_reg[*] \
    u_proto/cmd_seq_meta_reg[*] \
    u_proto/cmd_mode_meta_reg[*] }]
# clk_4m -> clk_uart: 第一级同步器 + 发送字节捕获
set_false_path -quiet -to [get_cells -quiet { \
    u_proto/mbox_req_meta_reg \
    u_proto/tx_data_uart_reg[*] }]

# ============================================================================
# Debug Hub 时钟约束 - 必须! 使 hw_server 能访问 mark_debug 自动生成的 ILA
# ============================================================================
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_4m]
