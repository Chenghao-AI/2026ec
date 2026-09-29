#!/usr/bin/env python3
"""快速扫描混合信号 CSV: valid 样本数, bin 分布, ADC 范围"""
import csv
import sys
from collections import Counter

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_mux1.csv"

buf_list, mag_list, bin_list, valid_list, adc_list = [], [], [], [], []
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)  # skip header + radix
    for row in reader:
        if len(row) < 7: continue
        try:
            buf_list.append(int(row[0]))
            mag_list.append(int(row[3]))
            bin_list.append(int(row[4]))
            valid_list.append(int(row[5], 16))
            adc_list.append(int(row[6], 16))
        except: continue

n_valid = sum(1 for v in valid_list if v == 1)
print(f"Total rows : {len(buf_list)}")
print(f"valid=1    : {n_valid}")

# valid sample 的 ADC 范围
av = []
bv = []
bi = []
for i, v in enumerate(valid_list):
    if v == 1:
        a = adc_list[i]
        if a > 2047: a -= 4096
        av.append(a)
        bv.append(bin_list[i])
        bi.append(buf_list[i])
print(f"ADC range  : min={min(av)}, max={max(av)}, P2P={max(av)-min(av)} LSB")
print(f"ADC P2P    : {(max(av)-min(av)) * 5000/2048:.2f} mV @ ±5V FS")
print(f"Buffer range: {min(bi)} .. {max(bi)}")

# valid sample 的 bin 分布 (top 10 出现频率)
bin_counter = Counter(bv)
top_bins = bin_counter.most_common(15)
print(f"\nTop bins (valid=1, count >= 5):")
for b, c in top_bins:
    if c < 5: break
    print(f"  bin={b:4d}  count={c:4d}")

# ADC 峰值 (单 sample)
print(f"\nADC peak single: {max(abs(a) for a in av)} LSB = {max(abs(a) for a in av) * 5000/2048:.2f} mV")

# valid=1 样本里 mag 分布
mag_valid = [mag_list[i] for i, v in enumerate(valid_list) if v == 1]
if mag_valid:
    print(f"mag range (valid=1): min={min(mag_valid)}, max={max(mag_valid)}")