#!/usr/bin/env python3
"""详细查找 16 kHz 附近峰"""
import csv
import numpy as np
fp = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata2.csv"

adc_vals = []
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            valid = int(row[5], 16)
            a = int(row[6], 16)
            if valid == 1:
                if a > 2047: a -= 4096
                adc_vals.append(a)
        except: continue

adc = np.array(adc_vals, dtype=np.float64)
N = len(adc)
x = adc - adc.mean()
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
xh = x * hann
N_FFT = 8192
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag = np.abs(X) / N * 2
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 16 kHz 附近 (bin 33) 详细
print("Near 16 kHz (bin 30..40):")
for b in range(28, 42):
    print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} mV")

# 找 80 kHz 附近 (bin 164)
print("\nNear 80 kHz (bin 160..170):")
for b in range(160, 172):
    print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} mV")

# 5 点抛物线拟合 16 kHz
def parabola_fit(mag_arr, center_bin):
    half = 2
    br = np.arange(center_bin-half, center_bin+half+1)
    m = mag_arr[br]
    c2 = np.polyfit(br, m, 2)
    bin_fine = -c2[1] / (2*c2[0])
    mag_fine = np.polyval(c2, bin_fine)
    return bin_fine, mag_fine

# 16 kHz 峰在 bin 33 附近最大
# Find local max around bin 33
local_region = mag[28:42]
local_peak = np.argmax(local_region) + 28
print(f"\n16 kHz local peak: bin={local_peak}")
bin_fine_16, mag_fine_16 = parabola_fit(mag, local_peak)
print(f"  Fine fit: bin={bin_fine_16:.3f}, freq={bin_fine_16*488.281:.1f} Hz, mag={mag_fine_16:.4f} mV")

# 80 kHz
bin_fine_80, mag_fine_80 = parabola_fit(mag, 164)
print(f"80 kHz fine fit: bin={bin_fine_80:.3f}, freq={bin_fine_80*488.281:.1f} Hz, mag={mag_fine_80:.4f} mV")

# 估算 Vpp
# mag (single-bin) 是 peak amplitude (Hann-未补偿), Vpp = mag * 2 (Hann comp)
# 但实际 |X|/N * 2 = peak amplitude (单边谱), Vpp = peak * 2
# 所以 Vpp = mag (already done above) * 2 实际我用的 mag 已经 = peak amplitude
# Vpp = peak * 2 = mag * 2 (因为 mag = peak)

# 测得 Vpp
vpp_16 = mag_fine_16 * 2  # Hann comp
vpp_80 = mag_fine_80 * 2
print(f"\nMeasured Vpp: 16 kHz = {vpp_16:.3f} mV, 80 kHz = {vpp_80:.3f} mV")
print(f"Expected Vpp: 16 kHz = ~8.33 mV, 80 kHz = ~41.67 mV")
print(f"Diff: 16 kHz = {vpp_16-8.33:+.3f} mV, 80 kHz = {vpp_80-41.67:+.3f} mV")

# CORDIC 测得的 mag
# CORDIC 输出 mag = sqrt(I^2+Q^2), CORDIC 11-bit output, 单边谱
# mag_fine_16 = 0.32, mag_fine_80 = 4.37
# 比值 4.37/0.32 = 13.7 (期望 5x)
# 这是因为 CORDIC 是 sqrt 形式, MATLAB 用 /N 单边, 比例不同