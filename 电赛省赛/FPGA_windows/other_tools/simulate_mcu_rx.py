#!/usr/bin/env python3
"""生成单片机视角下的传输数据模拟"""
import csv
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

# 收集 first cycle (buf 4096..6143 即第一三角坡) 的 (bin, mag)
first_cycle = {}
second_cycle = {}
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
            if valid == 1:
                if buf < 6144:
                    if bin_idx not in first_cycle:
                        first_cycle[bin_idx] = mag
                else:
                    if bin_idx not in second_cycle:
                        second_cycle[bin_idx] = mag
        except: continue

print(f"First cycle (first 三角坡): bins = {len(first_cycle)}")
print(f"Second cycle (second 三角坡): bins = {len(second_cycle)}")

# Print first cycle mag profile (按 bin 排序)
print(f"\n=== First cycle 完整 mag 序列 (bin 0..2047) ===")
print(f"形式: ILA_bin=XXX, mag=YYYY  (注意: 这是 ILA bin, 不是真实 FFT bin)")
print(f" 真实 FFT bin = ILA_bin - 200")
print(f" 频率 = 真实_bin * 488.281 Hz/bin")
print()

# 显示所有 2048 个 bin 的 mag (紧凑格式)
sorted_bins = sorted(first_cycle.keys())
print(f"bin range: {min(sorted_bins)} .. {max(sorted_bins)}")
print(f"Sample (前 20 bin):")
for b in sorted_bins[:20]:
    print(f"  bin={b}, mag={first_cycle[b]}")
print(f"...")
print(f"\n最大 mag 位置:")
max_bin = max(first_cycle, key=first_cycle.get)
print(f"  ILA bin={max_bin}, mag={first_cycle[max_bin]}")
print(f"  真实 bin = {max_bin - 200}")
print(f"  频率 = {(max_bin-200) * 488.281:.1f} Hz = {(max_bin-200) * 488.281 / 1000:.2f} kHz")

# Print distinct bins where mag > 1000 (significant values)
print(f"\n=== ILA bin where mag > 1000 (第一三角坡) ===")
sig = [(b, m) for b, m in first_cycle.items() if m > 1000]
for b, m in sorted(sig, key=lambda x: x[0]):
    real_b = b - 200
    freq = real_b * 488.281
    print(f"  ILA bin={b:4d} (real_bin={real_b:4d}), mag={m:5d}, freq={freq/1000:7.2f} kHz")

# Verify: each bin in 1st cycle has only 1 mag value (first occurrence)
occs = defaultdict(int)
for buf, b, m, v in []:
    pass
import csv as c2
with open(fp) as f:
    reader = c2.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            buf = int(row[0])
            bin_idx = int(row[4])
            valid = int(row[5], 16)
            if valid == 1 and buf < 6144:
                occs[bin_idx] += 1
        except: continue
max_occ = max(occs.values())
print(f"\n每个 bin 在第一三角坡出现次数: max={max_occ}")
print(f"  -> 1次 = ILA BRAM 只记录 1 个值 (传 1 次)")