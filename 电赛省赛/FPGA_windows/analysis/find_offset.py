import numpy as np
import csv

# Read ADC CSV
adc = []
with open(r'C:\Users\24307\Desktop\FPGA_windows\adc_timeseries.csv') as f:
    next(f)  # header
    for ln in f:
        parts = ln.strip().split(',')
        if len(parts) >= 2:
            adc.append(int(parts[1]))

adc = np.array(adc, dtype=np.float64)
N = 8192
n = np.arange(N)
w = 0.5 * (1 - np.cos(2*np.pi*n/N))
x_w = adc * w

# Compute FFT (scaled matches FPGA)
X = np.fft.fft(x_w)
mag_sim = np.abs(X[:N//2])
freqs = np.arange(N//2) * 4e6 / N

# Read CORDIC output
bin_dict = {}
with open(r'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv') as f:
    next(f); next(f)  # skip header, radix
    for ln in f:
        parts = ln.strip().split(',')
        if len(parts) < 7:
            continue
        try:
            mag = int(parts[3])
            bin_val = int(parts[4])
            valid = int(parts[5], 16)
        except:
            continue
        if valid == 0 or mag == 0:
            continue
        if bin_val not in bin_dict or mag > bin_dict[bin_val]:
            bin_dict[bin_val] = mag

# Sort by bin
bins_sorted = sorted(bin_dict.keys())
mmax = np.array([bin_dict[b] for b in bins_sorted])

# Try offsets
print("Searching for optimal bin offset...")
best_score = -1e18
best_off = 0
for off in range(-200, 200):
    # CORDIC bin b maps to simulation bin b+off
    sim_bins = np.array(bins_sorted) + off
    valid = (sim_bins >= 0) & (sim_bins < N//2)
    if not np.any(valid):
        continue
    sb = sim_bins[valid]
    cm = mmax[valid]
    sm = mag_sim[sb]
    # Normalize
    cm_n = cm / cm.max() if cm.max() > 0 else cm
    sm_n = sm / sm.max() if sm.max() > 0 else sm
    score = np.sum(cm_n * sm_n)
    if score > best_score:
        best_score = score
        best_off = off

print(f"Best offset: {best_off} bins (score={best_score:.4f})")

# Show top 10 CORDIC bins after offset
print(f"\nAfter offset {best_off}:")
sorted_by_mag = sorted(range(len(bins_sorted)), key=lambda i: mmax[i], reverse=True)
for k in range(15):
    idx = sorted_by_mag[k]
    b = bins_sorted[idx]
    mapped = b + best_off
    if 0 <= mapped < N//2:
        print(f"  CORDIC bin {b} -> sim bin {mapped} ({mapped*4e6/N/1000:.3f} kHz): mag={mmax[idx]}, sim_mag={mag_sim[mapped]:.0f}")
