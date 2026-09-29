# top.xdc - AD9764 dual AM/FM ���� (125 MSPS)
# ����: xc7z020clg400-2, BANK34 (50 MHz & keys) + BANK35 (DAC ����/ʱ��)

# -----------------------------------------------------------------------------
# ��ʱ�� 50 MHz (BANK34, U18)
# Vivado ����ݴ���ʱ�ӣ��Զ��Ƶ� MMCM �� CLKOUT0 �� CLKOUT1 ��� 125MHz ʱ�ӣ�
# ������������ XDC ��Ϊ CLKOUT0 / CLKOUT1 �ٴ������κ� create_clock �� rename_clock��
# -----------------------------------------------------------------------------
create_clock -period 20.000 -name clk_50m -waveform {0.000 10.000} [get_ports clk_50m]
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]

# -----------------------------------------------------------------------------
# ���� (BANK34, ����Ч)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN N15 [get_ports key1]
set_property PACKAGE_PIN N16 [get_ports key2]
set_property PACKAGE_PIN T17 [get_ports key3]
set_property IOSTANDARD LVCMOS33 [get_ports {key1 key2 key3}]
set_property PULLUP true [get_ports {key1 key2 key3}]

# -----------------------------------------------------------------------------
# CHA ���� (BANK35, J11 Pin 7-22 -> FPGA L16..G20)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN L16 [get_ports {cha_data[0]}]
set_property PACKAGE_PIN H20 [get_ports {cha_data[1]}]
set_property PACKAGE_PIN J20 [get_ports {cha_data[2]}]
set_property PACKAGE_PIN J19 [get_ports {cha_data[3]}]
set_property PACKAGE_PIN K19 [get_ports {cha_data[4]}]
set_property PACKAGE_PIN K18 [get_ports {cha_data[5]}]
set_property PACKAGE_PIN K17 [get_ports {cha_data[6]}]
set_property PACKAGE_PIN M20 [get_ports {cha_data[7]}]
set_property PACKAGE_PIN M19 [get_ports {cha_data[8]}]
set_property PACKAGE_PIN L20 [get_ports {cha_data[9]}]
set_property PACKAGE_PIN L19 [get_ports {cha_data[10]}]
set_property PACKAGE_PIN H18 [get_ports {cha_data[11]}]
set_property PACKAGE_PIN J18 [get_ports {cha_data[12]}]
set_property PACKAGE_PIN G20 [get_ports {cha_data[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports cha_data[*]]
set_property SLEW SLOW [get_ports cha_data[*]]
set_property DRIVE 4 [get_ports cha_data[*]]

# CHA ת��ʱ�� (ODDR ת��) Pin 8 / G19
set_property PACKAGE_PIN G19 [get_ports cha_clk]
set_property IOSTANDARD LVCMOS33 [get_ports cha_clk]
set_property SLEW SLOW [get_ports cha_clk]
set_property DRIVE 4 [get_ports cha_clk]

# -----------------------------------------------------------------------------
# CHB ���� (BANK35, J11 Pin 23-36 -> M18..K14)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN J14 [get_ports {chb_data[0]}]
set_property PACKAGE_PIN K14 [get_ports {chb_data[1]}]
set_property PACKAGE_PIN G15 [get_ports {chb_data[2]}]
set_property PACKAGE_PIN H15 [get_ports {chb_data[3]}]
set_property PACKAGE_PIN H17 [get_ports {chb_data[4]}]
set_property PACKAGE_PIN H16 [get_ports {chb_data[5]}]
set_property PACKAGE_PIN G18 [get_ports {chb_data[6]}]
set_property PACKAGE_PIN G17 [get_ports {chb_data[7]}]
set_property PACKAGE_PIN E19 [get_ports {chb_data[8]}]
set_property PACKAGE_PIN E18 [get_ports {chb_data[9]}]
set_property PACKAGE_PIN D20 [get_ports {chb_data[10]}]
set_property PACKAGE_PIN D19 [get_ports {chb_data[11]}]
set_property PACKAGE_PIN M18 [get_ports {chb_data[12]}]
set_property PACKAGE_PIN M17 [get_ports {chb_data[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports chb_data[*]]
set_property SLEW SLOW [get_ports chb_data[*]]
set_property DRIVE 4 [get_ports chb_data[*]]

# CHB ת��ʱ�� (ODDR ת��) Pin 21 / L17
set_property PACKAGE_PIN L17 [get_ports chb_clk]
set_property IOSTANDARD LVCMOS33 [get_ports chb_clk]
set_property SLEW SLOW [get_ports chb_clk]
set_property DRIVE 4 [get_ports chb_clk]

# -----------------------------------------------------------------------------
# ״̬ LED (BANK34, ����Ч)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN M14 [get_ports {status_led[0]}]
set_property PACKAGE_PIN M15 [get_ports {status_led[1]}]
set_property PACKAGE_PIN K16 [get_ports {status_led[2]}]
set_property PACKAGE_PIN J16 [get_ports {status_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports status_led[*]]

# -----------------------------------------------------------------------------
# ����/ȫ��
# -----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# �첽·�� (��ʱ���� + ��λ + �ڲ������ź�)
set_false_path -from [get_ports {key1 key2 key3}]
set_false_path -to [get_ports {status_led[*]}]

# -----------------------------------------------------------------------------
# DAC ʱ�ӵ����ݵ� source-synchronous output delay
# -----------------------------------------------------------------------------
create_generated_clock -name clk_cha_out -source [get_pins u_mmcm/mmcm_inst/CLKOUT1] \
    -multiply_by 1 [get_ports cha_clk]
create_generated_clock -name clk_chb_out -source [get_pins u_mmcm/mmcm_inst/CLKOUT1] \
    -multiply_by 1 [get_ports chb_clk]

set_output_delay -clock [get_clocks clk_cha_out] -max -2.0 [get_ports cha_data[*]]
set_output_delay -clock [get_clocks clk_cha_out] -min -1.5 [get_ports cha_data[*]]
set_output_delay -clock [get_clocks clk_chb_out] -max -2.0 [get_ports chb_data[*]]
set_output_delay -clock [get_clocks clk_chb_out] -min -1.5 [get_ports chb_data[*]]