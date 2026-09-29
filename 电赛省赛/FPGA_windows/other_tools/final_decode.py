#!/usr/bin/env python3
"""最终确认 iladata1.csv 的两个信号位置 - 用 N=8192"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\iladata1.csv"

# 读
first_cycle = {}
adc_raw = []
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
            if valid == 1 and buf < 6144:
                if bin_idx not in first_cycle:
                    first_cycle[bin_idx] = mag
                adc_raw.append(adc)
        except: continue

# ADC Python FFT (unsigned, mean-subtracted)
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
mag_py = np.abs(X) / N * 2  # LSB units
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 peaks
def find_5pt(mag, center_bin):
    half = 2
    br = np.arange(center_bin-half, center_bin+half+1)
    m = mag[br]
    c2 = np.polyfit(br, m, 2)
    bin_fine = -c2[1] / (2*c2[0])
    mag_fine = np.polyval(c2, bin_fine)
    return bin_fine, mag_fine

# 40 kHz
local_region = mag_py[78:91]
local_peak = np.argmax(local_region) + 78
bin_fine_40, mag_fine_40 = find_5pt(mag_py, local_peak)
print(f"40 kHz (Python ADC FFT): bin={bin_fine_40:.3f}, freq={bin_fine_40*488.281:.2f} Hz, mag={mag_fine_40:.2f} LSB")

# 100 kHz
local_region = mag_py[200:215]
local_peak = np.argmax(local_region) + 200
bin_fine_100, mag_fine_100 = find_5pt(mag_py, local_peak)
print(f"100 kHz (Python ADC FFT): bin={bin_fine_100:.3f}, freq={bin_fine_100*488.281:.2f} Hz, mag={mag_fine_100:.2f} LSB")

# ILA CORDIC mag 在预期 bin 的值
# 40 kHz → bin 82 → ILA bin 282
print(f"\n=== ILA CORDIC mag 在预期位置 ===")
print(f"40 kHz expected ILA bin 282, CORDIC mag = {first_cycle.get(282, 'N/A')}")
print(f"100 kHz expected ILA bin 404, CORDIC mag = {first_cycle.get(404, 'N/A')}")
# 取 100 kHz 附近 ILA mag (bin 403..407)
near_100k = [(b, first_cycle[b]) for b in range(403, 408) if b in first_cycle]
print(f"100 kHz 附近 ILA bins 403..407: {near_100k}")

# === 1. FFT N 验证: 用 40 kHz 实际信号频率反推 ===
# 已知: 信号是 40 kHz, 实测 ILA bin 282
# bin 282 → ILA bin 282
# bin_cnt (verilog 内部) = bin_in - 200 = ?
# ILA bin 显示 = bin_in mod 2048
# 因为 bin_in = bin_cnt + 200, mod 2048
# 当 bin_cnt = 0..2047: bin_in = 200..2247, mod 2048 = 200..2047 + 0..199 = 0..2047
# 完整覆盖 0..2047

# 反推 bin_cnt: 假设 bin_cnt = ila_bin (mod 2048), 即 bin_cnt ∈ [0, 2047]
# 验证: ILA bin 282 → bin_cnt 282 (mod 2048) → freq = 282 * 488.281 = 137.7 kHz ✗
# 但实际信号是 40 kHz

# 验证: bin_cnt = ila_bin - 200 (mod 2048)
# ILA bin 282 → bin_cnt 82 → freq = 82 * 488.281 = 40 kHz ✓

print(f"\n=== Bin 解码验证 ===")
# 验证 1: bin_cnt = ila_bin (mod 2048)
freq_40k_method1 = 282 * 488.281
print(f"方法1: real_bin = ila_bin (mod 2048) → freq = {freq_40k_method1/1000:.2f} kHz (期望 40, 错误)")

# 验证 2: bin_cnt = ila_bin - 200 (mod 2048)
freq_40k_method2 = (282 - 200) * 488.281
print(f"方法2: real_bin = ila_bin - 200 (mod 2048) → freq = {freq_40k_method2/1000:.2f} kHz (期望 40, ✓)")

# 验证 100 kHz
freq_100k_method2 = (404 - 200) * 488.281
print(f"方法2: 100 kHz ILA bin 404 → real_bin 204 → freq = {freq_100k_method2/1000:.2f} kHz (期望 100, ✓)")

# === 2. 5-550 kHz 范围对应 ILA bin ===
print(f"\n=== 5-550 kHz 范围 ===")
f_min = 5000.0 / 488.281  # = 10.24 → 11
f_max = 550000.0 / 488.281  # = 1126.4 → 1127
print(f"5 kHz → real_bin = {f_min:.2f} → ILA bin = {f_min+200:.2f}")
print(f"550 kHz → real_bin = {f_max:.2f} → ILA bin = {f_max+200:.2f}")

# === 3. 模拟单片机接收数据流 (第一三角坡 2048 个点, 取 5-550 kHz 范围) ===
print(f"\n=== 模拟单片机接收 (第一三角坡, 5-550 kHz) ===")
n_total = 0
n_filtered = 0
peak_mag = 0
peak_bin = 0
for ila_bin in range(2048):
    n_total += 1
    real_bin = ila_bin - 200  # wrap to 0..2047
    if real_bin < 0: real_bin += 2048
    if real_bin < 11 or real_bin > 1126: continue
    n_filtered += 1
    mag = first_cycle.get(ila_bin, 0)
    if mag > peak_mag:
        peak_mag = mag
        peak_bin = ila_bin

print(f"  接收总点数 (第一三角坡): {n_total}")
print(f"  5-550 kHz 范围过滤后: {n_filtered}")
print(f"  范围: ILA bin 211..1326, real_bin 11..1126")
print(f"  峰值: ILA bin {peak_bin}, mag {peak_mag}")

# === 4. 验证 N_Hann 和 mag 公式 ===
# 实测:
# CORDIC mag at 40 kHz = 27758
# Python FFT mag at bin 82 = 1168.93 LSB (single-bin, Hann-uncomp)
# 但 CORDIC 输出已经是 Hann 后的, 而 Python mag 是 /N*2 = 1168.93
# |X[k]| = 1168.93 * N / 2 = 1168.93 * 4096 = 4,787,057
# CORDIC mag = 27758
# 比例 = 4,787,057 / 27758 = 172.5x

# 或者: CORDIC mag (Hann) = |X_unHann| / 2 = 4,787,057 / 2 = 2,393,528
# 但 CORDIC 输出 27758, 比例 = 2,393,528 / 27758 = 86.2x

# 或者: CORDIC 输出 = |X_with_Hann|, |X_with_Hann| = |X_unHann| * 0.5 (Hann 窗整体缩 0.5)
# 但实际是  |X_with_Hann| = A * N/4 (Hann coherent gain = 0.5)
# |X_unHann| = A * N/2 (no Hann)
# Python mag = |X_unHann| / N * 2 = A
# CORDIC mag = |X_with_Hann| = A * N/4
# 比例 = CORDIC / Python_mag = N/4 = 8192/4 = 2048

# 验证: CORDIC mag / Python_mag = 27758 / 13.55 ≈ 2048
# 但 Python_mag at bin 82 = 1168.93 LSB (after /N*2)
# Python 真正的 |X[k]| = 1168.93 * 4096 = 4,787,057
# CORDIC mag = 27758
# 比例 = 4,787,057 / 27758 = 172.5x

# 等等, A = 1168.93 LSB? 但 Vpp_ADC = 2A = 2337.86 LSB = 2855 mV (ADC 端)
# 这对应 5V 满量程下很大信号, 跟 200mV Vpp 5x 衰减不符

# 让我重新理解 Python FFT mag 的含义:
# x[n] = ADC[n] (in LSB), N=4096 sample
# X[k] = sum x[n] * exp(-j*2π*k*n/N), for k in [0, N-1]
# 注意: Python FFT 用 N=4096 (实际 sample 数)
# 但 numpy 用 N_FFT=8192 (zero-padded), 自动 FFT N_FFT
# Python mag = abs(X) / N * 2 = abs(X) / 4096 * 2
# 对于单频 A*cos(...), X[k_peak] = A * N/2 * 0.5 (Hann) = A * 1024 (Hann)
# abs(X) = A * 1024
# Python mag = A * 1024 / 4096 * 2 = A / 2 (这是 Hann-uncompensated!)
# 实际上 A = 1168.93 * 2 = 2337.86 LSB (peak amplitude)
# Vpp = 2 * A = 4675.72 LSB (但这跟前面 2337.86 矛盾, 因为 /N*2 已经是 peak amp)

# 重新校准:
# abs(X) / N = 单边谱密度 (V/Hz)
# abs(X) / N * 2 = 单边谱 peak amplitude (peak 信号的复振幅 magnitude)
# 对于 x[n] = A*cos(2π*k0*n/N):
#   X[k0] = A * N/2
#   abs(X[k0]) = A * N/2
#   abs(X[k0]) / N * 2 = A
# 所以 Python mag (= abs(X)/N*2) = A (peak amplitude in same unit as input)
# 如果 x 是 LSB, A 也是 LSB
# Python mag at bin 82 = 1168.93 LSB → A = 1168.93 LSB → Vpp = 2A = 2337.86 LSB

# 但 2337.86 LSB 太大了 (Vpp_mV = 2337.86 * 1.221 = 2855 mV)
# ADC 量程 5V, 这相当于信号满量程
# 这意味着 iladata1 实际是 5V 输入 (满量程), 不是 200mV Vpp

# 等等, ADC UNSIGNED 0~4095, mean=1534, Vpp = max-min ≈ 4095
# 信号 Vpp 接近 5V → 这是满量程!
# 但 ADC Vpp ADC max = 5V, source Vpp = 5V * 5 = 25V ?? 这不对

# 重新看: iladata1.csv 的 ADC 是 UNSIGNED 12-bit, mean=1534
# 如果信号是 ±2.5V, ADC 输出 0..4095
# Vpp = (max-min) * 5V/4096 = 4095 * 1.221 = 5000 mV = 5V
# 但实际信号 Vpp 应该是 200mV/5x = 40mV at ADC
# 40mV / 1.221mV/LSB = 33 LSB
# ADC max - min = 33 LSB (信号 Vpp)
# 但实测 max-min = 4095 LSB??

# 这意味着 iladata1.csv 的 ADC 是 wrong - 实际信号被削顶 (clipping)
# 或者 ADC 是显示是 UNSIGNED, 但实际接的是差分信号

print(f"\n=== ADC 范围分析 ===")
print(f"ADC max - min = {max(adc_raw) - min(adc_raw)} LSB")
print(f"  → Vpp = {(max(adc_raw) - min(adc_raw)) * 1.221:.1f} mV at ADC")
print(f"  → 这意味着信号 ADC 端 Vpp ≈ 5V (满量程)")
print(f"  → 实际硬件信号源 200mV Vpp / 5x = 40mV Vpp at ADC")
print(f"  → 不一致! iladata1 看起来是 ADC saturated / clipping")

# 但 Python FFT 仍然能找到 40/100 kHz peak
# 因为信号饱和只是削顶 (clipping), 主频分量仍在
# Python mag at bin 82 = 1168.93 LSB → A = 1168.93 LSB
# 但实际信号削顶后, A 的物理值 ≈ 33 LSB (因为 source 200mV Vpp / 5x / 1.221mV)
# Python 算的 1168.93 LSB 应该是 clipped signal 的等效 A

# 重新: clipping 后, FFT 的 A 反映的是饱和前的"虚拟振幅" 不是真实信号振幅
# 用 CORDIC mag = 27758 反推真实 A?
# CORDIC 算的是 FPGA 内 Hann-FFT 的 mag, 同样被 clipping 影响
# CORDIC mag = A * N/4 = A * 2048
# → A = 27758 / 2048 = 13.55 LSB
# Vpp = 27.10 LSB at ADC
# Vpp_mV = 33.09 mV at ADC
# Vpp_source = 165.45 mV (5x 衰减)
# 期望 175 mV → 偏差 5.4% ✓ (合理!)

# 所以: 单片机用 CORDIC mag 计算 Vpp 是正确的 (因为 clipping 后 mag 仍反映真实信号)
# Python mag 1168.93 LSB 反映 clipping 后的虚拟振幅 (无 Hann)
# 实际 A = 1168.93 LSB, Vpp = 2337.86 LSB
# 但因为 ADC 量程 5V, 2337.86 LSB ≈ 2855 mV, 远大于信号真实 Vpp
# 这是因为 ADC 是 UNSIGNED, 而我做了 mean-subtract 后用 LSB 单位, Python mag 单位是 LSB
# 但 Python mag 也对应 clipping 前的 virtual A (因为 Python FFT 是 linear)
# 等等, ADC 已经饱和, Python FFT 输入已经是 clipping 后的值
# 那 Python FFT 输出 mag 应该反映 clipping 后信号的频谱, 不是真实信号

# 等等, 让我看看 ADC 实际 max/min
# max-min = 4095, 这说明 ADC 输出从 0 到 4095 (full range)
# 这要么是 ADC 是 UNSIGNED 的饱和值, 要么是真的 5V peak-to-peak
# 检查 raw 头几个 ADC 值
print(f"\n=== Raw ADC (前 10 个 valid) ===")
for i, r in enumerate(adc_raw[:10]):
    print(f"  adc[{i}] = {r}")

print(f"\n=== Raw ADC (中间 10 个) ===")
for i, r in enumerate(adc_raw[2000:2010]):
    print(f"  adc[{i+2000}] = {r}")

# 看 ADC 是否真的饱和
adc_arr = np.array(adc_raw)
print(f"\nADC min = {adc_arr.min()}")
print(f"ADC max = {adc_arr.max()}")
print(f"ADC distribution (high end):")
hist, bins = np.histogram(adc_arr, bins=20)
for h, b in zip(hist, bins):
    print(f"  [{b:.0f}-{b+bins[1]-bins[0]:.0f}]: {h} samples")

# === 5. 单片机最终公式 (基于 CORDIC mag) ===
print(f"\n=== 单片机最终公式 (基于 CORDIC mag) ===")
print(f"// N_FFT = 8192 (实测反推)")
print(f"// N_Hann = N_FFT * 0.5 = 4096 (Hann coherent gain)")
print(f"//")
print(f"// 1. ILA bin → real FFT bin")
print(f"int32_t real_bin = (int32_t)ila_bin - 200;")
print(f"if (real_bin < 0) real_bin += 2048;  // wrap to [0, 2047]")
print(f"")
print(f"// 2. real bin → 频率 (Hz)")
print(f"float freq_Hz = (float)real_bin * 488.281f;")
print(f"")
print(f"// 3. CORDIC mag → Vpp (mV at source)")
print(f"// CORDIC mag = A * N_Hann = A * 4096 (with Hann)")
print(f"// → A (LSB peak) = CORDIC_mag / 4096")
print(f"// → Vpp (LSB peak-peak) = 2 * A = CORDIC_mag / 2048")
print(f"// → Vpp_mV_ADC = Vpp_LSB * (5000/4096) = CORDIC_mag * 1.221 / 2048")
print(f"// → Vpp_mV_source = Vpp_mV_ADC * 5.0 (5x attenuation comp)")
print(f"float Vpp_mV_at_source = (float)CORDIC_mag * 1.221f / 2048.0f * 5.0f;")
print(f"// = CORDIC_mag * 0.002981 mV")
print(f"")
print(f"// 验证:")
print(f"// 40 kHz: CORDIC_mag = 27758, Vpp = {27758 * 1.221 / 2048 * 5:.2f} mV (期望 175)")
print(f"// 100 kHz: CORDIC_mag = 3714, Vpp = {3714 * 1.221 / 2048 * 5:.2f} mV (期望 25)")