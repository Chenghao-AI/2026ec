#!/usr/bin/env python3
"""计算目标 40kHz/100kHz 在 ILA bin 哪里 - 验证信号"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

# 1) 验证 iladata.csv 对应的信号
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
print(f"N = {N} samples")
print(f"ADC P2P = {adc.max()-adc.min()} LSB ({(adc.max()-adc.min())*5000/2048:.1f} mV)")

# 用户说: 40k + 100k, 7:1, 总 Vpp 200 mV
# A1 + A2 = 100 mV peak (200 mV Vpp)
# A1/A2 = 7 -> A1 = 87.5 mV peak (175 mV Vpp), A2 = 12.5 mV peak (25 mV Vpp)
# 链路衰减 5x: ADC 实测 = A1/5, A2/5 = 17.5 mV Vpp, 2.5 mV Vpp

# FFT (zero-pad 8192)
x = adc - adc.mean()
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
xh = x * hann
N_FFT = 8192
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag = np.abs(X) / N * 2
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 40 kHz (bin 81.9)
print(f"\n40 kHz expected bin: {40000/(4e6/8192):.1f}")
print(f"100 kHz expected bin: {100000/(4e6/8192):.1f}")

# Top 10 FFT peaks
top = np.argsort(mag[1:])[::-1][:10] + 1
print(f"\nTop 10 FFT peaks (Python simulation):")
for t in sorted(top):
    print(f"  bin={t:4d}, freq={freqs[t]/1000:7.3f} kHz, mag={mag[t]:7.4f} mV")

# ILA bin (verilog +200 偏置)
print(f"\n=== ILA bin 视角 (verilog +200 偏置) ===")
# 找对应 ILA bin
for t in sorted(top):
    ila_bin = t + 200
    print(f"  ILA bin {ila_bin} <- real_bin {t}, freq {freqs[t]/1000:.2f} kHz, mag={mag[t]:.4f} mV")

# 取 first cycle (buf 4096..6143) 的 mag (实际 ILA 实时显示的值)
bin_first_mag = {}
valid_rows = []
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
            valid_rows.append((buf, bin_idx, mag, valid))
        except: continue

# first cycle: 取 buf < 6144 的 (即第一三角坡)
for buf, b, m, v in valid_rows:
    if v == 1 and buf < 6144:
        # first cycle
        if b not in bin_first_mag:
            bin_first_mag[b] = m

# 打印 ILA 第一三角坡中, 40kHz 和 100kHz 附近的实际 ILA 看到的 mag (raw mag from CORDIC)
print(f"\n=== ILA 第一三角坡在目标频率附近的实际 mag ===")
# target bins
target_ila_bins = [200 + int(round(40000/(4e6/8192))), 200 + int(round(100000/(4e6/8192)))]
for tb in target_ila_bins:
    print(f"Target ILA bin {tb}: mag = {bin_first_mag.get(tb, 'N/A')}")

# 找 ILA 第一三角坡实际峰值
top_ila = sorted([(m, b) for b, m in bin_first_mag.items()], reverse=True)[:10]
print(f"\nTop 10 peaks in first cycle (ILA 实际看到的):")
for m, b in sorted(top_ila, key=lambda x: x[1]):
    real_bin = b - 200
    freq = real_bin * 4e6 / 8192 if real_bin > 0 else 0
    print(f"  ILA bin={b:4d} (real_bin={real_bin:4d}), mag={m:5d}, freq={freq/1000:.2f} kHz")