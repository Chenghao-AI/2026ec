#!/usr/bin/env python3
"""验证 Hann 窗的实际 coherent gain"""
import numpy as np

# Hann 窗 N=4096
N = 4096
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
print(f"Hann window (N={N}):")
print(f"  sum = {hann.sum():.4f}")
print(f"  mean = {hann.mean():.4f}")
print(f"  Coherent gain = sum/N = {hann.sum()/N:.4f}")
print(f"  Theoretical: 0.5")

# 对于 FFT N=8192 (zero-padded from 4096 sample)
# Hann window applied in time, then zero-padded
# X[k_peak] = sum_{n=0}^{N-1} A * w[n] * exp(-j*2π*k*n/N_FFT)
# 对于 k_peak 在主频, X[k_peak] ≈ A * sum(w[n]) / 2 (因为 fftshift / N_FFT scaling)
# 标准 Python: mag_python = abs(X)/N_FFT*2 (single-sided peak amplitude)
# 对于 Hann applied: A_python = abs(X)/N_FFT*2 = A * sum(w)/N_FFT / (some scaling)

# Actually 让我直接模拟
A_signal = 1.0  # 1 LSB peak
f_signal = 82  # bin 82 (40 kHz)
N_FFT = 8192
n = np.arange(N)
x = A_signal * np.cos(2*np.pi*f_signal*n/N_FFT)
# Apply Hann
xh = x * hann
# Zero-pad to N_FFT
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag_python = np.abs(X) / N_FFT * 2
print(f"\nSimulation (A={A_signal} LSB, N={N} sample, Hann, N_FFT={N_FFT}):")
print(f"  X[82] (bin 82) = {X[82]:.4f}")
print(f"  mag_python = {mag_python[82]:.4f} LSB")
# A_signal expected = 1.0
# Hann coherent gain = sum(w)/N = 0.5
# mag_python = A_signal * (sum(w)/N) * N / N_FFT * 2  <-- scaling
# = A_signal * 0.5 * 4096 / 8192 * 2 = 0.5 LSB

# 等等, mag_python = A_signal/2 = 0.5
# 这是因为 Hann 把信号能量减半, 反映在 X[k_peak] 上

# 所以 mag_python * 2 = A_signal (Hann comp)
# 实测: mag_python at 40 kHz = 1168.93 LSB (from earlier)
# → A_signal = 1168.93 * 2 = 2337.86 LSB (peak amplitude)
# → Vpp = 4675.72 LSB (this is at ADC, in LSB unit)
# 但 ADC 是 UNSIGNED, Vpp_LSB = max-min = 4095 LSB
# 这与 4675.72 LSB 矛盾

# 啊! Python mag at bin 82 = 1168.93 LSB
# Vpp_LSB_peak = 1168.93 * 2 (Hann comp) = 2337.86 LSB
# 但 ADC max-min = 4095 LSB → 信号 Vpp = 4095 LSB
# 差 1.75x

# 实际上, Python 用 N_FFT = 8192, 但实际数据只有 N=4096 sample
# 这相当于 zero-padding to N_FFT
# 信号 A = 1168.93 / 2 = 584.47 LSB (实际 peak amplitude, Hann-uncomp)
# Wait, mag_python = abs(X)/N*2 = 1168.93, so abs(X) = 1168.93 * 8192 / 2 = 4,787,058
# 实际 A_signal 在时域峰值 = max(|x[n]|)
# 但 x 是 Hann 后的, x peak = A_signal * 0.5 (Hann max)
# 所以 A_signal = x_peak / 0.5
# x[n] = A_signal * cos(...) * w[n], max = A_signal * 0.5 (at Hann peak)
# 实测 ADC max-min = 4095 LSB, 是 x 的峰峰值 = 2 * x_peak = A_signal * 0.5 * 2 = A_signal
# → A_signal = 4095 LSB (peak amplitude in LSB)
# → Vpp = 8190 LSB
# 但 mag_python = 1168.93 LSB
# → A_signal / mag_python = 4095 / 1168.93 = 3.50 (差 3.5x)

# 让我重新理解: Python mag = abs(X)/N*2
# 对于 x = A * w * cos(2πf*n/N):
#   abs(X[f*N/(N_FFT)]) = A * sum(w) / 2 (because X is "smooth" peak)
# 不对, 实际是:
# X[k] = sum_n x[n] * exp(-j*2π*k*n/N_FFT)
# 对于 x[n] = A * w[n] * cos(2π*f0*n/N_FFT) = A/2 * w[n] * (exp(j2πf0*n/N_FFT) + exp(-j2πf0*n/N_FFT))
# X[k] = A/2 * sum w[n] * exp(-j*2π*(k-f0)*n/N_FFT) + A/2 * sum w[n] * exp(-j*2π*(k+f0)*n/N_FFT)
# X[k0=f0] = A/2 * N_FFT * (sum w[n]/N_FFT) = A/2 * sum(w)  (using DTFT property of w at zero frequency)
# sum(w) for Hann N=4096 ≈ 4096 * 0.5 = 2048
# X[k0] = A/2 * 2048 = A * 1024
# mag_python = abs(X) / N_FFT * 2 = A * 1024 / 8192 * 2 = A / 4 = A * 0.25

