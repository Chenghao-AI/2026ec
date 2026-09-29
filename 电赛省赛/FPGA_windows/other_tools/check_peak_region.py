#!/usr/bin/env python3
"""检查 ILA 显示的 peak 是否来自第二三角坡错位"""
import csv
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

# Read all valid samples with buf
all_valid = []
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
                all_valid.append((buf, bin_idx, mag))
        except: continue

# Sort by buf
all_valid.sort(key=lambda x: x[0])
print(f"Total valid samples: {len(all_valid)}")

# Show around buf=4447 (where ILA said bin=351 had max mag)
print(f"\n=== Around buf=4447 (peak region) ===")
for buf, b, m in all_valid:
    if 4440 <= buf <= 4460:
        print(f"  buf={buf}, bin={b}, mag={m}")

# Maybe the data shows that around when bin_cnt = 351 (FFT bin 151 = 73.7 kHz), Mag shoots up
# Because of FFT chain issue: bins 348..352 are huge
# But Python FFT of same ADC data shows those bins are 0!

# Wait — this can only mean the FFT IN HARDWARE is producing different result
# Let's see what FFT bin 151 looks like in ILA data — perhaps a leakage from somewhere else?

# ILA first cycle mag sorted, then look at unique shape
first_cycle = {}
for buf, b, m in all_valid:
    if buf < 6144:
        if b not in first_cycle:
            first_cycle[b] = m

# All ILA mag (in first cycle)
print(f"\nFirst cycle, all bins:")
prev = 0
print("ILA bin: freq(real)        mag")
for b in sorted(first_cycle.keys()):
    real_b = b - 200
    print(f"  {b:4d}: freq={real_b*488.281/1000:7.2f} kHz  mag={first_cycle[b]:5d}")

# Wait, let me see if maybe what ILA displays is NOT the CORDIC mag of FFT bin cnt
# but some 8-bit scaled value or something

# print first 10 raw valid mag to understand
print(f"\nFirst 30 valid samples raw:")
for buf, b, m in all_valid[:30]:
    print(f"  buf={buf}, bin={b}, mag={m}")