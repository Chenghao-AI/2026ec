#!/usr/bin/env python3
"""模拟 verilog FFT (N=8192, zero-pad 后 8192 点)"""
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
N = len(adc)
x = adc - adc.mean()

# Hann 窗
n_idx = np.arange(N)
hann = 0.5 * (1 - np.cos(2 * np.pi * n_idx / (N - 1)))
xh = x * hann

# Zero-pad 到 N_FFT = 8192 (模拟 verilog)
N_FFT = 8192
xp = np.zeros(N_FFT)
xp[:N] = xh

X = np.fft.rfft(xp)
mag = np.abs(X) / N  # 用 N (不是 N_FFT) 归一化 (与之前公式一致)
mag_v2 = np.abs(X) / N_FFT  # 用 N_FFT 归一化
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 peak
top = np.argsort(mag[1:])[::-1][:5] + 1
print(f"FFT N=8192 (zero-pad 4096 sample):")
print(f"Δf = {4e6/N_FFT:.3f} Hz/bin")
print(f"\nTop 5 peaks (mag = |X|/N, N=4096):")
for t in top:
    print(f"  bin={t:4d}, freq={freqs[t]/1000:.3f} kHz, mag_N={mag[t]:.3f} mV, mag_NFFT={mag_v2[t]:.3f} mV")

# Compute "mag with /N*2" formula:
# mag_calibrated = mag_N * 2 * 2 / LINK_GAIN  (×2 for single-sided, ×2 for Hann comp, /LINK_GAIN for source)
LINK_GAIN = 1.22
print(f"\n--- 幅度对比 (LinkGain=1.22) ---")
print(f"  expected Vpp_10k = 9.77 mV (= 2 LSB peak * 2)")
print(f"  expected Vpp_180k = 29.30 mV (= 6 LSB peak * 2)")
for t in top:
    m_n = mag[t]
    m_hann_comp = m_n * 2  # Vpp (Hann-补偿后)
    m_cal = m_hann_comp / LINK_GAIN
    print(f"  bin={t}, freq={freqs[t]/1000:.2f} kHz: |X|/N={m_n:.3f}, Vpp(after Hann)={m_hann_comp:.3f}, cal={m_cal:.3f} mV")