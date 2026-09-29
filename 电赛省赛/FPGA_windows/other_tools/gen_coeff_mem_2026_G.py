#!/usr/bin/env python3
"""
gen_coeff_mem_2026_G.py
-----------------------
为 GoertzelBank.v 预生成 CoeffBank.mem (2560 项 2*cos(2πk/N), Q1.15)
和 verify_coeff.py 反解 Re/Im 时的解析对比值.

公式:
    coeff[k] = 2 * cos(2π k / N_FRAME),   k = 0..2559, N_FRAME = 10240
    范围 [-2, +2],  16-bit Q1.15 表示 [-1, +1) 范围 → 直接存储时会饱和,
    因此存储为 round(coeff * 32767 / 2) * 2, 即
        coeff_q15 = round(coeff * 32767)
    这样 result 实际范围 [-2*32767, +2*32767] = [-65534, +65534]
    在 cell 内乘法器是 16 x 28 = 44-bit, 自然处理.
"""

import math, os, argparse

N_FRAME = 10240
N_BIN   = 2560
DEFAULT_OUT = r"C:\Users\24307\Desktop\FPGA_windows\Vivado\verliog\A0_1\A0_1.srcs\sources_1\imports\A0_1"

def s15_hex(v: int) -> str:
    if v < 0: v = (v + 65536) & 0xFFFF
    return f"{v:04X}"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=DEFAULT_OUT)
    args = p.parse_args()
    os.makedirs(args.out, exist_ok=True)

    out_path = os.path.join(args.out, "CoeffBank.mem")
    with open(out_path, "w", encoding="utf-8") as fp:
        for k in range(N_BIN):
            coeff = 2.0 * math.cos(2.0 * math.pi * k / N_FRAME)
            v = int(round(coeff * 32767.0))
            v = max(-32768, min(32767, v))
            fp.write(s15_hex(v) + "\n")
        fp.write("// end of CoeffBank\n")
    print(f"[OK] CoeffBank.mem written: {N_BIN} x 16-bit hex")

if __name__ == "__main__":
    main()
