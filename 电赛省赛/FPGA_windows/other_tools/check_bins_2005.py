#!/usr/bin/env python3
"""看 iladata_mux1.csv 里 bin > 1024 的所有数据 (11-bit 上半段)"""
import csv
from collections import defaultdict
fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

# 全部 sample 的 (bin, mag), 按 valid=1 过滤
data = []
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            bin_idx = int(row[4])
            mag = int(row[3])
            valid = int(row[5], 16)
            data.append((bin_idx, mag, valid))
        except: continue

# bin 分布
bin_counter = defaultdict(int)
for b, m, v in data:
    if v == 1:
        bin_counter[b] += 1

print(f"Total bin range: {min(bin_counter.keys())} .. {max(bin_counter.keys())}")
print(f"Number of unique bins with valid=1: {len(bin_counter)}")
print(f"Unique bins: {sorted(bin_counter.keys())[:20]}...{sorted(bin_counter.keys())[-20:]}")

# 找 bin=2005 附近的样本
print(f"\nAll bin values (sorted): {sorted(bin_counter.keys())}")

# max bin
max_bin = max(bin_counter.keys())
print(f"\nMax bin: {max_bin} (count: {bin_counter[max_bin]})")
print(f"Min bin: {min(bin_counter.keys())} (count: {bin_counter[min(bin_counter.keys())]})")

# 找 2005 附近
near_2005 = [b for b in bin_counter.keys() if abs(b - 2005) < 50]
print(f"\nBins near 2005: {sorted(near_2005)}")