# 验证: A_signal = 4095 LSB, mag_python = 4095 / 4 = 1023.75 LSB
# 实测 mag_python at bin 82 = 1168.93 LSB (after 5pt fit)
# 单 bin mag = 1164 (近似)
# 差 1168.93 - 1023.75 = 145 LSB = 14% (信号不是 pure cosine, 有 100kHz 干扰)

# 实际上 mag_python 公式是:
# abs(X) / N_FFT * 2 = abs(X[k0]) / 8192 * 2
# 其中 abs(X[k0]) = A/2 * sum(w)
# 所以 mag_python = (A/2 * sum(w)) / 8192 * 2 = A * sum(w) / 8192

# sum(w) for N=4096 Hann ≈ 4096 * 0.5 = 2048
# mag_python = A * 2048 / 8192 = A / 4

# 验证: A_signal = 1168.93 * 4 = 4675.72 LSB → 但 max-min = 4095 LSB!
# 矛盾. 让我重新理解 Python fft scaling

# NumPy rfft scaling:
# np.fft.rfft(x) returns complex spectrum
# np.abs(X[k]) = |X[k]| in physical units
# For x[n] = sum_k X[k] * exp(j*2π*k*n/N), np.fft.rfft(X) doesn't scale, returns same units
# So if x is in LSB, X is in LSB
# For x[n] = A * cos(2π*k0*n/N), X[k0] = X[N-k0] = A*N/2 (no window)
# np.abs(X[k0]) = A * N/2 = A * 4096 (since x has N=4096 samples)
# np.abs(X) / N * 2 = A * 4096 / 4096 * 2 = A * 2
# This means mag_python = 2*A (overshoot by 2x)?

# Actually, let me re-derive:
# Forward DFT (numpy convention): X[k] = sum_n x[n] * exp(-j*2π*k*n/N)
# Inverse: x[n] = (1/N) sum_k X[k] * exp(j*2π*k*n/N)
# For x[n] = A * cos(2π*k0*n/N) = A/2 * (exp(j*2π*k0*n/N) + exp(-j*2π*k0*n/N))
# X[k0] = A/2 * N, X[-k0] = A/2 * N
# So |X[k0]| = A*N/2
# np.abs(X[k0]) / N * 2 = A
# ✓ So mag_python = A (peak amplitude in input units)

# With Hann window:
# x[n] = A * cos(2π*k0*n/N) * w[n] = A/2 * w[n] * (exp(j2πk0n/N) + exp(-j2πk0n/N))
# X[k0] = A/2 * sum_n w[n] * exp(-j*2π*(k0-k0)*n/N) = A/2 * sum(w) = A/2 * (N * 0.5) = A * N / 4
# So |X[k0]| = A * N / 4 (with Hann, N samples)
# np.abs(X[k0]) / N * 2 = A / 2 (single-sided peak amplitude with Hann uncomp)
# To get A: mag_python * 2 = A (Hann coherent gain compensation)

# OK so mag_python = A / 2 (Hann uncomp)
# A = mag_python * 2 = 1168.93 * 2 = 2337.86 LSB
# Vpp = 2 * A = 4675.72 LSB

# But ADC max-min = 4095 LSB. Why conflict?
# Because x has clipping or different scaling
# Or because A_signal in the formula is not the actual peak of unclipped signal

# Let's just verify by simulation
print(f"\n=== Simulation ===")
A_true = 100.0  # LSB
N = 4096
N_FFT = 8192
f_signal = 82 * N_FFT / N  # in bin units (of N_FFT)
# Hmm wait, f_signal in bin of N_FFT for zero-padded FFT
# Actually, f_signal = 82 means 82 cycles per N_FFT samples
# For 40 kHz at fs=4 MHz: bin in N_FFT = 82 / N_FFT * fs = 82 / 8192 * 4e6 = 40 kHz ✓
n = np.arange(N)
x = A_true * np.cos(2*np.pi*82*n/N_FFT)  # 40 kHz signal
xh = x * hann  # Apply Hann
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag_py = np.abs(X) / N_FFT * 2
print(f"Signal A_true = {A_true} LSB")
print(f"  Python mag at bin 82 = {mag_py[82]:.4f} LSB")
print(f"  Ratio: A_true / mag_py = {A_true / mag_py[82]:.4f}")

