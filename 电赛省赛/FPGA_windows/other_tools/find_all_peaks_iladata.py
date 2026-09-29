#!/usr/bin/env python3
"""找 iladata.csv 里所有强峰"""
import csv
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv"

# first cycle mag dict
bin_first_mag = {}
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
            valid_rows.append((buf, bin_idx, mag, valid))
        except: continue

for buf, b, m, v in valid_rows:
    if v == 1 and buf < 6144:
        if b not in bin_first_mag:
            bin_first_mag[b] = m

# find all peaks: local max with mag > some threshold
def find_peaks(mags, threshold=500):
    peaks = []
    for i in range(1, len(mags) - 1):
        if mags[i] > threshold and mags[i] >= mags[i-1] and mags[i] >= mags[i+1]:
            peaks.append((i, mags[i]))
    return peaks

bin_list = sorted(bin_first_mag.keys())
mag_arr = [bin_first_mag[b] for b in bin_list]

# Sort by mag, find top regions
# Top peak: bin 351, mag=24146
# But there should be multiple peaks if signal has multiple tones

# Use 5-point running max
peaks = find_peaks(mag_arr, threshold=1000)
print(f"Peaks > 1000 in first cycle: {len(peaks)}")
for i, m in sorted(peaks, key=lambda x: -x[1])[:15]:
    real_bin = i - 200
    freq = real_bin * 4e6 / 8192 if real_bin > 0 else 0
    print(f"  ILA bin={i:4d} (real_bin={real_bin:4d}), mag={m:5d}, freq={freq/1000:.2f} kHz")

# All bins > 5000
print(f"\nAll bins with mag > 5000 (first cycle):")
high_bins = [(b, mag_first_mag) for b in mag_arr if mag_first_mag > 5000]  # wait this is wrong
# re-iterate
high_bins = [(b, m) for b, m in bin_first_mag.items() if m > 5000]
for b, m in sorted(high_bins, key=lambda x: x[0]):
    real_bin = b - 200
    freq = real_bin * 4e6 / 8192 if real_bin > 0 else 0
    print(f"  ILA bin={b:4d} (real_bin={real_bin:4d}), mag={m:5d}, freq={freq/1000:.2f} kHz")