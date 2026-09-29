#!/usr/bin/env python3
"""对所有 4 个文件, 算 bin 偏移 = cordic_bin - python_fft_bin"""
import csv
import numpy as np
from collections import defaultdict

for fp_name in ['iladata_100kHz_50mV.csv', 'iladata_150kHz_100mV.csv', 'iladata.csv', 'iladata_mux1.csv']:
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

    if not adc_vals:
        continue

    adc = np.array(adc_vals, dtype=np.float64)
    x = adc - adc.mean()
    X = np.fft.rfft(x)
    mag = np.abs(X) / len(x)

    # 主峰 (跳过 DC)
    main_idx = np.argmax(mag[1:]) + 1
    py_bin = main_idx
    py_freq = main_idx * 4e6 / len(adc)

    # CORDIC mag top bins
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
    offset = cordic_bin - py_bin

    print(f"{fp_name:30s}  N={len(adc):5d}  py_bin={py_bin:4d} ({py_freq/1000:6.2f} kHz)  cordic_bin={cordic_bin:4d}  offset={offset:+4d}")