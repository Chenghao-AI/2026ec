#!/usr/bin/env python3
"""看混合信号 FFT 的具体 bin 30 (15kHz target) 和 bin 370 (180kHz target) 附近"""
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

adc = np.array(adc_vals, dtype=np.float64)
print(f"N samples = {len(adc)}")
print(f"ADC mean = {adc.mean():.2f}, P2P = {adc.max()-adc.min():.1f}")

# DC removal
x = adc - adc.mean()

# 不 zero-pad, 真实 FFT
N = len(x)
X = np.fft.rfft(x)
mag = np.abs(X) / N
freqs = np.arange(len(X)) * 4e6 / N

# 找 10 kHz 附近 (bin 20-21)
print(f"\n  Bin ~20 (10 kHz expected):")
for b in range(15, 30):
    print(f"    bin={b:4d}, freq={freqs[b]:.2f} Hz, mag={mag[b]:.4f}")

# 找 180 kHz 附近 (bin 369)
print(f"\n  Bin ~369 (180 kHz expected):")
for b in range(360, 380):
    print(f"    bin={b:4d}, freq={freqs[b]:.2f} Hz, mag={mag[b]:.4f}")

# 找 200 kHz 附近 (bin 410)
print(f"\n  Bin ~410 (200 kHz):")
for b in range(400, 420):
    print(f"    bin={b:4d}, freq={freqs[b]:.2f} Hz, mag={mag[b]:.4f}")

# DC bin
print(f"\n  DC bin=0: mag={mag[0]:.4f}")

# Setup ratio test
print(f"\n  Ratio at expected 10 kHz vs 180 kHz:")
print(f"    10 kHz (bin 20) mag = {mag[20]:.4f}")
print(f"    180 kHz (bin 369) mag = {mag[369]:.4f}")
print(f"    Ratio = {mag[369]/mag[20]:.2f}")
print(f"    Expected by signal '6*sin(180kHz) / 2*sin(10kHz)' = 3.0")

# 整体最大峰
top = np.argsort(mag)[::-1][:10]
print(f"\n  Top 10 peaks (full mag):")
for t in top:
    print(f"    bin={t:4d}, freq={freqs[t]:.2f} Hz, mag={mag[t]:.4f}")