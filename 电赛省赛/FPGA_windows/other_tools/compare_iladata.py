#!/usr/bin/env python3
"""比较 iladata.csv (用户说 40k/100k) vs iladata3.csv (我之前测试 40k/100k)"""
import csv
import numpy as np
from collections import defaultdict

for fp_name in ['iladata.csv', 'iladata3.csv']:
    print(f"\n========== {fp_name} ==========")
    fp = rf"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\{fp_name}"

    # 头尾
    with open(fp) as f:
        lines = f.readlines()
    print(f"Lines: {len(lines)}, first: {lines[2].strip()}, last: {lines[-1].strip()}")

    # ADC + FFT
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
    print(f"N={len(adc)} ADC, P2P={adc.max()-adc.min()} LSB ({(adc.max()-adc.min())*5000/2048:.1f} mV)")

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

    def find_peaks(m, thr):
        ps = []
        for i in range(2, len(m)-2):
            if m[i] > thr and m[i] >= m[i-1] and m[i] >= m[i+1] and m[i] >= m[i-2] and m[i] >= m[i+2]:
                ps.append((i, m[i]))
        return ps

    peaks = find_peaks(mag, 0.5)
    print(f"Top peaks (mag > 0.5):")
    for b, m in sorted(peaks, key=lambda x: -x[1])[:5]:
        print(f"  bin={b:4d}, freq={freqs[b]/1000:.2f} kHz, mag={m:.4f} mV")