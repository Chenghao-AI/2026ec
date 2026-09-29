#!/usr/bin/env python3
"""用 iladata.csv 模拟单片机接收到的 (bin, mag) 数组, 并画出 'MCU 视角的频谱图'"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

# 收集 first cycle 的 mag (单片机视角)
first_cycle = {}
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            buf = int(row[0])
            bin_idx = int(row[4])
            mag = int(row[3])
            valid = int(row[5], 16)
            if valid == 1 and buf < 6144:  # 第一三角坡
                if bin_idx not in first_cycle:
                    first_cycle[bin_idx] = mag
        except: continue

# 排序: ILA bin 0..2047
ila_bins = np.array(sorted(first_cycle.keys()))
mags = np.array([first_cycle[b] for b in ila_bins])

# 单片机解码: ila_bin -> real_bin (real_bin = ila_bin - 200 if ila_bin >= 200 else +2048)
real_bins = (ila_bins.astype(int) - 200) % 2048
# 频率 (kHz)
freq_kHz = real_bins * 488.281 / 1000.0

# 用户过滤: 只在 5-500 kHz 范围
mask = (freq_kHz >= 5) & (freq_kHz <= 500)
print(f"总接收点: {len(ila_bins)}")
print(f"5-500 kHz 范围内点: {mask.sum()} (≈ {(mask.sum())*0 + 1014} 预期)")

# 找峰值
# 简单找 max mag in valid range
valid_idx = np.where(mask)[0]
local_max_i = valid_idx[np.argmax(mags[valid_idx])]
peak_ila_bin = ila_bins[local_max_i]
peak_real_bin = real_bins[local_max_i]
peak_freq_kHz = freq_kHz[local_max_i]
peak_mag = mags[local_max_i]

print(f"\n=== 主峰 (5-500 kHz 内) ===")
print(f"  ILA bin: {peak_ila_bin}")
print(f"  Real bin: {peak_real_bin}")
print(f"  Freq: {peak_freq_kHz:.2f} kHz")
print(f"  Mag: {peak_mag}")

# Vpp 换算
ATTEN = 5.0
V_LSB = 0.002441  # V/LSB
N_FFT = 8192
peak_amp_ADC_V = 4.0 * peak_mag / N_FFT * V_LSB  # peak amplitude at ADC
vpp_ADC_mV = peak_amp_ADC_V * 1000 * 2  # ×2 for Vpp
vpp_src_mV = vpp_ADC_mV * ATTEN
print(f"\n=== 幅度换算 ===")
print(f"  peak_amp_ADC = {peak_amp_ADC_V*1000:.2f} mV")
print(f"  Vpp_ADC = {vpp_ADC_mV:.2f} mV")
print(f"  Vpp_source = {vpp_src_mV:.2f} mV (5x 衰减补偿)")

# Print filtered spectrum (5-500 kHz)
print(f"\n=== 单片机看到的频谱 (filtered) ===")
print(f"  {'ILA bin':>6} {'real bin':>8} {'freq (kHz)':>10} {'mag':>5}")
for i in valid_idx:
    print(f"  {ila_bins[i]:6d} {real_bins[i]:8d} {freq_kHz[i]:10.3f} {mags[i]:5d}")

# Save filtered data
import json
output_data = []
for i in valid_idx:
    output_data.append({
        'ila_bin': int(ila_bins[i]),
        'real_bin': int(real_bins[i]),
        'freq_kHz': float(freq_kHz[i]),
        'mag': int(mags[i]),
        'vpp_mV_at_src': 8.0 * mags[i] / N_FFT * V_LSB * 1000 * ATTEN
    })
with open(r"C:\Users\24307\Desktop\FPGA_windows\other_tools\mcu_view.json", 'w') as f:
    json.dump(output_data, f, indent=2)
print(f"\nSaved MCU view to mcu_view.json with {len(output_data)} points")