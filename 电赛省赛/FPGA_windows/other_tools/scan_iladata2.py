#!/usr/bin/env python3
"""快速扫描 iladata2.csv"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata2.csv"

# 行数
with open(fp) as f:
    lines = f.readlines()
print(f"Total lines: {len(lines)}")
print(f"Header: {lines[0].strip()}")
print(f"Radix:  {lines[1].strip()}")
print(f"First data: {lines[2].strip()}")
print(f"Last data:  {lines[-1].strip()}")

# 读 valid=1
adc_vals = []
bin_mags = defaultdict(list)
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            valid = int(row[5], 16)
            a = int(row[6], 16)
            mag = int(row[3])
            bin_idx = int(row[4])
            buf = int(row[0])
        except: continue
        if valid == 1:
            if a > 2047: a -= 4096
            adc_vals.append(a)
            bin_mags[bin_idx].append(mag)

adc = np.array(adc_vals, dtype=np.float64)
print(f"\nValid samples: {len(adc)}")
print(f"ADC range: {adc.min()}..{adc.max()}, P2P={adc.max()-adc.min()} LSB")
print(f"ADC P2P mV = {(adc.max()-adc.min()) * 5000/2048:.2f} mV")

# FFT (zero-pad 到 8192)
N = len(adc)
x = adc - adc.mean()
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
xh = x * hann
N_FFT = 8192
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag = np.abs(X) / N * 2  # 单边谱 peak amplitude (Hann-未补偿)
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 top peaks
top = np.argsort(mag[1:])[::-1][:5] + 1
print(f"\nTop 5 FFT peaks (Δf=488 Hz/bin, N_FFT=8192):")
for t in top:
    print(f"  bin={t}, freq={freqs[t]/1000:.3f} kHz, mag={mag[t]:.3f} mV (peak)")

# CORDIC mag top bins
bin_max = {b: max(m) for b, m in bin_mags.items()}
cordic_top = sorted(bin_max.items(), key=lambda x: -x[1])[:5]
print(f"\nCORDIC mag top 5 (raw ILA bin):")
for b, m in cordic_top:
    real_bin = b - 200
    freq = real_bin * 4e6 / N_FFT if real_bin > 0 else 0
    print(f"  ILA bin={b}, real_bin={real_bin}, freq={freq/1000:.3f} kHz, mag={m}")

# 信号预期
print(f"\nExpected: 16 kHz -> bin = {16000/(4e6/N_FFT):.1f} (real), ILA bin = {int(16000/(4e6/N_FFT))+200}")
print(f"Expected: 80 kHz -> bin = {80000/(4e6/N_FFT):.1f} (real), ILA bin = {int(80000/(4e6/N_FFT))+200}")
print(f"\nExpected Vpp: 50 mV total (16k: ~8.3 mV, 80k: ~41.7 mV)")
print(f"  if peak amplitudes A1/A2 with A1/A2 = 1/5:")
print(f"  A1 + A2 = peak total = 25 mV -> A1=4.17 mV peak (8.33 mV Vpp), A2=20.83 mV peak (41.67 mV Vpp)")