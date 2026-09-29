#!/usr/bin/env python3
"""完整列出所有 bin (mod 8192) 的 mag 分布"""
import csv
from collections import defaultdict
fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

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

# 取每个 bin 的 max mag
bin_max = {b: max(m) for b, m in bin_mags.items() if m}

# 按 mag 排序前 50
top = sorted(bin_max.items(), key=lambda x: -x[1])[:50]
print("Top 50 bins by max mag (valid=1):")
print(f"  {'bin':>4} | {'max_mag':>6} | {'freq@32768':>10} | {'freq - 200':>10} | {'freq mod':>10}")
for b, m in sorted(top, key=lambda x: x[0]):
    # 假设 FFT 是 32768 点
    freq32768 = b * 4e6 / 32768
    freq_sub200 = (b - 200) * 4e6 / 32768 if b >= 200 else 0
    print(f"  {b:4d} | {m:6d} | {freq32768:8.1f} Hz | {freq_sub200:8.1f} Hz")