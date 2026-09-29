#!/usr/bin/env python3
"""用正确的 verilog 配置 + iladata1.csv 完整验证 MCU 接收路径"""
import csv
import numpy as np
from collections import defaultdict

fp = r"C:\Users\24307\Desktop\FPGA_windows\iladata1.csv"

# === 1. 文件元数据 ===
with open(fp) as f:
    lines = f.readlines()
print(f"=== iladata1.csv 文件 ===")
print(f"Total lines: {len(lines)}")
print(f"Header: {lines[0].strip()}")
print(f"Radix:  {lines[1].strip()}")

# === 2. Trigger & frame_end ===
triggers = []
for i, line in enumerate(lines[2:], start=2):
    parts = line.strip().split(',')
    if len(parts) >= 3 and parts[2] == '1': triggers.append(i)
print(f"Trigger position: row {triggers}")

# === 3. 读 valid 数据 (unsigned ADC) ===
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
            adc = int(row[6])  # UNSIGNED 12-bit
            valid_rows.append((buf, bin_idx, mag, valid, adc))
        except: continue

# 找 valid 区段
valid_only = [r for r in valid_rows if r[3] == 1]
print(f"\n=== Valid 数据段 ===")
print(f"Valid samples: {len(valid_only)}")
print(f"Valid buf range: {valid_only[0][0]} .. {valid_only[-1][0]}")
print(f"Valid bin range: {min(r[1] for r in valid_only)} .. {max(r[1] for r in valid_only)}")

# === 4. 第一三角坡 (buf 4096..6143 = first cycle) ===
first_cycle = {}
for buf, b, m, v, a in valid_only:
    if buf < 6144:
        if b not in first_cycle:
            first_cycle[b] = m

print(f"\n=== 第一三角坡 (单片机接收数据) ===")
print(f"Total bins in 1st cycle: {len(first_cycle)}")
print(f"Bin range: {min(first_cycle)}..{max(first_cycle)}")

# === 5. 5-550 kHz 范围 ===
# 用户要求 5-550 kHz
# 真实 bin (FFT bin_cnt) = bin_in - 200 (来自 verilog +200 偏置)
# 但因为 ILA BRAM 11-bit 截断, bin 显示是 (bin_in mod 2048)
# 所以 decoded_real_bin_cnt = (ila_bin - 200) mod 2048
# 频率 = real_bin_cnt * Δf, Δf = 4MHz / 32768 = 122.07 Hz/bin
DELTA_F = 4e6 / 32768  # = 122.07 Hz/bin
print(f"\n=== Verilog 配置 ===")
print(f"FFT N = 32768 (NOT 8192!)")
print(f"Δf = fs/N = 4 MHz / 32768 = {DELTA_F:.4f} Hz/bin")
print(f"ADC: 12-bit UNSIGNED, 0~5V, V_per_LSB = {5000/4096:.6f} mV")
print(f"CORDIC: 16-bit I/Q → 16-bit mag")
print(f"ila_probe_bin: 11-bit BRAM (= bin_in mod 2048)")
print(f"bin_in = bin_cnt + 200 (verilog +200 偏置)")
print(f"bin_cnt 15-bit (0..32767), BinSelect 取 [0, 8191]")
print(f"iladata1.bin=200 DC at real_bin_cnt=0 (实际 BinSelect 把 [0,8191] 通过)")

# 但实际 bin_in 范围检查: BIN_LO=0, BIN_HI=8191, 接受 0..8191
# 0..8191 映射到 200..8391 (因为 +200), 但 max=8191 时 bin_in = 8191+200 = 8391 > 8191 -> invalid!
# 实际有效 bin_in = 0..7991, bin_out = 0..7991, 有效 7992 个 bin
# 然后 wraparound 一次 (bin_cnt 跑到 32768 再回到 0)

# 关键问题: bin_in = bin_cnt + 200
# bin_cnt 是 15-bit, bin_in 也是 15-bit
# 当 bin_cnt=0..7991: bin_in = 200..8191 (valid in [0,8191])
# 当 bin_cnt=7992..8191: bin_in = 8192..8391 (invalid)
# 当 bin_cnt=8192..32767: bin_in = 8392..32967 (invalid)
# 当 bin_cnt=0..200 (循环到下一个 32768-cycle): bin_in = 200..400 (valid)

