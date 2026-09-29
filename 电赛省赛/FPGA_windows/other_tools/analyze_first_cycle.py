#!/usr/bin/env python3
"""分析第一个三角坡的精确结构"""
import csv
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

# 收集 valid sample
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
            adc = int(row[6], 16)
            valid_rows.append((buf, bin_idx, mag, valid, adc))
        except: continue

valid_only = [r for r in valid_rows if r[3] == 1]
print(f"Total valid samples: {len(valid_only)}")

# bin 是顺序递增的: bin 0, 1, 2, ..., 2047 (有 wraparound 在 2047->0)
# 每个 bin 出现 2 次 (因为 ILA 触发后记录 2 个窗口)
# 验证: 每个 bin 出现 2 次
bin_counts = defaultdict(int)
for buf, b, m, v, a in valid_only:
    bin_counts[b] += 1

# 找哪段是 "first cycle" / "second cycle" / "wave" 形状
# 看每段的 buf 序列
buf_per_bin_0 = [r[0] for r in valid_only if r[1] == 0]
buf_per_bin_2047 = [r[0] for r in valid_only if r[1] == 2047]
buf_per_bin_2050 = [r[0] for r in valid_only if r[1] == 2050]  # 触发 wrap
print(f"bin=0 first occ buf: {buf_per_bin_0}")
print(f"bin=2047 first occ buf: {buf_per_bin_2047}")

# 找第一次 bin 重新回到 0 的位置 (第一三角坡结束)
prev_bin = 0
for i, (buf, b, m, v, a) in enumerate(valid_only):
    if b == 0 and prev_bin > 100:
        print(f"First cycle ends at buf={buf} (i={i}), bin=0, mag={m}")
        break
    prev_bin = b

# 找最后一次 buf=4095 之前的 "first cycle" 包含的 sample 数
# 找 first cycle 末 buf
prev_bin = 0
in_first = False
first_end_buf = None
for buf, b, m, v, a in valid_only:
    if b == 0:
        if prev_bin > 1000:
            first_end_buf = buf
            break
        in_first = True
    prev_bin = b
print(f"First cycle end buf: {first_end_buf}")

# 找 prev_buf 增加到 4096 时重新从 0 开始的位置
# 实际上, ILA trigger 在 row 4098 (前面算出)
# 触发后第一个 valid 在 row 4096 (buf=4096)
# bin 在这之后从 0 顺序增加

# 简单做法: 每个 bin 出现 2 次, 取 first occurrence 当 "first cycle"
bin_first = {}
for buf, b, m, v, a in valid_only:
    if b not in bin_first:
        bin_first[b] = (buf, m)

# Find the peak bins
bin_first_sorted = sorted(bin_first.items(), key=lambda x: x[0])
print(f"\n=== First cycle structure (bin -> first buf, first mag) ===")
print(f"Total first-occurrence bins: {len(bin_first_sorted)}")
print(f"Range: bin {bin_first_sorted[0][0]} .. bin {bin_first_sorted[-1][0]}")

# Min/max buf
bufs = [bf[1][0] for bf in bin_first_sorted]
mags = [bf[1][1] for bf in bin_first_sorted]
print(f"buf range: {min(bufs)} .. {max(bufs)}")
print(f"mag range: {min(mags)} .. {max(mags)}")

# 找最大 mag
max_mag_bin = max(bin_first_sorted, key=lambda x: x[1][1])
print(f"Max mag bin: {max_mag_bin[0]}, mag={max_mag_bin[1][1]}, buf={max_mag_bin[1][0]}")

# 整体前 30 bin mag plot
print(f"\n=== First cycle peak height (bin 0 -> 80) ===")
for b, (buf, m) in bin_first_sorted[:80]:
    print(f"  bin={b:4d}, mag={m:5d}")

# 找第二个 trig 是 wraparound 后开始 (从 bin=0)
# 找 cycle 2 (second occurrence) 的 bin=0..2047
bin_counts_count = defaultdict(int)
for buf, b, m, v, a in valid_only:
    bin_counts_count[b] += 1
print(f"\nMax count per bin: {max(bin_counts_count.values())}")
print(f"All bin counts: {set(bin_counts_count.values())}")

# 实际数据: 每个 bin 出现 2 次
# 因此 first cycle = 0~2047 (2048 bin), second cycle = 再 0~2047 (2048 bin)
# 总 4096 samples = 2 × 2048
# 用户想只传 first cycle = 2048 bin (< 10000)
print(f"\n*** First cycle 有 {len(bin_first_sorted)} bin (小于 8192 的 max 2047) ***")