# 实际: mag_py / A_true = 0.25 (因 /4 from Hann, N=4096 vs N_FFT=8192 zero-pad)
# 所以: A_true = mag_py * 4
# 验证: 1168.93 * 4 = 4675.72 LSB
# Vpp = 9351.44 LSB
# 这比 ADC range 4095 大很多 → 信号 clipping!
# 但实测的 max-min = 4095 LSB → 信号被 clipping 到 ±2047.5 (full scale)

# 这意味着实际 40 kHz 信号在 ADC 输入端 Vpp > ADC range
# 但因为 ADC 是 UNSIGNED 0~4095 (单极性), 最大值 = 4095 = V_ref (5V)
# 实际信号中心化后 Vpp (单极性) = max - min = 4095 LSB = 5V
# 这超过 AD9226 的量程

# 关键洞察: ADC 是 UNSIGNED, 没有 ±2048 双极性
# 信号 200 mV Vpp / 5x = 40 mV Vpp at ADC (期望)
# 但实测 ADC P2P = 5V → 信号被饱和削顶了

# 这意味着:
# 1. iladata1.csv 的数据是 saturation 数据 (40 kHz + 100 kHz 已削顶)
# 2. Python FFT mag at bin 82 = 1168.93 LSB 是 saturated spectrum 的 "virtual A"
# 3. 真实信号的 A (如果有 ADC 更大量程) = mag_py * 4 = 4675.72 LSB
# 4. Vpp = 9351.44 LSB ≈ 11.42 V (远大于 40 mV 期望)

# 等等, 5x attenuation:
# 200 mV source Vpp → ADC Vpp = 40 mV → ADC LSB = 40/1.221 = 32.75 LSB (期望)
# 但实测 ADC Vpp = 4095 LSB (饱和!)
# 偏差: 4095/32.75 = 125x → 信号比期望大 125 倍

# 不可能! 让我重新看 ADC 的 radix 是 UNSIGNED
# iladata1 ADC column 6 (UNSIGNED), format = UNSIGNED
# 但实际 ADC AD9226 通常是 binary offset, 即 0~4095 = 0~5V, 或者 ±5V 双极性
# 如果是 binary offset, 则 0 = -5V, 2048 = 0V, 4095 = +5V
# 但 radix UNSIGNED 表示数字直接显示 0~4095

# 重新看 ADC:
# min=0, max=4095, mean=1534
# 如果 binary offset: mean = 1534 → 实际电压 = (1534 - 2048) * 5V/4096 = -627 LSB * 5/4096 = -0.766 V
# max=4095 → (4095-2048) * 5/4096 = 2.497 V
# min=0 → -2.5 V
# 信号 Vpp = 2.497 - (-2.5) = 4.997 V ≈ 5V (full scale, 削顶)

# 但 ADC V_ref 是多少?
# AD9226 通常 V_ref 内部固定 1V 或 2V, 输入范围 0~V_ref 或 ±V_ref
# 如果 V_ref = 2V, 输入 ±2V (binary offset): Vpp = 4V
# 如果 V_ref = 1V, 输入 ±1V (binary offset): Vpp = 2V
# 通常 ADC 配置 differential 模式, V_ref 决定量程

# 但 UNSIGNED 0~4095 直接对应 0~5V (single-ended)
# UNSIGNED 不可能输出 0~5V 而 AD9226 是 0~5V → 如果是单端输入, ADC = 0..4095 = 0..V_ref
# 但 AD9226 是 12-bit, V_ref 通常 1V/2V/5V 内部可选

# 简化: 假设 V_per_LSB = 5V/4096 = 1.221 mV (不管 V_ref 多少)
# Vpp = (max-min) * V_per_LSB = 4095 * 1.221 mV = 5V

# 实际信号应该是 200 mV Vpp → ADC Vpp 应该 = 40 mV (5x衰减)
# 但实测 ADC Vpp = 5V → 不可能!

# 除非: 5x 衰减是指别的链路, 不是 ADC 前端
# 或者 iladata1 的数据有误

# 重新看 iladata1 的 ADC 头几个值
print(f"\n=== iladata1 ADC 前 20 个 valid sample ===")
with open(fp) as f:
    reader = csv.reader(f)
    next(reader); next(reader)
    cnt = 0
    for row in reader:
        if len(row) < 7: continue
        try:
            buf = int(row[0])
            valid = int(row[5], 16)
            adc = int(row[6])
            if valid == 1:
                print(f"  buf={buf}, adc={adc}")
                cnt += 1
                if cnt >= 20: break
        except: continue