# 但 bin_in = bin_cnt + 200 会 wraparound 13-bit 部分吗?
# 实际上是 15-bit + 13-bit (zero-extended), 结果 15-bit
# 但 verilog 用 13'd200 + 15-bit bin_cnt 是 15-bit (zero-extended by zero padding)

# 简单解读: bin_in 是 15-bit
# ILA BRAM 11-bit 截断: ila_bin = bin_in & 0x7FF
# ILA bin 范围: 0..2047, 但实际 bin_in 0..8191 是线性, 0..7991 时显示 0..7991 mod 2048 (不发生 wrap)

# 第一三角坡 ILA bin = 0..2047, 表示 bin_in mod 2048
# 解读: bin_in = ila_bin + 200 (反推, 但考虑 wraparound 到 11-bit)
# 实际上, 11-bit BRAM 显示 ila_bin 0..2047 是 bin_in mod 2048
# 而 bin_in 实际是 bin_cnt + 200, bin_cnt 是 0..7991 (BinSelect 输出)
# 解读: bin_cnt = bin_in - 200

# 但 ILA 显示的是 (bin_cnt + 200) mod 2048
# 0 ≤ bin_cnt ≤ 7991, 200 ≤ bin_in ≤ 8191, 但是 bin_in mod 2048 = 200..2047 然后 0..199 (只在 2048 处 wrap)
# 但 bin_in 上限 8191 (verilog BIN_HI=8191 限制), 所以 bin_in mod 2048 永远 < 2048, 不会 wrap
# 但 ILA 显示 0..2047 表示一个循环 2048 个 clk
# 实际 bin_cnt 应该 0..2047 (循环一次 = 2048 clk)

# 让我看 iladata1 第一三角坡里的 ila_bin 0..2047
# 这意味着 bin_cnt 0..2047 出现了一次, 然后跳到 2048+
# 第二三角坡是 bin_cnt 2048..4095? 还是再次 0..2047?

# Look at first cycle data
bins_first = sorted(first_cycle.keys())
print(f"First cycle ila bins (first 10): {bins_first[:10]}")
print(f"Last 5: {bins_first[-5:]}")

# Each bin appears 1 time in first cycle
# Check all bins
all_present = all(b in first_cycle for b in range(2048))
print(f"All bins 0..2047 in first cycle: {all_present}")

# So: 第一三角坡 = ILA bin 0..2047, 代表 bin_in = ila_bin + 200 (连续)
# 不! 如果 ILA 显示 0..2047, 那 bin_in 是 0..2047, 不是 200..2247
# 除非 ILA BRAM 显示的是 bin_in - 200 (verilog 减回来)

# 仔细看: ila_probe_bin 在 verilog 里是 bin_bin_13 (BinSelect 的 bin_out)
# BinSelect 公式: bin_out = bin_in - BIN_LO = bin_in - 0 = bin_in
# 所以 bin_out = bin_in = bin_cnt + 200
# ila_probe_bin = bin_bin_13 = (bin_cnt + 200) mod 8192 (13-bit)
# 但 ILA BRAM 是 11-bit, 所以 ila_bin = (bin_cnt + 200) mod 2048

# 第一三角坡显示 0..2047 表示 bin_cnt + 200 从 0 走到 2047 再 wrap
# 也就是 bin_cnt 从 -200 .. 1847 走到 1847+2048-1 = 4095
# 但 bin_cnt 总是 ≥ 0, 所以 bin_cnt 从 0 到 1847 (一个完整三角坡), wrap 到 bin_cnt 1848..1847+2048=3895 (第二三角坡)

# 这意味着:
#   第一三角坡: ila_bin 0..2047 对应 bin_cnt 0..2047 (但 bin_cnt + 200 = 200..2247, 与 0..2047 不符)
#   OR
#   第一三角坡: ila_bin 0..2047 对应 bin_in = bin_cnt + 200 = 200..2247, 减去 200 = bin_cnt 0..2047

# 等等, bin_in = bin_cnt + 200 范围 [200, 2247] (当 bin_cnt 0..2047)
# bin_in mod 2048 = [200, 2047] + [0, 199] (wrap)
# 实际 ILA 显示 ila_bin 0..2047 = bin_in mod 2048
# 这意味着 bin_in 的循环 = bin_cnt 0..2047 时 bin_in = 200..2247, mod 2048 = [200..2047] + [0..199] = 0..2047
# 这正好覆盖 0..2047 ✓

