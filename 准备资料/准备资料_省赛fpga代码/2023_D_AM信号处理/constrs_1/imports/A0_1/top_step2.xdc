#==============================================================================
# top_step2.xdc - Constraints for Step 2: AM Signal Detection
#==============================================================================

#------------------------------------------------------------------------------
# 系统主时钟物理约束 (50 MHz)
#------------------------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk [get_ports clk_50m]

#------------------------------------------------------------------------------
# ADC A 通道物理引脚约束 (12-bit)
#------------------------------------------------------------------------------
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

# ADC A 通道溢出引脚及异步路径处理
set_property PACKAGE_PIN P16 [get_ports adc_a_ora]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_ora]
set_false_path -from [get_ports adc_a_ora]

# ADC A 采样工作时钟管脚输出 (直插杜邦线连 P14)
set_property PACKAGE_PIN P14 [get_ports adc_aclk_p14]
set_property IOSTANDARD LVCMOS33 [get_ports adc_aclk_p14]

#------------------------------------------------------------------------------
# ADC B 通道物理引脚约束 (未被使用，设为 false_path 以防止偶发时序警告)
#------------------------------------------------------------------------------
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
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[*]}]
set_false_path -from [get_ports {adc_b_data[*]}]

# ADC B 溢出及采样时钟输出物理管脚
set_property PACKAGE_PIN T10 [get_ports adc_b_orb]
set_property IOSTANDARD LVCMOS33 [get_ports adc_b_orb]
set_false_path -from [get_ports adc_b_orb]

set_property PACKAGE_PIN T16 [get_ports adc_bck_t16]
set_property IOSTANDARD LVCMOS33 [get_ports adc_bck_t16]
set_false_path -to [get_ports adc_bck_t16]

#------------------------------------------------------------------------------
# 外部输入按键及 LED 信号约束
#------------------------------------------------------------------------------
# PL 按键 (低电平有效，带上拉)
set_property PACKAGE_PIN N15 [get_ports {pl_key[0]}]
set_property PACKAGE_PIN N16 [get_ports {pl_key[1]}]
set_property PACKAGE_PIN T17 [get_ports {pl_key[2]}]
set_property PACKAGE_PIN R17 [get_ports {pl_key[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pl_key[*]}]
set_property PULLUP true [get_ports {pl_key[*]}]
# 按键属于异步漫输入，阻断其路径分析以满足时序收敛
set_false_path -from [get_ports {pl_key[*]}]

# PL LEDs (物理引脚低有效)
set_property PACKAGE_PIN M14 [get_ports {pl_led[0]}]
set_property PACKAGE_PIN M15 [get_ports {pl_led[1]}]
set_property PACKAGE_PIN K16 [get_ports {pl_led[2]}]
set_property PACKAGE_PIN J16 [get_ports {pl_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pl_led[*]}]
set_false_path -to [get_ports {pl_led[*]}]

#------------------------------------------------------------------------------
# 4 位带小数点共阳极数码管管脚约束
#------------------------------------------------------------------------------
# 数码管段输出：A / B / C / D / E / F / G / DP (低电平点亮)
set_property PACKAGE_PIN F20 [get_ports {seg[0]}]  
set_property PACKAGE_PIN F19 [get_ports {seg[1]}]  
set_property PACKAGE_PIN G20 [get_ports {seg[2]}]  
set_property PACKAGE_PIN G19 [get_ports {seg[3]}]  
set_property PACKAGE_PIN H18 [get_ports {seg[4]}]  
set_property PACKAGE_PIN J18 [get_ports {seg[5]}]  
set_property PACKAGE_PIN L19 [get_ports {seg[6]}]  
set_property PACKAGE_PIN M19 [get_ports {seg[7]}]  
set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]
set_false_path -to [get_ports {seg[*]}]

# 数码管位输出：DIG1 / DIG2 / DIG3 / DIG4 (高电平使能)
set_property PACKAGE_PIN L20 [get_ports {dig_sel[0]}]  
set_property PACKAGE_PIN M20 [get_ports {dig_sel[1]}]  
set_property PACKAGE_PIN K18 [get_ports {dig_sel[2]}]  
set_property PACKAGE_PIN J19 [get_ports {dig_sel[3]}]  
set_property IOSTANDARD LVCMOS33 [get_ports {dig_sel[*]}]
set_false_path -to [get_ports {dig_sel[*]}]

#------------------------------------------------------------------------------
# 闲置公引脚解调输出接口 (J11.PIN20 = J20)
#------------------------------------------------------------------------------
set_property PACKAGE_PIN J20 [get_ports uo_ana]
set_property IOSTANDARD LVCMOS33 [get_ports uo_ana]
set_false_path -to [get_ports uo_ana]

#------------------------------------------------------------------------------
# 芯片配置电平设定
#------------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

#------------------------------------------------------------------------------
# 时序与延迟分析 (采用自适应推断时钟，对输入 ADC 端口进行约束)
#------------------------------------------------------------------------------
# 利用 get_clocks 获取 MMCM 自动衍生的 40MHz 主时钟，避免覆盖及 overlapping
set adc_clk_obj [get_clocks -of_objects [get_pins u_mmcm/mmcm_inst/CLKOUT0]]

set_input_delay -clock $adc_clk_obj -max 5.0 [get_ports {adc_a_data[*]}]
set_input_delay -clock $adc_clk_obj -min 1.0 [get_ports {adc_a_data[*]}]