#!/usr/bin/env python3
"""直接对 ADC 数据做 FFT 并找峰 (Python 验证)"""
import csv
import numpy as np
fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

adc_vals = []
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            valid = int(row[5], 16)
            a = int(row[6], 16)
        except: continue
        if valid == 1:
            if a > 2047: a -= 4096
            adc_vals.append(a)

print(f"Got {len(adc_vals)} valid samples")
adc = np.array(adc_vals, dtype=np.float64)
print(f"ADC range: {adc.min():.1f} .. {adc.max():.1f}, P2P = {adc.max()-adc.min():.1f}")
print(f"Mean: {adc.mean():.2f}")

# 去 DC
x = adc - adc.mean()
print(f"After DC removal: mean = {x.mean():.4f}, P2P = {x.max()-x.min():.1f}")

# FFT
N = len(x)
X = np.fft.rfft(x)
mag = np.abs(X) / N
print(f"FFT: {len(X)} bins")

# 找 top 10 peaks
top_idx = np.argsort(mag)[::-1][:20]
print(f"\nTop 20 FFT bins (single-sided |X|/N):")
for idx in sorted(top_idx):
    freq = idx * 4e6 / 8192  # full range fs=4MHz
    # 但 fs 可能不对! 我们只用了 N samples in 时间
    freq2 = idx * 4e6 / N    # 实际 fs (但 fs=4MHz, N=4096 => bin=488Hz)
    print(f"  bin={idx:4d}, freq1={freq2:.1f} Hz ({freq2/1000:.3f} kHz), mag={mag[idx]:.3f}")

# 时域看几个周期
print(f"\nFirst 50 samples (signed ADC):")
print(adc_vals[:50])
print(f"\nSample at index 200:")
print(adc_vals[195:215])