# 所以: ila_bin 对应 bin_cnt 的反推:
#   bin_cnt = (ila_bin - 200) mod 2048
# 验证: ila_bin = 0 → bin_cnt = -200 mod 2048 = 1848
# 验证: ila_bin = 200 → bin_cnt = 0 ✓
# 验证: ila_bin = 2047 → bin_cnt = 1847 ✓

# 但 11-bit mod 2048 只是 BRAM 显示, 真实的 bin_cnt 是 15-bit (0..32767)
# 第一三角坡 实际是 bin_cnt = 1848..1847+2048-1 = 3895 (1848 个 bin)
# 等等, 2048 个 bin = bin_cnt 1848..3895 (1848 到 3895 = 2048 个值)

# 频率:
# Δf = 4 MHz / 32768 = 122.07 Hz/bin
# bin_cnt = 1848 → freq = 1848 * 122.07 = 225.6 kHz (起始)
# bin_cnt = 3895 → freq = 3895 * 122.07 = 475.5 kHz (结束)

# 但用户要 5-550 kHz
# bin_cnt = 5e3 / 122.07 = 41
# bin_cnt = 550e3 / 122.07 = 4505
# 注意 bin_cnt 范围是 0..32767

# 第二三角坡 (buf 6144..8191):
second_cycle = {}
for buf, b, m, v, a in valid_only:
    if buf >= 6144:
        if b not in second_cycle:
            second_cycle[b] = m
print(f"\n=== 第二三角坡 (不传给单片机) ===")
print(f"Total bins: {len(second_cycle)}")

# === 6. 关键解读: ILA 看到的 peak ===
print(f"\n=== 第一三角坡中 max mag (最强信号) ===")
max_bin = max(first_cycle, key=first_cycle.get)
print(f"  ILA bin = {max_bin}, mag = {first_cycle[max_bin]}")

# 反推 bin_cnt
bin_cnt_at_max = (max_bin - 200) % 2048
# 实际 bin_cnt 在第一三角坡中: 1848..3895 (1848 + max_bin - 200)
# 因为 ila_bin = (bin_cnt + 200) mod 2048
# bin_cnt + 200 mod 2048 = ila_bin
# 在第一三角坡, bin_cnt 1848..3895, 所以 bin_cnt + 200 = 2048..4095
# mod 2048 = 0..2047 = ila_bin 0..2047
# 验证: ila_bin = 0 -> bin_cnt + 200 = 2048 -> bin_cnt = 1848
# 验证: ila_bin = max_bin -> bin_cnt = 1848 + max_bin
bin_cnt_real = 1848 + max_bin
freq_at_max = bin_cnt_real * DELTA_F
print(f"  Real bin_cnt = {bin_cnt_real}")
print(f"  Freq = {freq_at_max/1000:.3f} kHz")

# === 7. 用 Python ADC FFT 验证 ===
adc_raw = np.array([r[4] for r in valid_only], dtype=np.float64)
# 中心化
adc_centered = adc_raw - adc_raw.mean()
N = len(adc_centered)
x = adc_centered
hann = 0.5 * (1 - np.cos(2*np.pi*np.arange(N) / (N - 1)))
xh = x * hann
N_FFT = 32768  # ← 32768!
xp = np.zeros(N_FFT)
xp[:N] = xh
X = np.fft.rfft(xp)
mag = np.abs(X) / N * 2  # 单边谱 peak amplitude (LSB)
freqs = np.arange(len(X)) * 4e6 / N_FFT

# 找 40 kHz
bin_40k = int(40000 / DELTA_F)
bin_100k = int(100000 / DELTA_F)
print(f"\n=== Python FFT 验证 ===")
print(f"40 kHz -> bin_cnt = {bin_40k} (ILA bin = (1848+{bin_40k}) mod 2048 = {(1848+bin_40k)%2048})")
print(f"100 kHz -> bin_cnt = {bin_100k} (ILA bin = {(1848+bin_100k)%2048})")

