#!/usr/bin/env python3
"""画 MCU 视角频谱图"""
import csv
import numpy as np
import matplotlib.pyplot as plt
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

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

# Filter 5-500 kHz
mask = (freq_kHz >= 5) & (freq_kHz <= 500)
f_bins = ila_bins[mask]
f_real = real_bins[mask]
f_freq = freq_kHz[mask]
f_mag = mags[mask]

fig, axes = plt.subplots(2, 1, figsize=(14, 8))

# 图 1: 完整第一三角坡 (bin 0..2047)
ax = axes[0]
ax.plot(ila_bins, mags, 'b-', linewidth=0.6, label='ILA bin mag')
ax.set_xlabel('ILA bin (0..2047)')
ax.set_ylabel('Mag (CORDIC)')
ax.set_title('Single-Chip-MCU View: First Triangle (2048 bins, No Filter)')
ax.grid(True, alpha=0.3)
ax.axvspan(211, 1224, color='green', alpha=0.1, label='5-500 kHz valid range (bin 211~1224)')
ax.legend(loc='upper right')
# Mark peaks
top_idx = np.argsort(mags)[::-1][:5]
for ti in top_idx:
    ax.annotate(f'bin={ila_bins[ti]}, mag={mags[ti]}',
                xy=(ila_bins[ti], mags[ti]),
                xytext=(ila_bins[ti], mags[ti]+2000),
                fontsize=8, ha='center',
                arrowprops=dict(arrowstyle='->', color='red', lw=0.5))

# 图 2: 过滤后 (5-500 kHz, 1014 个点)
ax = axes[1]
ax.bar(f_real, f_mag, width=1.0, color='green', alpha=0.7, label='Filtered mag (5-500 kHz)')
ax.set_xlabel('Real FFT bin (= ILA bin - 200)')
ax.set_ylabel('Mag (CORDIC)')
ax.set_title(f'After 5-500 kHz Filter (1014 bins: real_bin {f_real[0]}-{f_real[-1]}, freq {f_freq[0]:.1f}-{f_freq[-1]:.1f} kHz)')
ax.grid(True, alpha=0.3)
# Mark peak
peak_i = np.argmax(f_mag)
ax.annotate(f'Peak: bin={f_real[peak_i]}, mag={f_mag[peak_i]}',
            xy=(f_real[peak_i], f_mag[peak_i]),
            xytext=(f_real[peak_i]+50, f_mag[peak_i]*0.6),
            fontsize=10, color='red',
            arrowprops=dict(arrowstyle='->', color='red', lw=1.5))
ax.legend(loc='upper right')

plt.tight_layout()
plt.savefig(r"C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure\mcu_spectrum_view.png", dpi=100)
print(f"图已保存到 C:\\Users\\24307\\Desktop\\FPGA_windows\\matlab\\2026_G\\figure\\mcu_spectrum_view.png")
print(f"\n=== 关键统计 ===")
print(f"第一三角坡总 bin: 2048")
print(f"5-500 kHz 内 bin (real): {f_real[0]}-{f_real[-1]}")
print(f"5-500 kHz 内点数: {len(f_real)}")
print(f"5-500 kHz 内 max mag: {f_mag[peak_i]} at bin {f_real[peak_i]}")
print(f"5-500 kHz 内 peak 频率: {f_freq[peak_i]:.2f} kHz")