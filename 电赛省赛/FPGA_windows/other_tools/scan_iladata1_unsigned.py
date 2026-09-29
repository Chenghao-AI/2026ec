#!/usr/bin/env python3
"""正确解析 iladata1.csv - 考虑 ADC unsigned"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\iladata1.csv"

# 1) 文件头
with open(fp) as f:
    lines = f.readlines()
print(f"Total lines: {len(lines)}")
print(f"Header: {lines[0].strip()}")
print(f"Radix:  {lines[1].strip()}")
print(f"First data: {lines[2].strip()}")
print(f"Last data:  {lines[-1].strip()}")

# 2) Trigger & frame_end
trigger_pos = []
frame_end_pos = []
for i, line in enumerate(lines[2:], start=2):
    parts = line.strip().split(',')
    if len(parts) >= 8:
        if parts[2] == '1': trigger_pos.append(i)
        if parts[7] == '1': frame_end_pos.append(i)

print(f"\nTrigger positions: {trigger_pos}")
print(f"Frame_end positions: {frame_end_pos}")

# 3) 读 ADC raw (UNSIGNED 12-bit: 0..4095)
adc_raw = []
bin_mags = defaultdict(list)
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            valid = int(row[5], 16)
            a = int(row[6])  # UNSIGNED! 没有 16 进制说明
            mag = int(row[3])
            bin_idx = int(row[4])
        except: continue
        if valid == 1:
            adc_raw.append(a)
            bin_mags[bin_idx].append(mag)

adc = np.array(adc_raw, dtype=np.float64)
print(f"\nValid samples: {len(adc)}")
print(f"ADC range (UNSIGNED 12-bit): {adc.min():.0f}..{adc.max():.0f}")
print(f"ADC mean (DC): {adc.mean():.1f}")
print(f"ADC peak-to-peak: {adc.max()-adc.min():.0f} LSB")

# 在 UNSIGNED 模式下, ADC 值表示 0~4095 = 0~5V (单极性)
# Vpp = (max-min) * 5000/4096 mV
vpp_adc_mV = (adc.max()-adc.min()) * 5000.0/4096
print(f"ADC Vpp (UNSIGNED 12-bit, 0~5V scale): {vpp_adc_mV:.2f} mV")

# 减去 DC, 看作 signed around mean
adc_centered = adc - adc.mean()
print(f"ADC centered range: {adc_centered.min():.0f}..{adc_centered.max():.0f}, P2P={adc_centered.max()-adc_centered.min():.0f} LSB")

# 4) FFT (zero-pad 到 8192) - 用 centered ADC
N = len(adc)
x = adc_centered
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
xh = x * hann
N_FFT = 8192
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag = np.abs(X) / N * 2  # 单边谱 peak amplitude (UNSIGNED scale: per-LSB voltage = 5000/4096 mV)
freqs = np.arange(len(X)) * 4e6 / N_FFT

# mag (LSB units, not mV!) 还原到 LSB
# Actually if we want mV: (abs(X)/N * 2) * (5000/4096) per LSB
# But we used adc (already in LSB), so mag is in mV if we scale
# We scaled x = adc - mean (in LSB), so mag is in LSB units

mag_mV = mag * (5000.0/4096)
print(f"\nFFT bin 82 (40 kHz): mag = {mag[82]:.2f} LSB = {mag_mV[82]:.4f} mV")
print(f"FFT bin 205 (100 kHz): mag = {mag[205]:.2f} LSB = {mag_mV[205]:.4f} mV")

# 5) 找 40 kHz (bin ~82) 和 100 kHz (bin ~205)
print(f"\nNear 40 kHz (bin 78..90, in LSB units):")
for b in range(78, 91):
    if mag[b] > 0.1:
        print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} LSB")

print(f"\nNear 100 kHz (bin 200..215, in LSB units):")
for b in range(200, 216):
    if mag[b] > 0.1:
        print(f"  bin={b}, freq={freqs[b]/1000:.3f} kHz, mag={mag[b]:.4f} LSB")

# 6) 5 点抛物线拟合
def parabola_fit(mag_arr, center_bin):
    half = 2
    br = np.arange(center_bin-half, center_bin+half+1)
    m = mag_arr[br]
    c2 = np.polyfit(br, m, 2)
    bin_fine = -c2[1] / (2*c2[0])
    mag_fine = np.polyval(c2, bin_fine)
    return bin_fine, mag_fine

# 40 kHz
local_region = mag[78:91]
local_peak = np.argmax(local_region) + 78
bin_fine_40, mag_fine_40 = parabola_fit(mag, local_peak)
print(f"\n40 kHz fine: bin={bin_fine_40:.3f}, freq={bin_fine_40*488.281:.1f} Hz, mag={mag_fine_40:.4f} LSB")

# 100 kHz
local_region = mag[200:215]
local_peak = np.argmax(local_region) + 200
bin_fine_100, mag_fine_100 = parabola_fit(mag, local_peak)
print(f"100 kHz fine: bin={bin_fine_100:.3f}, freq={bin_fine_100*488.281:.1f} Hz, mag={mag_fine_100:.4f} LSB")

# 7) CORDIC mag (直接传给单片机的)
bin_max = {b: max(m) for b, m in bin_mags.items()}
print(f"\n=== CORDIC mag top 8 (直接传给单片机的值) ===")
for b, m in sorted(bin_max.items(), key=lambda x: -x[1])[:8]:
    real_bin = b - 200
    freq = real_bin * 4e6 / N_FFT if real_bin > 0 else 0
    print(f"  ILA bin={b}, real_bin={real_bin}, freq={freq/1000:.3f} kHz, mag={m}")

# 8) ILA 第一三角坡 (单片机视角)
first_cycle = {}
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    for row in reader:
        if len(row) < 7: continue
        try:
            buf = int(row[0])
            bin_idx = int(row[4])
            m = int(row[3])
            valid = int(row[5], 16)
            if valid == 1 and buf < 6144:
                if bin_idx not in first_cycle:
                    first_cycle[bin_idx] = m
        except: continue

print(f"\n=== 第一三角坡 (MCU 视角) ===")
print(f"Total bins: {len(first_cycle)}")

# 在 5-550 kHz 范围内
bins_filtered = [(b, m) for b, m in first_cycle.items()
                 if 11 <= (b-200) <= 1126]
print(f"5-550 kHz filter: {len(bins_filtered)} bins (real_bin 11..1126)")
print(f"  Start ILA bin: {bins_filtered[0][0]}")
print(f"  End   ILA bin: {bins_filtered[-1][0]}")

# Vpp 换算
# CORDIC mag 是 |X[k]| 单位 (LSB-Hann-未补偿)
# Hann coherent gain = 0.5
# peak amplitude (LSB) = 2 * mag / N_Hann
# N_Hann 是 Hann 窗有效长度, 对 N=4096 sample Hann: 接近 N=4096
# peak_amp (LSB) = 4 * mag / N
# Vpp (LSB) = 8 * mag / N
# Vpp_mV = Vpp (LSB) * V_per_LSB
# V_per_LSB (UNSIGNED 12-bit) = 5000/4096 = 1.221 mV/LSB
# 5x 衰减补偿: Vpp_source = Vpp_mV * 5

# 但更简单: 用 N_eff = 4096 (实际 sample 数, 非 zero-pad 后)
# CORDIC mag (peak) ≈ 2 * signal_amplitude_peak * N_eff
# signal_amp_peak = mag / (2 * N_eff)
# Vpp_signal = 2 * signal_amp_peak = mag / N_eff
# Vpp_mV = Vpp_signal * V_per_LSB
# Vpp_source = Vpp_mV * 5

N_eff = 4096  # 实际有效 sample 数, 不是 zero-pad 后的 N_FFT
V_per_LSB = 5000.0/4096  # UNSIGNED 12-bit, 0~5V 量程
ATTEN = 5.0  # AD9226 5x 衰减

# 取最大 mag 的 bin (40 kHz 期望)
m_40_cordic = max(m for b, m in first_cycle.items() if 280 <= b <= 285)
m_100_cordic = max(m for b, m in first_cycle.items() if 403 <= b <= 407)
print(f"\n=== 幅度换算 ===")
vpp_40 = (m_40_cordic / N_eff) * V_per_LSB * ATTEN
vpp_100 = (m_100_cordic / N_eff) * V_per_LSB * ATTEN
print(f"40 kHz ILA peak mag: {m_40_cordic}")
print(f"  Vpp = {m_40_cordic} / {N_eff} * {V_per_LSB} * {ATTEN} = {vpp_40:.3f} mV (expected 175 mV)")
print(f"100 kHz ILA peak mag: {m_100_cordic}")
print(f"  Vpp = {m_100_cordic} / {N_eff} * {V_per_LSB} * {ATTEN} = {vpp_100:.3f} mV (expected 25 mV)")
print(f"Ratio: {vpp_40/vpp_100:.3f} (expected 7.0)")