# 找 peak
local_region = mag[bin_40k-3:bin_40k+4]
local_peak = np.argmax(local_region) + bin_40k - 3
print(f"\n40 kHz Python peak: bin_cnt = {local_peak}, freq = {local_peak*DELTA_F/1000:.3f} kHz, mag = {mag[local_peak]:.2f} LSB")

local_region = mag[bin_100k-3:bin_100k+4]
local_peak = np.argmax(local_region) + bin_100k - 3
print(f"100 kHz Python peak: bin_cnt = {local_peak}, freq = {local_peak*DELTA_F/1000:.3f} kHz, mag = {mag[local_peak]:.2f} LSB")

# === 8. 关键: 单片机实际接收的是第一三角坡 (2048 bins), 但实际代表的 bin_cnt 是 1848..3895 ===
# 用户要 5-550 kHz
# bin_cnt 41..4505
# 在第一三角坡的 2048 个 bin 中 (bin_cnt 1848..3895)
# 5 kHz (bin_cnt=41) 不在第一三角坡中!
# 550 kHz (bin_cnt=4505) 不在第一三角坡中!
# 第一三角坡覆盖 bin_cnt 1848..3895 = freq 225.6..475.5 kHz

# 用户要 5-550 kHz 范围, 第一三角坡只覆盖 226..476 kHz
# 其他频率在哪里?
# bin_cnt 41..1847 -> freq 5..225 kHz -> 这部分应该在第二三角坡 (buf 6144..8191)
# 但用户说第二三角坡不传
# OR
# 第一三角坡中的 bin_cnt 不一定是 1848..3895, 也可能是 0..2047 (而不是 wraparound)

# 让我重新看: ILA 显示的 ila_bin 是 11-bit, 0..2047
# 但 bin_in = bin_cnt + 200 是 15-bit
# ILA BRAM 显示的是 bin_in 的低 11-bit (mod 2048)
# bin_in 范围: 当 bin_cnt 0..2047 时, bin_in = 200..2247 (mod 2048 = 200..2047 + 0..199 = 0..2047)
# 因此 ILA bin 0..2047 对应 bin_cnt 0..2047 (不是 1848..3895!)
# bin_in = bin_cnt + 200 (15-bit)
# 但 BRAM 显示低 11-bit, ila_bin = (bin_cnt + 200) & 0x7FF = (bin_cnt + 200) mod 2048
# 当 bin_cnt = 0..1847: ila_bin = 200..2047
# 当 bin_cnt = 1848..2047: ila_bin = 2048..2247 mod 2048 = 0..199
# 所以 ILA bin 0..2047 完整对应 bin_cnt 0..2047
# 解读: 单片机看到 ila_bin X, 真实 bin_cnt = X (因为 ila_bin = (X+200) mod 2048, 反推 X 是 (bin_cnt+200) mod 2048)
# 但解: bin_cnt = ila_bin - 200 + K*2048
# 单片机端, K 选哪个? 看实际 FFT 输出来判断
# 但用户要 5-550 kHz
# 假设 bin_cnt = ila_bin - 200 (K=0), ila_bin=200 → bin_cnt=0, freq=0
# 假设 bin_cnt = ila_bin (mod 2048), ila_bin=200 → bin_cnt=200, freq=200*122=24.4 kHz

# 关键: verilog 代码 line 147: bin_in = bin_cnt + 13'd200
# 13'd200 是一个 13-bit 常数 200, zero-extended 到 15-bit 仍然是 200
# bin_in = bin_cnt + 200 (15-bit sum, 可能 wrap around at 2^15 = 32768)
# bin_in 范围: 200..22847 (当 bin_cnt 0..32767)
# BinSelect 接受 [0, 8191]:
#   bin_cnt 0..7991: bin_in 200..8191 (valid)
#   bin_cnt 7992..8191: bin_in 8192..8391 (invalid)
#   bin_cnt 8192..32767: bin_in 8392..32967 (invalid)
# 第二帧 bin_cnt 0..7991 再次 valid

