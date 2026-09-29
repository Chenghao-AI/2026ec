#!/usr/bin/env python3
"""检查 ADC 原始值的范围和分布"""
import csv
fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

adc_vals = []
adc_raw = []
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            valid = int(row[5], 16)
            a_hex = row[6]
            a = int(a_hex, 16)
            if valid == 1:
                adc_raw.append(a)
                # signed conversion
                if a > 2047: a -= 4096
                adc_vals.append(a)
        except: continue

print(f"Total valid samples: {len(adc_vals)}")
print(f"Raw hex range: 0x{min(adc_raw):03X} .. 0x{max(adc_raw):03X}")
print(f"Signed range: {min(adc_vals)} .. {max(adc_vals)}")
print(f"P2P (signed): {max(adc_vals)-min(adc_vals)}")
print(f"Distribution: <0: {sum(1 for a in adc_vals if a<0)}, >0: {sum(1 for a in adc_vals if a>0)}, ==0: {sum(1 for a in adc_vals if a==0)}")

# 看几个具体值
print(f"\nFirst 10 ADC (raw hex, signed): ")
for i in range(10):
    print(f"  {adc_raw[i]:03X} = {adc_vals[i]}")

# 找 wrap-around (相邻差 > 2048)
print("\nLooking for wrap-arounds (diff > 2048):")
for i in range(1, len(adc_vals)):
    d = adc_vals[i] - adc_vals[i-1]
    if abs(d) > 2048:
        print(f"  idx {i}: {adc_vals[i-1]} -> {adc_vals[i]} (diff {d})")
        if i > 10: break

# 用 cumulative sum 看时域波形
import statistics
print(f"\nMean: {statistics.mean(adc_vals):.2f}")
print(f"Stdev: {statistics.stdev(adc_vals):.2f}")