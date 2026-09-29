#!/usr/bin/env python3
"""最基础方法: 直接对 ADC 数据做 FFT, 不做任何偏置假设"""
import csv
import numpy as np
from collections import defaultdict

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
            if valid == 1:
                if a > 2047: a -= 4096
                adc_vals.append(a)
        except: continue

adc = np.array(adc_vals, dtype=np.float64)
N = len(adc)
x = adc - adc.mean()

# Hann 窗 (与 Verilog 端一致)
n_idx = np.arange(N)
hann = 0.5 * (1 - np.cos(2 * np.pi * n_idx / (N - 1)))
xh = x * hann

# FFT (单边谱)
X = np.fft.rfft(xh)
coherent_gain = np.sum(hann) / N  # ≈ 0.5
mag = np.abs(X) / N * 2  # 单边谱 peak amplitude (与 mag_hann_comp 公式一致)
freqs = np.arange(len(X)) * 4e6 / N

# 找 top 5
top_idx = np.argsort(mag[1:])[::-1][:5] + 1
print(f"N = {N} samples, Hann windowed FFT, fs = 4 MHz")
print(f"Δf = {4e6/N:.3f} Hz/bin")
print(f"\nTop 5 peaks (mag_hann_comp formula):")
for t in top_idx:
    print(f"  bin={t:4d}, freq={freqs[t]:10.2f} Hz ({freqs[t]/1000:7.3f} kHz), mag={mag[t]:.3f} mV (peak amplitude)")

# 也尝试 zero-pad 到 32768
N_pad = 32768
xp = np.zeros(N_pad)
xp[:N] = xh
Xp = np.fft.rfft(xp)
mag_p = np.abs(Xp) / N * 2
freqs_p = np.arange(len(Xp)) * 4e6 / N_pad
top_p = np.argsort(mag_p[1:])[::-1][:5] + 1
print(f"\n--- Zero-padded to N=32768 ---")
print(f"Δf = {4e6/N_pad:.3f} Hz/bin")
print(f"Top 5 peaks:")
for t in top_p:
    print(f"  bin={t:5d}, freq={freqs_p[t]:10.2f} Hz ({freqs_p[t]/1000:7.3f} kHz), mag={mag_p[t]:.3f} mV")

# 期望信号
print(f"\n--- 期望信号 ---")
print(f"  10 kHz  -> bin = {10000/(4e6/N):.2f}  (N={N})")
print(f"  180 kHz -> bin = {180000/(4e6/N):.2f}  (N={N})")
print(f"  10 kHz  -> bin = {10000/(4e6/N_pad):.2f}  (N={N_pad})")
print(f"  180 kHz -> bin = {180000/(4e6/N_pad):.2f}  (N={N_pad})")
print(f"  Vpp_1 = 2*2.441 = {2*2.441:.2f} mV (10 kHz 2 LSB)")
print(f"  Vpp_2 = 6*2.441 = {6*2.441:.2f} mV (180 kHz 6 LSB)")
print(f"  180/10 ratio = 3.0 (理论上 mag_180/mag_10 = 3.0)")