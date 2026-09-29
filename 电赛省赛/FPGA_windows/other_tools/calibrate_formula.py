#!/usr/bin/env python3
"""实测标定: 用 iladata1.csv 反推单片机幅度公式"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\iladata1.csv"

# 已知:
# 源端 40 kHz Vpp = 175 mV (期望)
# 源端 100 kHz Vpp = 25 mV (期望)
# CORDIC mag (40 kHz) = 27758
# CORDIC mag (100 kHz) = 3714 (bin 405)

# ADC UNSIGNED 12-bit, 0~4095
# 衰减 5x
# V_per_LSB (in source) = 5V/4096 / 5 = 2.441 mV (假设 ±5V 量程, 5x 衰减后, ±25V 源端量程)
# 但实际信号 ±10V ?? 不对
# 实际: V_per_LSB (source) = 5V/4096 × 5 (5x 衰减逆) = 6.104 mV/LSB (源端)
# 验证: 40 kHz 175 mV Vpp / 6.104 = 28.66 LSB at source

# 但 iladata1 ADC 是 UNSIGNED, 0..4095 (单极性), 不像 signed ±2048
# 这暗示 ADC 是 0~5V 单端输入, 或者有 DC 偏置
# 实际信号 Vpp 在 ADC (单极性) 是 max-min = 4095 LSB (full scale!)
# 但源端 Vpp = 200 mV? 这意味着 ADC Vpp / 衰减 = 4095 / 5 = 819 LSB (in ±V_ref)
# 不对, 衰减是对 source to ADC, 不是反过来
# source Vpp = 200 mV → ADC Vpp (单极性) = 40 mV (5x 衰减)
# ADC Vpp_LSB = 40 / 1.221 = 32.75 LSB
# 但实测 max-min = 4095 LSB!
# 矛盾: 说明 iladata1 的 ADC 不是真实物理 ADC, 或者信号被 clipping

# 看 ADC mean=1534 (不是 2048 中点), 说明有 DC 偏置
# 也可能是 AD9226 的 V_ref 不是 5V, 而是更小 (如 1V 或 2V)

# 简化处理: 直接用 CORDIC mag 反推源端 Vpp
# 设 CORDIC_mag = k × Vpp_source_mV (k 是常系数)
# 标定 k = CORDIC_mag / Vpp_source_mV
# 验证两个信号的 k 是否一致

# 测试 1: 40 kHz CORDIC = 27758, Vpp_source = 175 mV
k_40 = 27758 / 175
# 测试 2: 100 kHz CORDIC = 3714, Vpp_source = 25 mV
k_100 = 3714 / 25
print(f"40 kHz: CORDIC/Vpp = {k_40:.4f}")
print(f"100 kHz: CORDIC/Vpp = {k_100:.4f}")
print(f"Ratio: {k_40/k_100:.4f} (期望 1.0)")

# 假设线性, 用平均 k
k_avg = (k_40 + k_100) / 2
print(f"\n平均 k = {k_avg:.4f}")
print(f"\n=== 单片机公式 (实测标定) ===")
print(f"// CORDIC_mag → Vpp_source_mV: Vpp = CORDIC_mag / {k_avg:.4f}")
print(f"// = CORDIC_mag * {1/k_avg:.6f} mV")
print(f"// 或: Vpp_mV = CORDIC_mag * 0.00631 mV")

# 测试 3: 用 Python FFT mag 反推
# Python mag at bin 82 = 1168.93 LSB (single-bin, abs(X)/N*2)
# 理论: mag_python = A * sum(w) / N = A * 2048 / 4096 = A/2 (Hann-uncomp peak amplitude)
# A_signal = mag_python * 2 = 2337.86 LSB (peak amplitude)
# Vpp_LSB = 2 * A = 4675.72 LSB
# 但 ADC max-min = 4095 LSB → 信号 saturation

# CORDIC_mag 跟 mag_python 的关系:
# CORDIC_mag = |X[k]| = A * sum(w) / 2 = A * 1024 (with Hann)
# mag_python = abs(X)/N*2 = A * sum(w) / N * 2 = A * 2048 / 4096 * 2 = A
# CORDIC / mag_python = (A * 1024) / A = 1024

# 验证:
print(f"\n=== CORDIC vs Python mag ===")
print(f"CORDIC_mag at 40 kHz = 27758")
print(f"mag_python at 40 kHz = 1168.93 (after /2 correction: {1168.93/2:.2f})")
print(f"  Wait, mag_python uses /N*2 = /4096*2 in my code")
print(f"  But standard convention: abs(X)/N where N is the FFT length used")
print(f"  In numpy: np.fft.rfft(xp) where xp has length N_FFT=8192")
print(f"  So norm should be /N_FFT")
print(f"  mag_python (correct) = abs(X[82])/N_FFT*2 = ?")

# Recompute mag_python with N_FFT normalization
mag_py_correct = np.abs(X[82]) / 8192 * 2  # standard
print(f"\nRecomputing Python mag with N_FFT normalization:")
print(f"  mag_python = abs(X[82])/N_FFT*2 = {mag_py_correct:.4f}")
print(f"  → ratio CORDIC/mag_python = {27758/mag_py_correct:.4f}")
print(f"  Expected: N_FFT/4 = {8192/4} (from theory)")

# Actually let me directly simulate with same scaling
A_test = 100.0  # in LSB
n = np.arange(4096)
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(4096) / 4095))
x = A_test * np.cos(2*np.pi*82*n/8192) * hann  # Hann applied
xp = np.zeros(8192)
xp[:4096] = x
X_test = np.fft.rfft(xp)
abs_X_82 = np.abs(X_test[82])
print(f"\nSimulation A={A_test} LSB:")
print(f"  abs(X[82]) = {abs_X_82:.4f}")
# Theory: abs(X[82]) = A * sum(w)/2 = A * 2048/2 = A * 1024
print(f"  Theory: abs(X[82]) = A * sum(w)/2 = {A_test * hann.sum()/2:.4f}")

# So CORDIC mag ≈ |X[k]| = A * sum(w)/2 = A * 1024
# But that's in "input LSB" units
# A_signal (peak amplitude in LSB) = CORDIC_mag / 1024

# iladata1: CORDIC_mag at 40 kHz = 27758
# A_signal (LSB) = 27758 / 1024 = 27.11 LSB
# Vpp_LSB = 2 * A = 54.21 LSB
# Vpp_mV_ADC = 54.21 * (5V/4096) = 66.19 mV (assuming ±5V 量程)
# Vpp_mV_source = 66.19 * 5 = 330.95 mV (5x 衰减补偿)
# 期望 175 mV → 偏差 +89%

# Hmm 还是不对. 但 wait, ADC 是 UNSIGNED 0~4095, 信号 Vpp 可能不是 ±V_ref
# 可能是 0~V_ref (单极性) → 中心化后 Vpp = max-min (但有 DC 偏置)
# 实际 ADC 量程可能是 1V or 2V (内部 V_ref), 不是 5V

# 实测 ADC mean = 1534 ≈ 4096 * 0.375, V_ref = ? 取决于 AD9226 配置
# 假设 V_ref = 5V: LSB = 1.221 mV
# 信号 Vpp_LSB = max-min = 4095 LSB = 5V (full scale) → saturated
# 信号 Vpp_source = 5V * 5 = 25V ?? 不可能

# 假设 V_ref = 1V: LSB = 0.244 mV
# 信号 Vpp_LSB = 4095 → Vpp_mV_ADC = 1000 mV = 1V (full scale)
# 信号 Vpp_source = 5V → 期望 200 mV → 不对

# 假设 V_ref = 2V: LSB = 0.488 mV
# 信号 Vpp_LSB = 4095 → Vpp_mV_ADC = 2000 mV = 2V
# 信号 Vpp_source = 10V → 期望 200 mV → 不对

# 唯一解释: 信号被放大 (而不是衰减) 进入 ADC
# 或者 iladata1 的数据采集时 gain 设置不正确

# 简化: 用 iladata1 直接做单片机公式标定
# Vpp_source_mV = CORDIC_mag * k1 (linear)
# k1 = Vpp_source / CORDIC_mag = 175 / 27758 = 0.006306 (40 kHz)
# k1 = 25 / 3714 = 0.006731 (100 kHz)
# 平均 k1 = 0.006519

# 单片机公式:
# Vpp_source_mV = CORDIC_mag * 0.006519
# 验证:
vpp_40_cal = 27758 * 0.006519
vpp_100_cal = 3714 * 0.006519
print(f"\n=== 标定后的单片机公式 ===")
print(f"k = {0.006519:.6f}")
print(f"  40 kHz: Vpp = 27758 × {0.006519:.6f} = {vpp_40_cal:.2f} mV (期望 175)")
print(f"  100 kHz: Vpp = 3714 × {0.006519:.6f} = {vpp_100_cal:.2f} mV (期望 25)")

# 简化公式: Vpp ≈ CORDIC_mag / 158 (倒数为 0.006329)
vpp_40_inv = 27758 / 158
vpp_100_inv = 3714 / 158
print(f"\n简化: Vpp_mV = CORDIC_mag / 158")
print(f"  40 kHz: Vpp = 27758 / 158 = {vpp_40_inv:.2f} mV (期望 175)")
print(f"  100 kHz: Vpp = 3714 / 158 = {vpp_100_inv:.2f} mV (期望 25)")