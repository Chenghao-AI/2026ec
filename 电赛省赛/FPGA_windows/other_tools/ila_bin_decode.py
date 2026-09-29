#!/usr/bin/env python3
"""精确映射: ILA bin = (real_bin + 200) mod 2048"""
import csv
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

# 收集 (ila_bin, mag)
bin_mags = defaultdict(list)
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            bin_idx = int(row[4])
            mag = int(row[3])
            valid = int(row[5], 16)
            if valid == 1:
                bin_mags[bin_idx].append(mag)
        except: continue

bin_max = {b: max(m) for b, m in bin_mags.items() if m}

# 按 max mag 排序 top 50
top = sorted(bin_max.items(), key=lambda x: -x[1])[:50]
print("Top 50 bins by max mag (ILA bin →  real_bin = (ila_bin - 200) mod 32768):")
print(f"  {'ILA_bin':>6} | {'real_bin':>7} | {'max_mag':>6} | {'freq@32768':>11} | {'freq@4096':>10}")
for b, m in sorted(top, key=lambda x: x[0]):
    # real bin = (ila_bin - 200) mod 32768
    real_bin = (b - 200) % 32768
    freq_32768 = real_bin * 4e6 / 32768
    # also try alternate decode
    print(f"  {b:6d} | {real_bin:7d} | {m:6d} | {freq_32768:8.1f} Hz")

# Expected bins
print(f"\nExpected: 10 kHz real bin = {10000/(4e6/32768):.1f}, ILA bin = {(int(10000/(4e6/32768)) + 200) % 2048}")
print(f"Expected: 180 kHz real bin = {180000/(4e6/32768):.1f}, ILA bin = {(int(180000/(4e6/32768)) + 200) % 2048}")