#!/usr/bin/env python3
"""详细分析 CORDIC 输出: 对每个 bin, 看 valid=1 时该 bin 的 mag 平均/最大值"""
import csv
from collections import defaultdict
fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

# 收集 (bin, mag) 仅 valid=1
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

# 按 mag 排序前 30
top = sorted(bin_max.items(), key=lambda x: -x[1])[:30]
print("Top 30 bins (max mag at valid=1):")
for b, m in sorted(top, key=lambda x: x[0]):  # 按 bin 排序显示
    # 假设 verilog bin_in = bin + 200 偏置, 真实 bin = bin - 200
    real_bin = b - 200
    freq_if_real = real_bin * 4e6 / 8192 if real_bin >= 0 else None
    freq_direct = b * 4e6 / 8192
    print(f"  bin={b:4d} (real_bin={real_bin:5d})  mag={m:6d}  freq_if_real={freq_if_real}  freq_direct={freq_direct/1000:.2f} kHz")