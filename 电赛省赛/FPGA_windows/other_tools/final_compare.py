#!/usr/bin/env python3
"""最终精确对比: Python FFT vs ILA 显示"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

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
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
xh = x * hann
N_FFT = 8192
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag_python = np.abs(X) / N * 2
freqs = np.arange(len(X)) * 4e6 / N_FFT

# ILA first cycle mag
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
            if valid == 1 and buf < 6144:
                if bin_idx not in first_cycle:
                    first_cycle[bin_idx] = mag
        except: continue

# Sort by ILA bin (sorted by ila_bin which is (real_bin + 200) mod 2048)
sorted_bins = sorted(first_cycle.keys())

print("对比: Python FFT bin (real) vs ILA bin (mod 2048)")
print(f"\nPython FFT mag peak: bin={np.argmax(mag_python[1:])+1}, freq={(np.argmax(mag_python[1:])+1)*4e6/N_FFT/1000:.2f} kHz, mag={mag_python[np.argmax(mag_python[1:])+1]:.4f}")
print(f"Python FFT ADC P2P: {adc.max()-adc.min()} LSB")
print(f"Per LSB voltage: {5000/2048} mV (ADC ±5V)")
print()
print(f"ILA first cycle max mag: bin={max(first_cycle, key=first_cycle.get)}, mag={max(first_cycle.values())}")
print()

# Look for the same peak in Python
print("Python FFT around bin 410 (200 kHz):")
for b in range(395, 420):
    print(f"  bin={b}, freq={freqs[b]/1000:.2f} kHz, mag={mag_python[b]:.4f} mV")

# Convert ILA mag back to "Python FFT mag equivalent"
# CORDIC mag = |X[k]| (single-sided), same units as Python abs(X)
# But CORDIC is 16-bit, so mag_CORDIC may be scaled
# Python mag_N = abs(X)/N*2 = peak amplitude
# CORDIC: 16-bit |X[k]|, max 65535
# ILA shows first_cycle[351] = 24146
# Python mag_Python[151] = ?
real_bin_351 = 351 - 200  # 151
print(f"\nFor ILA bin 351, real_bin = {real_bin_351}")
print(f"Python FFT mag at bin {real_bin_351}: {mag_python[real_bin_351]:.4f} mV")
print(f"Python FFT mag at bin 210 (Python found this): {mag_python[210]:.4f} mV")

# Plot ILA mag in Python's bin scale (real_bin = ILA_bin - 200)
print(f"\n=== ILA 看到的频谱 (转 real_bin) ===")
# Find all peaks in ILA: local max with mag > 1000
for b in sorted_bins[:10]:
    print(f"  real_bin={b-200}, freq={(b-200)*488.281/1000:.2f} kHz, ILA mag={first_cycle[b]}")

# Try: real_freq_N = ?
# 0.2 mV expectation at 200 kHz if Vpp = 100 mV at ADC, w/ 5x attenuation = ADC Vpp 20 mV
# So mag_python ~ Vpp / (some factor)

# Strong hypothesis: signal at ILA bin 410 (=210 real_bin) ~ 102 kHz
# = ~ 100 kHz component
# ILA shows 410 in second cycle (real_bin = 410 - 200 = 210)
print(f"\nILA bin 410 mag: {first_cycle.get(410, 'NOT IN FIRST CYCLE')}")
# But bin 410 > 2047! 410 is in range, OK
# wait, ILA BRAM is 11-bit (max 2047). bin 410 is in range

print(f"\nAll 'real_bin' that might be signal:")
# Search for max ILA mag
for b in sorted(first_cycle.keys(), key=lambda x: -first_cycle[x])[:20]:
    real_b = b - 200
    if real_b < 0: real_b += 2048  # wraparound
    freq = real_b * 488.281
    print(f"  ILA bin={b:4d} (real_bin if no wrap: {real_b}, freq {freq/1000:.2f} kHz), mag={first_cycle[b]}")