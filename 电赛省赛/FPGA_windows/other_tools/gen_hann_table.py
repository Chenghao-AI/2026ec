#!/usr/bin/env python3
"""
gen_hann_table.py
生成 HannTable.v 中需要的 10240 项 12-bit Q0.12 汉宁窗系数.

Hann 窗: w[n] = 0.5 * (1 - cos(2π n / (N-1))), n = 0..N-1, N = 10240
Q0.12 定点: round(w * 2^12), 范围 [0, 4095] (因为 w ∈ [0,1])

输出: vivado_mem_init / coe 文件均可直接 $readmemh 加载.

用法:
  python gen_hann_table.py
  -> 在同目录生成 hann_table.mem (一行一个 12-bit 十六进制数)
"""
import math
import os

N = 10240
SCALE = 4096.0  # 2^12

def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    mem_path = os.path.join(out_dir, "hann_table.mem")
    coe_path = os.path.join(out_dir, "hann_table.coe")

    mem_lines = []
    coe_lines = []
    coe_lines.append("; Hann window N=10240, 12-bit Q0.12")
    coe_lines.append("memory_initialization_radix=16;")
    coe_lines.append("memory_initialization_vector=")

    for n in range(N):
        # 严格对称: w[0]=w[N-1]=0, w[N/2]=1
        w = 0.5 * (1.0 - math.cos(2.0 * math.pi * n / (N - 1)))
        q = int(round(w * (SCALE - 1)))  # 用 SCALE-1 保证最大值 < 4096
        if q < 0:
            q = 0
        if q > 4095:
            q = 4095
        hex_str = f"{q:03X}"
        mem_lines.append(hex_str)
        if n < N - 1:
            coe_lines.append(hex_str + ",")
        else:
            coe_lines.append(hex_str + ";")

    with open(mem_path, "w") as f:
        f.write("\n".join(mem_lines) + "\n")
    print(f"wrote {mem_path} ({N} entries)")

    with open(coe_path, "w") as f:
        f.write("\n".join(coe_lines) + "\n")
    print(f"wrote {coe_path}")

    # 抽样打印
    sample_idx = [0, 1, N//4, N//2, N-2, N-1]
    for i in sample_idx:
        q = int(round((0.5 * (1.0 - math.cos(2.0 * math.pi * i / (N - 1)))) * (SCALE - 1)))
        print(f"  w[{i:5d}] = {0.5*(1.0-math.cos(2.0*math.pi*i/(N-1))):.6f} -> 0x{q:03X}")

if __name__ == "__main__":
    main()
