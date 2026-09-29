#!/usr/bin/env python3
"""详细分析: buffer idx 与 valid=1 的对应关系"""
import csv
fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

# 按 buffer 索引排列的 valid 标志
buf_to_valid = {}
buf_to_mag = {}
buf_to_bin = {}
buf_to_adc = {}
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            buf = int(row[0])
            mag = int(row[3])
            b = int(row[4])
            v = int(row[5], 16)
            a = int(row[6], 16)
        except: continue
        buf_to_valid[buf] = v
        buf_to_mag[buf] = mag
        buf_to_bin[buf] = b
        buf_to_adc[buf] = a

# 找 valid=1 的连续段
buf_sorted = sorted(buf_to_valid.keys())
valid_runs = []
cur_run = []
for b in buf_sorted:
    if buf_to_valid[b] == 1:
        if not cur_run or b == cur_run[-1] + 1:
            cur_run.append(b)
        else:
            valid_runs.append(cur_run)
            cur_run = [b]
    else:
        if cur_run:
            valid_runs.append(cur_run)
            cur_run = []
if cur_run:
    valid_runs.append(cur_run)

print(f"Total buffer indices: {len(buf_sorted)}")
print(f"Number of valid=1 runs: {len(valid_runs)}")
print("Runs:")
for i, r in enumerate(valid_runs):
    print(f"  Run {i}: buf {r[0]}..{r[-1]} ({len(r)} samples)")
    # 显示 run 中前 5 个 mag
    sample_mags = [buf_to_mag[b] for b in r[:5]]
    sample_bins = [buf_to_bin[b] for b in r[:5]]
    print(f"    first 5 mags: {sample_mags}")
    print(f"    first 5 bins: {sample_bins}")

# 对每个 run 的 mag 取 max
print("\nMax mag per run (top 10):")
all_runs_mag = []
for r in valid_runs:
    max_m = max(buf_to_mag[b] for b in r)
    all_runs_mag.append((max_m, r[0], r[-1]))
all_runs_mag.sort(reverse=True)
for m, s, e in all_runs_mag[:10]:
    print(f"  buf {s}..{e}: max_mag = {m}")