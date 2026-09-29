#!/usr/bin/env python3
"""详细看 40kHz (bin 81) 附近和 100kHz (bin 205) 附近"""
import csv
import numpy as np

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
mag = np.abs(X) / N * 2
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 40 kHz (bin ~82) 附近
print(f"Near 40 kHz (bin 78..90):")
for b in range(78, 91):
    print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} mV")
print(f"\nNear 100 kHz (bin 200..215):")
for b in range(200, 216):
    print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} mV")

# 找所有峰
def find_peaks(m, threshold=0.5):
    peaks = []
    for i in range(2, len(m)-2):
        if m[i] > threshold and m[i] >= m[i-1] and m[i] >= m[i+1] and m[i] >= m[i-2] and m[i] >= m[i+2]:
            peaks.append((i, m[i]))
    return peaks

peaks_all = find_peaks(mag, threshold=0.5)
print(f"\nAll peaks > 0.5 mV:")
for b, m in sorted(peaks_all, key=lambda x: -x[1])[:15]:
    print(f"  bin={b:4d}, freq={freqs[b]/1000:7.2f} kHz, mag={m:7.4f} mV")

# Highest peak
max_bin = np.argmax(mag[1:]) + 1
print(f"\nMax peak: bin={max_bin}, freq={freqs[max_bin]/1000:.2f} kHz, mag={mag[max_bin]:.4f} mV")