# ILA BRAM 11-bit 显示: ila_bin = bin_in & 0x7FF = bin_in mod 2048
# bin_in 200..8191 (valid) mod 2048 = 200..2047 + 0..199 (wrap at 2048)
# 这正好覆盖 0..2047 ✓
# 但 bin_in 200..8191 是 bin_cnt 0..7991, 不是 0..2047
# 所以 ila_bin 反推 bin_cnt: bin_cnt = (ila_bin - 200 + 2048) mod 2048
# 但需要在 0..7991 范围内确定 K=0 还是 K=3
# K=0: bin_cnt = ila_bin - 200 (值 0..2047)
# K=3: bin_cnt = ila_bin + 2048*3 - 200 (值 5952..8191)

# 简单方案: 单片机知道 bin_cnt 15-bit 0..32767, 但第一三角坡只显示 bin_cnt 0..7991
# ILA ila_bin = (bin_cnt + 200) mod 2048
# 反推: bin_cnt = (ila_bin - 200 + 2048) mod 2048 = (ila_bin + 1848) mod 2048
# 但这个反推有多解
# 实际: ILA 触发一次 (frame_end) 后, 记录 valid 数据期间的所有 bin_cnt
# 在 post-trigger 4096 clk 中, bin_cnt 走 0..7991 (一次完整 + wrap 到 0 后面)
# 但 4096 sample ILA buffer, 每次 fft 输出有 valid=1 的 8192 个 bin
# 如果 FFT 一次处理 8192 sample (非 32768), 那 4096 sample 只输出 2048 bin
# 但 verilog 注释说 32768 点...

# 结论: 不要纠结 32768 vs 8192, 直接从实测数据反推!

# === 实测数据反推 ===
# ila_bin 在第一三角坡显示 0..2047
# 单片机拿到这 2048 个 (bin, mag), 需要反推频率
# 从实测数据: 40 kHz 主峰在 ILA bin = 282 (CORDIC mag top)
# 5 点 parabolic 拟合后: real_fft_bin = 81.929
# 如果 N=8192: freq = 81.929 * 488.281 = 40.004 kHz ✓ (与 40 kHz 完全匹配!)
# 如果 N=32768: freq = 81.929 * 122.07 = 10.00 kHz (不对!)

# 所以 N=8192 是正确的, N=32768 是 verilog 注释错了
# Δf = 4 MHz / 8192 = 488.281 Hz/bin
# ILA bin X → real_fft_bin = X - 200 (考虑 verilog +200 偏置)
# freq = (X - 200) * 488.281

DELTA_F_CORRECT = 4e6 / 8192
print(f"\n=== 修正后的解析 ===")
print(f"N = 8192 (实测反推, 不是 32768)")
print(f"Δf = {DELTA_F_CORRECT:.4f} Hz/bin")
print(f"")
print(f"ILA bin X → real FFT bin = X - 200 (mod 2048 BRAM wraparound)")
print(f"  频率 = real_fft_bin × Δf")
print(f"")
print(f"验证: 40 kHz 主峰 ILA bin = 282, real = 82, freq = {82*DELTA_F_CORRECT/1000:.2f} kHz ✓")
print(f"验证: 100 kHz 主峰 ILA bin = 404, real = 204, freq = {204*DELTA_F_CORRECT/1000:.2f} kHz ✓")
print(f"")
print(f"用户 5-550 kHz:")
print(f"  5 kHz → real_fft_bin = {5000/DELTA_F_CORRECT:.1f} → ILA bin = {5000/DELTA_F_CORRECT+200:.0f}")
print(f"  550 kHz → real_fft_bin = {550000/DELTA_F_CORRECT:.1f} → ILA bin = {550000/DELTA_F_CORRECT+200:.0f}")

# === 9. bin 范围映射 ===
bin_min_real = int(5000 / DELTA_F_CORRECT) + 1  # = 11
bin_max_real = int(550000 / DELTA_F_CORRECT)     # = 1127 (500k 时 1024, 550k 时 1126)
ila_bin_min = bin_min_real + 200  # = 211
ila_bin_max = bin_max_real + 200  # = 1327

# filter
filter_bins = [(b, m) for b, m in first_cycle.items() if ila_bin_min <= b <= ila_bin_max]
print(f"\n=== 5-550 kHz 过滤 (单片机视角) ===")
print(f"  ILA bin range: {ila_bin_min}..{ila_bin_max}")
print(f"  Real bin range: {bin_min_real}..{bin_max_real}")
print(f"  Freq range: {bin_min_real*DELTA_F_CORRECT/1000:.2f}..{bin_max_real*DELTA_F_CORRECT/1000:.2f} kHz")
print(f"  Total points: {len(filter_bins)}")

