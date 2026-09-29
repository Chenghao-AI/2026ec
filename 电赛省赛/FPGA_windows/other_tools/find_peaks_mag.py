#!/usr/bin/env python3
"""找 mag 峰值 bin (近似 CORDIC 输出)"""
import csv
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

# 收集 (bin -> [mag 列表])
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

# 对每个 bin 取 max mag
bin_max = {b: max(m) for b, m in bin_mags.items()}

# 按 mag 排序，找 top bins
top = sorted(bin_max.items(), key=lambda x: -x[1])[:30]
print("Top 30 bins by max mag (valid=1):")
print(f"  bin  | max_mag | freq_Hz (if N=8192, fs=4MHz)")
for b, m in top:
    freq = b * 4e6 / 8192
    print(f"  {b:4d} | {m:6d} | {freq:10.2f}")

# 找 mag > 1000 的所有 bin (明显是信号)
sig_bins = [(b, m) for b, m in bin_max.items() if m > 1000]
sig_bins.sort()
print(f"\nBins with mag > 1000: {len(sig_bins)} bins")
# 把连续的 bin 段分组
if sig_bins:
    groups = []
    cur = [sig_bins[0]]
    for b, m in sig_bins[1:]:
        if b - cur[-1][0] <= 3:
            cur.append((b, m))
        else:
            groups.append(cur)
            cur = [(b, m)]
    groups.append(cur)
    print(f"Number of peak groups: {len(groups)}")
    for g in groups:
        max_b = max(g, key=lambda x: x[1])
        freq = max_b[0] * 4e6 / 8192
        print(f"  Group: bins {g[0][0]}..{g[-1][0]}, max at bin={max_b[0]} mag={max_b[1]} freq={freq:.1f} Hz")