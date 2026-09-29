#!/usr/bin/env python3
"""详细分析 iladata.csv - 重点理解第一个三角坡的 bin/mag 结构"""
import csv
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

# 1) 文件总览
with open(fp) as f:
    lines = f.readlines()
print(f"=== 文件概览 ===")
print(f"总行数: {len(lines)}")
print(f"Header: {lines[0].strip()}")
print(f"Radix:  {lines[1].strip()}")
print(f"首行: {lines[2].strip()}")
print(f"末行: {lines[-1].strip()}")

# 2) 找 trigger 位置
trigger_pos = []
for i, line in enumerate(lines[2:], start=2):
    parts = line.strip().split(',')
    if len(parts) >= 3 and parts[2] == '1':
        trigger_pos.append(i)

print(f"\n=== Trigger 时序 ===")
print(f"Trigger 触发位置 (行号): {trigger_pos[:5]}{'...' if len(trigger_pos)>5 else ''}, 共 {len(trigger_pos)} 个")

# 3) 收集有效 bin, mag
bin_mags = defaultdict(list)
valid_rows = []
all_rows = []
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            bin_idx = int(row[4])
            mag = int(row[3])
            valid = int(row[5], 16)
            adc = int(row[6], 16)
            fe = int(row[7])
            buf = int(row[0])
            trig = int(row[2])
            all_rows.append((buf, bin_idx, mag, valid, adc, fe, trig))
            if valid == 1:
                bin_mags[bin_idx].append(mag)
                valid_rows.append((buf, bin_idx, mag, valid, adc, fe, trig))
        except: continue

print(f"\n=== Sample 统计 ===")
print(f"总 sample: {len(all_rows)}")
print(f"valid=1 sample: {len(valid_rows)}")
print(f"不同 valid bin 数: {len(bin_mags)}")
print(f"bin 范围: {min(bin_mags.keys())} .. {max(bin_mags.keys())}")

# 4) 取每个 bin 的 final (last) mag, 模拟 ILA 实时显示
bin_final = {}
for b, ms in bin_mags.items():
    bin_final[b] = ms[-1]   # final value when ILA pauses / triggered

# 5) 看 bin 时间序列 - 一个 bin 在不同 sample 上是什么
print(f"\n=== Bin 时序 (前 30 个 valid sample) ===")
print(f"  {'buf':>4} {'bin':>4} {'mag':>6} {'adc':>4} {'fe':>2} {'trig':>4}")
for buf, b, m, v, a, fe, tg in valid_rows[:30]:
    print(f"  {buf:4d} {b:4d} {m:6d} {a:4x} {fe:2d} {tg:4d}")

# 6) bin 分布 (each bin each occurrence)
print(f"\n=== Bin 出现次数 ===")
counts = {b: len(ms) for b, ms in bin_mags.items()}
print(f"每个 bin 出现次数: min={min(counts.values())}, max={max(counts.values())}")
# 找出现 1 次和多次的 bins
single_bins = [b for b, c in counts.items() if c == 1]
multi_bins = [b for b, c in counts.items() if c > 1]
print(f"出现 1 次的 bin 数: {len(single_bins)}")
print(f"出现多次的 bin 数: {len(multi_bins)}")

# 7) 找 frame_end 位置
fe_pos = [r[0] for r in all_rows if r[5] == 1]
print(f"\n=== frame_end 位置 ===")
print(f"frame_end 总数: {len(fe_pos)}")
if fe_pos:
    print(f"前 5 个 fe row: {fe_pos[:5]}")
    print(f"后 5 个 fe row: {fe_pos[-5:]}")

# 8) 找 valid=1 期间的最大 bin 和最小 bin
print(f"\n=== Valid期间 bin 范围 ===")
print(f"First valid row: buf={valid_rows[0][0]}, bin={valid_rows[0][1]}")
print(f"Last  valid row: buf={valid_rows[-1][0]}, bin={valid_rows[-1][1]}")

# 9) ADC 范围
adc_vals = [r[4] for r in valid_rows]
print(f"\n=== ADC (valid 期间) ===")
print(f"min={min(adc_vals):3x}, max={max(adc_vals):3x}, P2P={(max(adc_vals)-min(adc_vals)) if max(adc_vals)>=min(adc_vals) else (max(adc_vals)-min(adc_vals)+4096):#x}")

# 10) 找峰值 bin
bin_max = {b: max(ms) for b, ms in bin_mags.items()}
top10 = sorted(bin_max.items(), key=lambda x: -x[1])[:10]
print(f"\n=== Max mag top 10 (按 ILA 看到的最大幅度) ===")
for b, m in sorted(top10, key=lambda x: x[0]):
    real_bin = b - 200
    print(f"  ILA bin={b:4d} (real_bin={real_bin:4d}), mag={m:5d}, freq_N8192={real_bin*4e6/8192/1000:.2f} kHz")

# 11) "第一个三角坡" 的位置（用户截图）
# 截图显示 bin 大约从 200 上升到 ~2750, 然后 reset 回 200
# 这是 bin_cnt 单调递增的一帧（一帧 8192 bin）
# 三角坡结束位置 = frame_end 触发的位置

print(f"\n=== 第一个三角坡结构 ===")
# 用 first occurrence 找 bin 的时间序列
first_occs = sorted([(r[0], r[1]) for r in valid_rows])
# 看是否单调递增
diffs = [first_occs[i+1][1] - first_occs[i][1] for i in range(len(first_occs)-1)]
print(f"bin 序列 first-occurrence diff 前 30:")
for i in range(min(30, len(diffs))):
    print(f"  row {first_occs[i][0]}: bin {first_occs[i][1]} -> {first_occs[i+1][1]} (diff {diffs[i]})")