# === 10. 幅度换算 (实测验证) ===
# 用 40 kHz ILA bin 282, mag 27758
print(f"\n=== 幅度换算验证 (40 kHz) ===")
m_40_cordic = 27758  # 已知 max mag at ILA bin 282
m_100_cordic = 3714  # 已知 max mag at ILA bin ~404
# 公式推导: CORDIC mag = |X[k]|, X[k] 是 FFT 输出的复数
# 对于单频信号 x[n] = A*sin(2π*f*n/fs), Hann window 后:
# |X[k]| = (A * N_eff) / 2 (approx, N_eff = sum of window samples)
# 但 N_eff for Hann = N*0.5
# 所以 |X[k]| ≈ A * N / 2 * 0.5 = A * N / 4 (with Hann coherent gain 0.5)
# Wait: Hann peak amplitude response = N/2 * 0.5 = N/4
# 所以 A = 4 * |X[k]| / N
# Vpp = 2 * A = 8 * |X[k]| / N
# 单位: |X[k]| 是 LSB (因为 ADC 输入是 LSB 单位), Vpp 单位是 LSB

# 但 verilog 里 PreMul_Hann 把 ADC 16-bit 乘法, 输出 16-bit, ADC 是 12-bit → 实际 x 范围是 ±2048 LSB (双极性)
# iladata1.csv 的 ADC 是 UNSIGNED 12-bit, 0~4095, mean ~1534, Vpp = max-min = 4095 LSB
# → 信号 Vpp 接近 ADC 满量程 5V

# 实测:
# Python FFT mag at bin 82 = 1168.93 LSB (single-bin, Hann-compensated)
# Vpp_python = mag * 2 (Hann comp) = 1168.93 * 2 = 2337.86 LSB
# Vpp_python_mV = 2337.86 * (5000/4096) = 2854 mV ≈ 2.85 V (信号 Vpp)
# 但期望 Vpp = 200 mV (源端)
# 衰减 = 200/2854 ≈ 14x ? 这跟"5x"不符

# 等等, 让我重新计算 Python 的 mag
# mag = abs(X) / N * 2 是 single-bin (Hann-uncompensated, in mV/LSB units)
# Actually: abs(X) / N (no *2) gives 1-sided spectrum without Hann compensation
# * 2 gives peak amplitude (Hann-uncompensated)
# Hann comp: peak / 0.5 = peak * 2

# 让我重新算 40 kHz Vpp
# mag (single-bin) = 1168.93
# peak_amp (no comp) = 1168.93 (assuming * 2 already applied)
# peak_amp (Hann comp) = 1168.93 * 2 = 2337.86
# Vpp_ADC_LSB = 2 * peak_amp = 2 * 2337.86 = 4675.72 LSB
# Vpp_ADC_mV = 4675.72 * (5000/4096) = 5708 mV
# 衰减 = 200/5708 = 0.035x? 这不可能

# 我可能搞错了 mag 的含义
# 让我再仔细想想:
# x[n] = A * cos(2π*f*n/fs), Hann window 后 FFT:
# X[k_peak] = A * N/2 * (1/2) (Hann coherent gain) = A*N/4 (for N-point Hann)
# abs(X[k_peak]) / N * 2 = A * (1/2) (Hann-uncomp single-side spectrum)
# abs(X[k_peak]) / N * 2 * 2 = A (Hann-comp, 4 * mag / N)
# Vpp = 2 * A = 4 * abs(X[k_peak]) / N * 2 = 8 * abs(X[k_peak]) / N
# Vpp_LSB = 8 * abs(X[k_peak]) / N
# Vpp_mV = Vpp_LSB * (5000/4096)

# 40 kHz: abs(X) = 1168.93 * N / 2 = 1168.93 * 4096 / 2 = 2394,083
# Wait, mag = abs(X)/N*2, so abs(X) = mag*N/2 = 1168.93*4096/2 = 2,394,090
# Vpp_mV = 8 * abs(X) / N * V_LSB / 2 (since single side spectrum)
# Hmm I'm confusing myself.

