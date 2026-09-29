#!/usr/bin/env python3
"""分析 100 kHz 数据的 bin 偏移 (verilog +200 偏置是否一致)"""
import csv
import numpy as np
from collections import defaultdict

for fp_name in ['iladata_100kHz_50mV.csv', 'iladata_150kHz_100mV.csv', 'iladata.csv']:
    fp = rf"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\{fp_name}"

    # ADC 时域 FFT
    adc_vals = []
    with open(fp) as f:
        reader = csv.reader(f)
        next(reader); next(reader)
        for row in reader:
            if len(row) < 7: continue
            try:
                valid = int(row[5], 16)
                a = int(row[6], 16)
                if valid == 1:
                    if a > 2047: a -= 4096
                    adc_vals.append(a)
            except: continue

    adc = np.array(adc_vals, dtype=np.float64)
    x = adc - adc.mean()
    X = np.fft.rfft(x)
    mag = np.abs(X) / len(x)

    # 主峰
    top_idx = np.argmax(mag[1:]) + 1   # 跳过 DC
    py_freq = top_idx * 4e6 / 8192

    # CORDIC mag 峰值
    bin_mags = defaultdict(list)
    with open(fp) as f:
        reader = csv.reader(f)
        next(reader); next(reader)
        for row in reader:
            if len(row) < 7: continue
            try:
                bin_idx = int(row[4])
                mag_v = int(row[3])
                valid = int(row[5], 16)
                if valid == 1:
                    bin_mags[bin_idx].append(mag_v)
            except: continue

    cordic_top = sorted([(max(m), b) for b, m in bin_mags.items()], reverse=True)[0]
    cordic_bin = cordic_top[1]
    cordic_freq_direct = cordic_bin * 4e6 / 8192
    cordic_freq_real   = (cordic_bin - 200) * 4e6 / 8192

    # 计算 bin 偏移
    py_bin = top_idx
    cordic_real_bin = cordic_bin - 200

    print(f"\n=== {fp_name} ===")
    print(f"  N samples = {len(x)}")
    print(f"  Python FFT: bin={py_bin}, freq={py_freq:.2f} Hz")
    print(f"  CORDIC ILA bin={cordic_bin}, direct freq={cordic_freq_direct:.2f} Hz")
    print(f"  CORDIC real_bin={cordic_real_bin}, real freq={cordic_freq_real:.2f} Hz")
    print(f"  Offset (cordic_real_bin - py_bin) = {cordic_real_bin - py_bin}")