#!/usr/bin/env python3
"""画 iladata1.csv 的 MCU 视角频谱图"""
import csv
import numpy as np
import matplotlib.pyplot as plt
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\iladata1.csv"

# 读第一三角坡
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

ila_bins = np.array(sorted(first_cycle.keys()))
mags = np.array([first_cycle[b] for b in ila_bins])
real_bins = (ila_bins.astype(int) - 200) % 2048
freq_kHz = real_bins * 488.281 / 1000.0

# Filter 5-550 kHz
mask = (freq_kHz >= 5) & (freq_kHz <= 550)
f_bins = ila_bins[mask]
f_real = real_bins[mask]
f_freq = freq_kHz[mask]
f_mag = mags[mask]

fig, axes = plt.subplots(2, 1, figsize=(14, 8))

# 上图: 完整第一三角坡
ax = axes[0]
ax.plot(ila_bins, mags, 'b-', linewidth=0.6, label='ILA bin mag')
ax.set_xlabel('ILA bin (0..2047)')
ax.set_ylabel('Mag (CORDIC 16-bit)')
ax.set_title('Single-Chip-MCU View: First Triangle (2048 bins) - 40kHz+100kHz 7:1 signal')
ax.grid(True, alpha=0.3)
ax.axvspan(211, 1326, color='green', alpha=0.1, label='5-550 kHz valid range (bin 211~1326)')
# Mark peaks
top_idx = np.argsort(mags)[::-1][:5]
for ti in top_idx:
    real_b = real_bins[ti]
    f = freq_kHz[ti]
    ax.annotate(f'bin={ila_bins[ti]} (real={real_b}, {f:.1f} kHz)\nmag={mags[ti]}',
                xy=(ila_bins[ti], mags[ti]),
                xytext=(ila_bins[ti]+50, mags[ti]+1500),
                fontsize=8, ha='center', color='red',
                arrowprops=dict(arrowstyle='->', color='red', lw=0.5))
ax.legend(loc='upper right')

# 下图: 过滤后 (5-550 kHz)
ax = axes[1]
ax.bar(f_real, f_mag, width=1.0, color='green', alpha=0.7, label='Filtered mag (5-550 kHz)')
ax.set_xlabel('Real FFT bin (= ILA bin - 200)')
ax.set_ylabel('Mag (CORDIC 16-bit)')
ax.set_title(f'After 5-550 kHz Filter ({len(f_real)} bins: real_bin {f_real[0]}-{f_real[-1]}, freq {f_freq[0]:.1f}-{f_freq[-1]:.1f} kHz)')
ax.grid(True, alpha=0.3)

# Mark two expected signals
# 40 kHz at real bin 82
idx_40k = np.where(f_real == 82)[0][0]
ax.annotate(f'40 kHz\nILA bin=282\nmag={f_mag[idx_40k]}',
            xy=(82, f_mag[idx_40k]),
            xytext=(200, f_mag[idx_40k]*0.7),
            fontsize=10, color='red',
            arrowprops=dict(arrowstyle='->', color='red', lw=1.5))
# 100 kHz at real bin 204
idx_100k = np.where(f_real == 204)[0][0]
ax.annotate(f'100 kHz\nILA bin=404\nmag={f_mag[idx_100k]}',
            xy=(204, f_mag[idx_100k]),
            xytext=(350, f_mag[idx_100k]*0.7),
            fontsize=10, color='blue',
            arrowprops=dict(arrowstyle='->', color='blue', lw=1.5))
ax.legend(loc='upper right')

plt.tight_layout()
plt.savefig(r"C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure\mcu_spectrum_view_iladata1.png", dpi=100)
print(f"\n图已保存")
print(f"5-550 kHz 过滤后点数: {len(f_real)}")
print(f"40 kHz peak (real_bin=82): mag = {f_mag[idx_40k]}")
print(f"100 kHz peak (real_bin=204): mag = {f_mag[idx_100k]}")
print(f"Magnitude ratio: {f_mag[idx_40k] / f_mag[idx_100k]:.2f} (expected 7.0)")

# 换算 Vpp
ATTEN = 5.0
V_LSB = 5000.0/4096
N_HANN = 4096
vpp_40 = f_mag[idx_40k] * 1.0 / N_HANN * 2 * V_LSB * ATTEN
vpp_100 = f_mag[idx_100k] * 1.0 / N_HANN * 2 * V_LSB * ATTEN
print(f"\nVpp 换算 (单片机公式):")
print(f"  40 kHz: Vpp = {vpp_40:.2f} mV (expected 175 mV, dev {(vpp_40-175):.2f} mV)")
print(f"  100 kHz: Vpp = {vpp_100:.2f} mV (expected 25 mV, dev {(vpp_100-25):.2f} mV)")