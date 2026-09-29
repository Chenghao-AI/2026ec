#!/usr/bin/env python3
"""验证 CORDIC mag 和 Python mag 的换算关系"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\iladata1.csv"

# 读
adc_raw = []
bin_mags = defaultdict(list)
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
            adc = int(row[6])
            if valid == 1:
                adc_raw.append(adc)
                bin_mags[bin_idx].append(mag)
        except: continue

# ADC Python FFT
adc = np.array(adc_raw, dtype=np.float64)
adc_centered = adc - adc.mean()
N = len(adc_centered)
x = adc_centered
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
xh = x * hann
N_FFT = 8192
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag_py = np.abs(X) / N * 2  # LSB units (N=4096 actually, not N_FFT)
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 5 点抛物线拟合
def find_5pt(mag, center_bin):
    half = 2
    br = np.arange(center_bin-half, center_bin+half+1)
    m = mag[br]
    c2 = np.polyfit(br, m, 2)
    bin_fine = -c2[1] / (2*c2[0])
    mag_fine = np.polyval(c2, bin_fine)
    return bin_fine, mag_fine

# 40 kHz peak
local_region = mag_py[78:91]
local_peak = np.argmax(local_region) + 78
bin_fine_40, mag_fine_40 = find_5pt(mag_py, local_peak)
print(f"Python FFT at 40 kHz:")
print(f"  bin = {bin_fine_40:.3f}")
print(f"  mag_python = {mag_fine_40:.4f} LSB (single-bin, mag = abs(X)/N*2 where N=4096)")

# Python mag = abs(X)/N*2 where N=4096 (actual sample count)
# For x = A * Hann * cos(...): abs(X[82]) = A * sum(Hann)/2 = A * 2048/2 = A * 1024
# Wait: abs(X[k0]) = sum(w[n] * x_real[n]) = A/2 * sum(w[n]) = A/2 * 2048 = A * 1024
# (Using Euler: x = A/2 * (exp + exp(-)) and only the exp(-j*2π*k0*n/N) term contributes)
# mag_py = abs(X)/N * 2 = A * 1024 / 4096 * 2 = A/2
# A_signal = mag_py * 2 = 1168.93 * 2 = 2337.86 LSB
# Vpp_LSB = 2 * A = 4675.72 LSB

# Verify by simulating
A_test = 2337.86
n = np.arange(4096)
x = A_test * np.cos(2*np.pi*82*n/N_FFT)
xh = x * hann
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
print(f"\nSimulate with A = {A_test}:")
print(f"  mag_py at bin 82 = {np.abs(X[82])/N*2:.2f} (expected ~{mag_fine_40:.2f})")

# But wait, np.fft uses N_FFT normalization for length-N array? No, np.fft uses input length.
# np.fft.rfft(xp) where xp has length N_FFT, uses N_FFT internally
# So mag = abs(X)/N_FFT*2 if we use N_FFT
# I used abs(X)/N*2 in code, which is wrong! Should be /N_FFT*2

# Re-do:
mag_py_correct = np.abs(X) / N_FFT * 2
print(f"  mag_py (correct, /N_FFT*2) at bin 82 = {mag_py_correct[82]:.2f}")
print(f"  Ratio: mag_py_correct / mag_py_wrong = {mag_py_correct[82] / (np.abs(X[82])/N*2):.4f}")
print(f"  This should be N/N_FFT = {N/N_FFT} = 0.5")

# So mag_py = abs(X)/N*2 = abs(X)/(N_FFT/2)*2 = abs(X)/N_FFT*4 = 4 * (correct mag)
# My code uses /N*2 but should use /N_FFT*2
# So all my "mag_python" values are 2x too high

# Re-do the analysis with correct scaling
mag_py_correct = mag_py / 2  # factor of 2 correction
print(f"\nCorrected Python mag at 40 kHz = {mag_fine_40/2:.4f} LSB (after /2 correction)")
print(f"  → A_signal = corrected_mag * 2 = {mag_fine_40:.4f} LSB (Hann comp)")
print(f"  → Vpp_LSB = 2 * A = {mag_fine_40 * 2:.4f} LSB")

# Wait this is confusing. Let me just be careful.
# np.fft.rfft(xp) returns FFT of xp
# np.abs(X[k]) is the complex magnitude
# Standard interpretation: abs(X[k]) represents |X[k]| where X is the DFT
# For x[n] = sum_k X[k] * exp(j*2π*k*n/N), and the inverse formula uses 1/N scaling
# So |X[k]| has units of N * input_units (peak amplitude in time domain)
# A_signal_peak (in time) = 2 * |X[k_peak]| / N (Hann-uncomp)
# Or, A_signal_peak = |X[k_peak]| / N * 2 if symmetric

# For Hann-windowed x[n]:
# |X[k_peak]| = A/2 * sum(w) = A/2 * 2048 = A * 1024 (with N=4096 sample)
# This is from xp (length N_FFT=8192, zero-padded)
# A_signal = 2 * |X[k_peak]| / sum(w) = 2 * 1024 * A / 2048 = A
# Hmm, let me just empirically verify

# Empirical test
print(f"\n=== Empirical test ===")
A_true = 1000.0  # LSB
n = np.arange(4096)
x = A_true * np.cos(2*np.pi*82*n/N_FFT)
xh = x * hann  # apply Hann
xp = np.zeros(N_FFT)
xp[:4096] = xh
X = np.fft.rfft(xp)
abs_X_82 = np.abs(X[82])
print(f"A_true = {A_true} LSB")
print(f"|X[82]| = {abs_X_82:.4f}")
# Theoretical: |X[82]| = A/2 * sum(w) = 1000/2 * 2048 = 1,024,000
print(f"Theoretical: |X[82]| = {A_true/2 * 2048:.4f}")

# So abs(X) is in LSB (no scaling), and represents |X[k]|
# Python's "mag_py = abs(X)/N*2" was 2x too high
# Correct formula: peak_amplitude (LSB) = 2 * |X[k_peak]| / N_FFT (for FFT without window)
# Or with Hann: peak_amplitude = 2 * |X[k_peak]| / sum(w)

# Try: peak_amp = 2 * |X[82]| / N_FFT = 2 * 1024000 / 8192 = 250
# But A_true = 1000. So this is wrong.

# Hmm. Let me just compute scaling factor empirically
print(f"\nScaling: |X[82]| / A_true = {abs_X_82/A_true:.4f}")
print(f"  sum(w) = {hann.sum():.4f}")
print(f"  N = {N}")
print(f"  N_FFT = {N_FFT}")
print(f"  sum(w)/2 = {hann.sum()/2:.4f}")
print(f"  Ratio to sum(w)/2 = {abs_X_82 / (A_true * hann.sum()/2):.4f}")

# So |X[k_peak]| = A * sum(w) / 2 (for Hann windowed signal at k_peak)
# To recover A: A = 2 * |X[k_peak]| / sum(w)
A_recovered = 2 * abs_X_82 / hann.sum()
print(f"\nA_recovered = {A_recovered:.4f} (should be {A_true})")

# Apply to iladata1:
mag_py_at_82 = abs(X[82]) / N_FFT * 2  # this is my "mag_py" in code
# wait, this uses N_FFT=8192, gives 250 for A=1000
# Let me check what my "mag_py" gives for A=1000
print(f"mag_py at 82 (A_true=1000) = {np.abs(X[82])/N_FFT*2:.4f}")

# OK so mag_py / 4 = A/1000
# mag_py = 4 * A/1000 = A/250
# So A = mag_py * 250
# This is consistent with: mag_py = abs(X)/N_FFT*2 = (A * sum(w)/2) / N_FFT * 2 = A * sum(w) / N_FFT = A * 2048/8192 = A/4

# So A_signal = mag_py * 4
# Vpp = 2 * A_signal = mag_py * 8
# 实测 iladata1: mag_py at bin 82 = 1168.93 → A = 4675.72 → Vpp = 9351.44 LSB
# 这个 Vpp 比 ADC 满量程大很多 → 信号 clipping

# 验证用 Python FFT 反推:
print(f"\n=== 用 Python FFT mag 反推 iladata1 ===")
print(f"mag_py at bin 82 = {mag_fine_40:.4f} LSB")
print(f"A_signal = mag_py * 4 = {mag_fine_40*4:.4f} LSB")
print(f"Vpp_LSB = A_signal * 2 = {mag_fine_40*8:.4f} LSB")
print(f"Vpp_mV_ADC = Vpp_LSB * (5V/4096) = {mag_fine_40*8 * 5000/4096:.4f} mV")
print(f"Vpp_mV_source = Vpp_mV_ADC * 5 = {mag_fine_40*8 * 5000/4096 * 5:.4f} mV")
print(f"  → 实测 9351 LSB Vpp vs ADC max 4095 LSB")
print(f"  → 信号 clipping 严重!")

# 现在的关键问题: CORDIC mag = 27758, 跟 Python mag = 1168.93 (Hann-uncomp) 对应?
# CORDIC 输出 = sqrt(Re^2 + Im^2) = |X[k]| (CORDIC 输出已经是 abs)
# 所以 CORDIC_mag = |X[k_peak]| = A * sum(w)/2 = A * 1024 (with N=4096 sample, Hann)
# 而 Python abs(X) 也 = |X[k_peak]|
# 让我实测:

# Compute |X[82]| for iladata1
print(f"\n=== 直接 |X[82]| for iladata1 ===")
X_abs_82 = np.abs(X[82])
print(f"  np.abs(X[82]) = {X_abs_82:.4f}")
print(f"  CORDIC mag = 27758")
print(f"  Ratio = CORDIC / np.abs = {27758/X_abs_82:.4f}")

# Should be close to 1
# But CORDIC is 16-bit (max 65535), so it might saturate / scale
# CORDIC input is 16-bit (signed), output is 16-bit
# CORDIC internally scales by ~1.6 (rotating mode) without scale comp
# With CORDIC v6 SCALE_COMP=1 (always compensate), no scaling

# So CORDIC mag ≈ |X[k]| (within scaling error)
# But |X[k]| in our simulation = A * 1024
# CORDIC mag = 27758 → A = 27758 / 1024 = 27.10 LSB
# Vpp = 54.20 LSB at ADC
# Vpp_mV = 66.18 mV at ADC
# Vpp_source = 330.91 mV (5x 衰减补偿)
# 期望 175 mV → 偏差 89% !?

# 这个偏差仍然很大, 但方向相反 (实测 > 期望)
# 而 Python 算的 Vpp 9351 LSB = 11421 mV (饱和)
# 两个方法结果不同 → 它们用了不同的 ADC 信号 view

# 可能:
# - Python FFT 用的是 adc - mean 的 ADC 数据 (4096 sample)
# - CORDIC 用的是 Hann-applied 后的 16-bit 数据 (1 ADC LSB = 16-bit 是 scaling)
# - PreMul_Hann 输出 16-bit, 但 ADC 输入 12-bit, scaling = 16 bit ?

# 关键! 看 verilog:
#   PreMul_Hann: x_in (12-bit ADC), x_hanned_16b (16-bit)
#   → 12-bit ADC → 16-bit, x_hanned = ADC * Hann (16-bit Hann) / 256?
#   或 ADC 12-bit, Hann 16-bit, x_hanned = (ADC * Hann) >> ?  (需要查 HannTable_32768.v)