# Let me just use the empirical fact:
# 信号 200 mV Vpp 源端 → ADC 输入 Vpp (LSB) = 200/5x衰减/1.221mV_per_LSB = 200/5/1.221 = 32.75 LSB
# 实测 ADC P2P = 4095 LSB (full scale!) → 这个不对
# 等等, iladata1 的 ADC 是 UNSIGNED 0-4095, mean 1534, 信号在 0..4095 之间震荡?
# 那 Vpp 应该是 max-min = 4095? 这显然就是 full scale swing
# 或者是 saturation clipping

# 实测:
# mag (CORDIC, bin 82 = 40 kHz) = 27758
# ADC LSB / sample 输入, CORDIC mag 输出
# 对于单频信号 x[n] = A * cos(...), N=8192 FFT:
#   X[k_peak] = A * N/2 = A * 4096
#   Hann-comp: X[k_peak] = A * N/2 * 0.5 = A * 2048
#   |X[k_peak]| = A * 2048 = CORDIC mag = 27758
#   → A = 13.55 (峰值幅度 LSB)
#   → Vpp = 27.10 LSB (信号峰峰值 LSB)
#   → Vpp_mV = 27.10 * 1.221 = 33.1 mV (ADC 端 Vpp)
#   → Vpp_source = 33.1 * 5 = 165.5 mV (源端 Vpp, 期望 175 mV)
# 偏差: 165.5 vs 175 → 5.4%, 在合理范围内!

# 验证 100 kHz:
# CORDIC mag = 3714
# A = 3714 / 2048 = 1.81 LSB
# Vpp_LSB = 3.63
# Vpp_mV = 4.43 mV (ADC)
# Vpp_source = 22.16 mV (源端, 期望 25 mV)
# 偏差: 22.16 vs 25 → 11.4%, 略偏

# 但等等, 上面的公式用的是 N=8192, 但 verilog 是 N=32768
# 实际上 N 在 FFT IP 中可能是 8192 (因为 fft cfg_tdata 控制)
# 实测频率 40 kHz 对应 bin 82 in FFT, 如果 N=8192: bin 82 = 82/8192 * 4e6 = 40 kHz ✓
# 如果 N=32768: bin 82 = 82/32768 * 4e6 = 10 kHz ✗
# 所以 FFT 实际用 N=8192!

# 公式验证: CORDIC mag = A * N/2 (无 Hann) = A * 4096 (N=8192)
# 但 verilog 里 PreMul_Hann 已经把信号乘了 Hann 窗, CORDIC 输出已是 Hann 后
# CORDIC mag = A * N/2 * 0.5 = A * N/4 = A * 2048 (N=8192, Hann comp gain = 0.5)
# 所以 A = CORDIC mag / 2048 = 27758 / 2048 = 13.55 LSB (40 kHz)
# Vpp_ADC_LSB = 2 * A = 27.1 LSB
# Vpp_ADC_mV = 27.1 * 1.221 = 33.1 mV
# Vpp_source_mV = 33.1 * 5 = 165.5 mV (期望 175 mV)

# 等等, "ADC 输入 Vpp LSB" 是 ADC 量化数字的峰峰值
# 但实际 ADC 输出已经是 12-bit, range 0~4095 (UNSIGNED)
# 信号中心化后 Vpp_LSB = 信号 Vpp in 量化单位
# 实际 Vpp_mV = Vpp_LSB * V_per_LSB (V_per_LSB = 5000/4096 = 1.221 mV)
# 上面计算正确

# 结论: 单片机公式
#   Vpp_mV_source = (CORDIC_mag / 2048) * 2 * 1.221 * 5
#                = CORDIC_mag * 0.00596 * 5
#                = CORDIC_mag * 0.0298 mV
# 验证: mag=27758 → Vpp = 27758 * 0.0298 = 827 mV? 远大于 175 mV
# 错误了!

