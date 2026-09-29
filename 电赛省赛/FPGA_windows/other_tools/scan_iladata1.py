#!/usr/bin/env python3
"""快速扫描 iladata1.csv (40+100kHz 7:1, Vpp 200mV)"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\iladata1.csv"

# 行数 + 表头
with open(fp) as f:
    lines = f.readlines()
print(f"Total lines: {len(lines)}")
print(f"Header: {lines[0].strip()}")
print(f"Radix:  {lines[1].strip()}")
print(f"First data: {lines[2].strip()}")
print(f"Last data:  {lines[-1].strip()}")

# 读 valid=1, ADC raw
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
        except: continue
        if valid == 1:
            adc_raw = a  # 保留 raw
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
mag = np.abs(X) / N * 2  # 单边谱 peak amplitude
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 40 kHz (bin ~82) 和 100 kHz (bin ~205)
print(f"\nNear 40 kHz (bin 78..90):")
for b in range(78, 91):
    if mag[b] > 0.01:
        print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} mV")

print(f"\nNear 100 kHz (bin 200..215):")
for b in range(200, 216):
    if mag[b] > 0.01:
        print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} mV")

# 5 点抛物线拟合
def parabola_fit(mag_arr, center_bin):
    half = 2
    br = np.arange(center_bin-half, center_bin+half+1)
    m = mag_arr[br]
    c2 = np.polyfit(br, m, 2)
    bin_fine = -c2[1] / (2*c2[0])
    mag_fine = np.polyval(c2, bin_fine)
    return bin_fine, mag_fine

# 40 kHz
local_region = mag[78:91]
local_peak = np.argmax(local_region) + 78
bin_fine_40, mag_fine_40 = parabola_fit(mag, local_peak)
print(f"\n40 kHz: bin={local_peak} -> fine bin={bin_fine_40:.3f}, freq={bin_fine_40*488.281:.1f} Hz, mag={mag_fine_40:.4f} mV")

# 100 kHz
local_region = mag[200:215]
local_peak = np.argmax(local_region) + 200
bin_fine_100, mag_fine_100 = parabola_fit(mag, local_peak)
print(f"100 kHz: bin={local_peak} -> fine bin={bin_fine_100:.3f}, freq={bin_fine_100*488.281:.1f} Hz, mag={mag_fine_100:.4f} mV")

# CORDIC mag top
bin_max = {b: max(m) for b, m in bin_mags.items()}
cordic_top = sorted(bin_max.items(), key=lambda x: -x[1])[:8]
print(f"\nCORDIC mag top 8 (ILA bin):")
for b, m in cordic_top:
    real_bin = b - 200
    freq = real_bin * 4e6 / N_FFT if real_bin > 0 else 0
    print(f"  ILA bin={b}, real_bin={real_bin}, freq={freq/1000:.3f} kHz, mag={m}")

# 信号预期
print(f"\nExpected: 40 kHz -> bin = {40000/(4e6/N_FFT):.1f}, ILA bin = {int(40000/(4e6/N_FFT))+200}")
print(f"Expected: 100 kHz -> bin = {100000/(4e6/N_FFT):.1f}, ILA bin = {int(100000/(4e6/N_FFT))+200}")
print(f"\nExpected Vpp: 200 mV total (ratio 7:1)")
print(f"  A1 + A2 = peak total = 100 mV -> A1=87.5 mV peak (175 mV Vpp), A2=12.5 mV peak (25 mV Vpp)")
print(f"  40 kHz Vpp = 175 mV, 100 kHz Vpp = 25 mV")

# 测得 Vpp (×2 for Hann comp)
vpp_40 = mag_fine_40 * 2
vpp_100 = mag_fine_100 * 2
print(f"\nMeasured Vpp (Python ADC FFT, *2 Hann comp): 40 kHz = {vpp_40:.3f} mV, 100 kHz = {vpp_100:.3f} mV")
print(f"Ratio: {vpp_40/vpp_100:.3f} (expected 7.0)")