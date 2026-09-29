#!/usr/bin/env python3
"""用 N=32768 重做 FFT, 同时尝试 zero-padding 4096 到 32768"""
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
            if valid == 1:
                if a > 2047: a -= 4096
                adc_vals.append(a)
        except: continue

adc = np.array(adc_vals, dtype=np.float64)
print(f"N samples = {len(adc)}")

# FFT with N = 4096
x = adc - adc.mean()
X = np.fft.rfft(x)
mag = np.abs(X) / len(x)
freqs = np.arange(len(X)) * 4e6 / len(x)

# Hann 窗 (matching Verilog)
N_hann = len(x)
n_idx = np.arange(N_hann)
hann = 0.5 * (1 - np.cos(2 * np.pi * n_idx / (N_hann - 1)))
xh = x * hann
Xh = np.fft.rfft(xh)
mag_h = np.abs(Xh) / (np.sum(hann) / 2)  # coherent gain compensation
freqs_h = np.arange(len(Xh)) * 4e6 / len(xh)

# 找 top peaks
top_idx = np.argsort(mag_h[1:])[::-1][:10] + 1
print(f"\nTop 10 peaks (Hann windowed, N=4096):")
for t in sorted(top_idx):
    print(f"  bin={t:4d}, freq={freqs_h[t]/1000:.3f} kHz, mag={mag_h[t]:.3f}")

# 10 kHz expected bin
print(f"\nExpected bins for signal '2*sin(10kHz*t) + 6*sin(180kHz*t)':")
print(f"  10 kHz  -> bin = {10000/(4e6/4096):.2f}")
print(f"  180 kHz -> bin = {180000/(4e6/4096):.2f}")

# ratio check
print(f"\nFFT mag at expected bins:")
print(f"  bin 31 (10 kHz expected)  mag = {mag_h[31]:.4f}")
print(f"  bin 369 (180 kHz expected, N=4096)  mag = {mag_h[369]:.4f}")

# Wait - let me also try zero-pad to 32768 (which is what FFT IP does)
N_pad = 32768
x_pad = np.zeros(N_pad)
# Hann window the same N=4096 region
xh_pad = xh.copy()
x_pad[:len(xh)] = xh
Xp = np.fft.rfft(x_pad)
mag_p = np.abs(Xp) / (np.sum(hann) / 2)
freqs_p = np.arange(len(Xp)) * 4e6 / N_pad
print(f"\n--- With zero-pad to N=32768 ---")
top_p = np.argsort(mag_p[1:])[::-1][:10] + 1
print(f"Top 10 peaks:")
for t in sorted(top_p):
    print(f"  bin={t:5d}, freq={freqs_p[t]/1000:.3f} kHz, mag={mag_p[t]:.3f}")

# Expected bins for N=32768
print(f"\nExpected bins (N=32768):")
print(f"  10 kHz  -> bin = {10000/(4e6/32768):.2f}")
print(f"  180 kHz -> bin = {180000/(4e6/32768):.2f}")
print(f"  10 kHz  -> mod 8192 = {int(10000/(4e6/32768)) % 8192}")
print(f"  180 kHz -> mod 8192 = {int(180000/(4e6/32768)) % 8192}")