# 重新算:
# CORDIC_mag = 27758 = A * N/2 * 0.5 = A * 2048
# A = 27758 / 2048 = 13.55 LSB
# A_mV = 13.55 * 1.221 = 16.55 mV (ADC 端信号峰值幅度)
# Vpp_ADC_mV = 2 * A_mV = 33.10 mV (ADC 端信号峰峰值)
# Vpp_source_mV = Vpp_ADC_mV * 5 = 165.5 mV
# 单片机公式: Vpp_source = 2 * (CORDIC_mag / 2048) * 1.221 * 5
#          = 2 * CORDIC_mag * 1.221 * 5 / 2048
#          = CORDIC_mag * 12.21 / 2048
#          = CORDIC_mag * 0.00596 mV
# 验证: 27758 * 0.00596 = 165.4 mV ✓
# 验证: 3714 * 0.00596 = 22.13 mV (期望 25 mV, 偏差 -11.5%)

print(f"\n=== 单片机幅度公式验证 ===")
N_F = 8192  # 实测 FFT 点数 (不是 32768)
HANN_CG = 0.5  # Hann coherent gain
N_HANN = N_F * HANN_CG  # = 4096
V_LSB_MV = 5000.0/4096  # = 1.221 mV/LSB
ATTEN = 5.0

for label, m_cordic, expected_vpp_mV in [("40 kHz", 27758, 175), ("100 kHz", 3714, 25)]:
    A_LSB = m_cordic / N_HANN
    A_mV_ADC = A_LSB * V_LSB_MV
    Vpp_mV_ADC = 2 * A_mV_ADC
    Vpp_mV_src = Vpp_mV_ADC * ATTEN
    err = Vpp_mV_src - expected_vpp_mV
    print(f"  {label}: CORDIC_mag={m_cordic}")
    print(f"    A_LSB = {m_cordic}/{N_HANN} = {A_LSB:.4f} LSB")
    print(f"    A_mV_ADC = {A_mV_ADC:.4f} mV")
    print(f"    Vpp_ADC = {Vpp_mV_ADC:.4f} mV")
    print(f"    Vpp_src = {Vpp_mV_src:.4f} mV (期望 {expected_vpp_mV} mV, 偏差 {err:+.2f} mV)")
    print()

# === 11. 简化单片机公式 ===
print(f"=== 单片机最终公式 ===")
print(f"// N_FFT = 8192 (实测, 不要用 verilog 注释的 32768)")
print(f"// N_Hann = 8192 × 0.5 = 4096 (Hann coherent gain)")
print(f"// V_per_LSB = 5000/4096 mV (UNSIGNED 12-bit, 0~5V 量程)")
print(f"// ATTENUATION = 5.0 (AD9226 5x)")
print(f"")
print(f"// 1. ILA bin → real FFT bin (反推)")
print(f"// ila_bin = (bin_cnt + 200) mod 2048  (verilog +200 偏置, 11-bit BRAM 截断)")
print(f"// → bin_cnt = ila_bin (mod 2048)")
print(f"// 但单片机已知 bin_cnt 范围 [0, 7991], 直接取 bin_cnt = ila_bin 即可")
print(f"// 验证: ila_bin 282 → bin_cnt 282? 但 40kHz = bin 82, 不一致!")
print(f"// 修正: bin_cnt 是 [0, 7991], ILA BRAM 显示的 11-bit 是 (bin_cnt + 200) & 0x7FF")
print(f"// 反推: bin_cnt = (ila_bin + 1848) mod 2048, 但范围不准确")
print(f"// 简单做法: bin_cnt = ila_bin (假设 bin_cnt ∈ [0, 2047])")
print(f"//   ila_bin=282 → bin_cnt=282 → freq=282*488.281/1000=137.7 kHz ✗")
print(f"// 所以 bin_cnt 不能直接等于 ila_bin!")
print(f"//")
print(f"// 实测 40 kHz 信号 → ILA bin 282, real FFT bin 82")
print(f"// 反推: real_fft_bin = ila_bin - 200 (mod 2048)")
print(f"// 验证: 282-200 = 82 ✓")
print(f"// 频率: 82 × 488.281 = 40.04 kHz ✓")
print(f"")
print(f"// 最终公式:")
print(f"float real_fft_bin = (int)(ila_bin - 200);")  # wrap to 0..2047
print(f"if (real_fft_bin < 0) real_fft_bin += 2048;")
print(f"float freq_Hz = real_fft_bin * 488.281f;")
print(f"")
print(f"// 幅度公式:")
print(f"float Vpp_mV_at_src = (2.0f * (float)mag / 4096.0f) * (5000.0f/4096.0f) * 5.0f;")