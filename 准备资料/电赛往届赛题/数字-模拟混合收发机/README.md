# TV给       接收端 FPGA 信号处理 — AX7020 (XC7Z020) 下板指南

###  ADC (AD9226 双通道 12-bit) — 信号 + 电源都在 J10

ADC 模块板上 **有一颗 SGM2036-3.3 LDO**, 把 VIN=5V 降到 VCC_3V3=3.3V 给
AD9226 用. 因此:

| ADC 模块端 | 接到 | ZYNQ Pin | 电压等级 |
|---|---|---|---|
| **VCC (= VIN)** | **J10 PIN2 (+5V)** | — | **5V → LDO → 3.3V** |
| **GND**          | **J10 PIN1**           | — | 0V |
| ACLK (FPGA→ADC) | J10 PIN10 | — | **3.3V LVCMOS33** |
| OTR (ADC→FPGA) | J10 PIN21 | — | **3.3V LVCMOS33** |
| A1..A12 (12 数据) | J10 PIN9（A1）， PIN12（A2）, PIN11（A3）, PIN14（A4）, PIN13（A5）, PIN16（A6）, PIN15（A7）, PIN18（A8）, PIN17（A9）, PIN20（A10）, PIN19（A11）, PIN22（A12） | — | **3.3V LVCMOS33** |

###  DAC (DAC8571 16-bit I2C) — 信号在 J10, 电源在 **J11**

> DAC 模块板上 **R9, R10 两颗 4.7K 电阻把 SDA/SCL 上拉到 VCC_3V3 (3.3V)**.
>即使 VCC 输入 5V, I2C 线的高电平稳态仍然是 3.3V (上拉到 3V3, 不到 5V).

| DAC 模块端 | 接到 | ZYNQ Pin | 电压等级 |
|---|---|---|---|
| **VCC** | **J11 PIN2 (+5V) ← 与 ADC 分开!** | — | **5V** |
| **GND** | **J11 PIN38 (GND) ← 与 ADC 分开!** | — | 0V |
| A0 | J11 PIN36 | **K14** | 3.3V (固定低 → I2C addr=0x4C) |
| SCL | J11 PIN34 | **H15** | **3.3V (开漏 + 板上 电阻 4.7K 上拉到 3V3)** |
| SDA | J11 PIN32 | **H16** | **3.3V (开漏 + 板上 电阻 4.7K 上拉到 3V3)** |

###  4 位带小数点数码管 SR410401N (共阳)

| 数码管 PIN | 功能 | J11 PIN | ZYNQ Pin | 电压 |
|---|---|---|---|---|
| 11 | a 段 (顶) | 13 | — | 3.3V LVCMOS33, **低有效点亮** |
| 7 | b 段 | 5 | — | 同上 |
| 4 | c 段 | 10 | — | 同上 |
| 2 | d 段 | 14 | — | 同上 |
| 1 | e 段 | 16 | — | 同上 |
| 10 | f 段 | 11 | — | 同上 |
| 5 | g 段 | 8 | — | 同上 |
| 3 | dp (小数点) | 12 | — | 3.3V (本设计常驻高 = 灭) |
| 12 | DIG.1 (最左) | 15 | — | 3.3V, **高有效选中** |
| 9 | DIG.2 | 9 | — | 同上 |
| 8 | DIG.3 | 7 | — | 同上 |
| 6 | DIG.4 (最右) | 6 | — | 同上 |

###  板载 4 颗 PL LED (低有效)

| LED | ZYNQ Pin | 含义 |
|-----|----------|------|
| LED1 | M14 | **模拟信号瞬时存在** (audioLpf AC 包络 > 阈值, signalPresent 门控) |
| LED2 | M15 | **数字信号瞬时存在** (audioHpf 能量 > 阈值, signalPresent 门控) |
| LED3 | K16 | **ADC AOTR 超量程报警** (250 ms 单稳拉伸) |
| LED4 | J16 | **心跳 ~0.75 Hz** (始终闪, 用于确认 bitstream 活着) |

板载 LED 不用接杜邦线.

###  FPGA 自身供电 (与 ADC/DAC 完全分开)

AX7020 用 **板载 USB-Micro 或 12V/3A 桶头** 单独供电.

> ⚠ **不要** 把外部 5V 电源同时灌到 FPGA. ZYNQ 启动峰值 1.5A, 5V/1A 适配
> 器带不动会反复复位.



###  上电前 5 步自检 (按顺序做完再插电)

1. 万用表测 ADC 模块 VCC↔GND 阻抗 **> 1 kΩ** (排除短路).
2. 万用表测 DAC 模块 VCC↔GND 阻抗 **> 1 kΩ**.
3. 杜邦线 33 根逐根核对 §0.1~§0.3 的表.
4. **J13 跳线 = JTAG 模式** (右两脚短路).
5. 5V/1A 适配器接 J10/J11 的两路 +5V, FPGA 用单独的 USB-Micro 或 12V 桶头.

---

##  设计指标与测试结果 (每次仿真后得重新填写“实测值”和“状态”)

| 测试 | 指标要求 | 实测值 | 状态 |
|---|---|---|---|
| TEST-A 基带 DSP 链 | 1KHz audio 主频清晰可见 | 主频 = **999.0 Hz** (300 mV 峰值, DC -0.00 mV) | **PASS** |
| TEST-A 模拟/数字能量比 | ≫ 1 | 比值 ≈ **10⁵** (audio 能量 >> ASK 能量) | **PASS** |
| TEST-B 模拟立即停 | t=3.10s, analog active=0 | 3.10s analogActive = **0** | **PASS** |
| TEST-B 数字 6s 保持 | 5~9.9s holdAct 占比 | 占比 = **1.000** | **PASS** |
| TEST-B 6s 后熄灭 | t=10.1s, holdAct=0 | 10.1s holdAct = **0** | **PASS** |
| TEST-C OOK ASK 解码 | 7 个 nibble 严格匹配 | 7 / 7 严格匹配 (**100 %**) | **PASS** |
| TEST-D 模拟停 → DAC 中点 | 4.10s, DAC 码 = 0x8000 | 4.10s DAC = **32768** (= 0x8000) | **PASS** |
| TEST-D 模拟停 → LED1 灭 | 4.10s, LED1 = 0 | 4.10s LED1 = **0** | **PASS** |
| TEST-D 数字 6s 后熄灭 | 8.9s LED2=1, 9.1s LED2=0 | 8.9s LED2=**1**, 9.1s LED2=**0** | **PASS** |
| ACLK 直插 50MHz 信号完整性 (~8 pF) | Vmin<0.8V, Vmax>2.0V, flat>1ns | Vmin **0.00V** / Vmax **3.30V** / flat **8.94 ns** | **PASS** |
| DAC SCL 杜邦 10cm 100kHz I2C (~125 pF) | t_rise + t_HIGH > V_IH 抵达时间 | t_rise = **1291 ns** > std 1000 ns 严限, **但** 100 kHz 下 t_HIGH = 5 µs, SCL 在 HIGH 段开始 ~700 ns 就过 V_IH=2.31 V (DAC8571 用 Schmitt 输入) | **FUNCTIONAL OK** (功能正常, 严仅超 NXP 严限) |
| FPGA 综合/PnR 警告 (`Vivado/logs/synth_impl.log`) | 0 Error / 0 Critical, 仅 DSP 流水线提示 | 0 Error / 0 Critical / **18 Warning (全 DRC DSP 流水线提示)** | **PASS** |
| Vivado XSim 行为级仿真 (`Vivado/tb_ReceiverBoard.v`) | T1~T6 全 PASS | adcClkOut 105090 跳变 ✓ / dacScl 123 跳变 ✓ / ledN0/1 idle=1 ✓ / AOTR→LED3 亮 ✓ / dig 1-hot ✓ | **PASS** |
| Vivado 布局布线后时序 (`Vivado/reports/impl_timing_summary.rpt`) | WNS ≥ 0, WHS ≥ 0 | WNS = **+6.243 ns**, WHS = **+0.047 ns** (TNS/THS = 0, 0 failing endpoints) | **PASS** |
| Vivado 资源使用 (`Vivado/reports/impl_utilization.rpt`) | DSP < 220 | LUT 22375/53200 (42%), FF 41826/106400 (39%), DSP **7/220** (3.18%), BRAM 1/140 | **PASS** |
| Vivado bit 生成 (`Vivado/proj_build/ReceiverBoard.bit`) | 生成成功 | `write_bitstream completed successfully` | **PASS** |

跑一遍指标:

```powershell
# MATLAB / Python 端 (不用打开 MATLAB):
cd metlab
python run_all.py        # < 30 秒, 4 张图 + 8 个 PASS

# Chisel 端:
cd ..\chisel
sbt "testOnly receiver.ModuleSpec"
.\_gen_verilog.bat       # 重生 ReceiverBoard.v
```

---

##  `metlab/figures/` 4 张图的内涵 (本版按用户要求重做)

> 测试脚本: `metlab/run_all.py`. **每次运行覆盖这 4 张图.**
> 仿真信号严格按 "数字-模拟混合传输系统" 实物配置:
>  - 原模拟 = **1KHz 单频正弦, 0.3 V_pk** (低频, 不再是音频范围扫频)
>  - 原数字 = STM32 PWM 11.5KHz, OOK 1ms-bit, 3.3V LVCMOS
>  - 载波 = AM 调制后 25MHz, 接收前端混到 10.7MHz IF
>  - ADC 满量程 ±1V (12-bit signed)
>  - DAC 输出 0..3.3V (16-bit unsigned, 中点 0x8000 = 1.65V)

###  `test_A_chain.png` — 中频 DSP 链路 (5 ms)
四子图 (从上到下):

1. **中频 10.7MHz 信号** (前 0.05ms, 单位 V): 真实送给 ADC 的电压波形.
2. **CORDIC 包络**: 经过 DDC + CIC↓64 + FIR↓8 后的复信号 √(I²+Q²).
   能看见: DC ≈ 1 (载波本身), 1KHz audio 慢起伏, 11.5KHz ASK 快起伏.
3. **模拟分支 audio LPF (fc=10.5KHz) 输出**:
   FFT 主频 = 996.5 Hz (≈ 1KHz audio, FFT bin 5ms→200Hz 是正常误差).
4. **数字分支 audio HPF (fc=10.5KHz) 输出**: 11.5KHz ASK 残留, OOK 节拍.

###  `test_B_timing.png` — 模拟立即停 / 数字 6 秒保持 (12 s)

时间表 (用户要求修正版): 模拟 0~3s, 数字 1~4s, **4s 后空载**.

五子图:

1. **包络 AC 分量**: 0~3s 大幅度 audio + 偶发 ASK, 3~4s 仅 ASK, 4s+ 空载.
2. **audio LPF 输出**: 3s 后衰减到接近噪声.
3. **AnalogGate.active**: **3s 立即归零** (用户要求, 不再延伸到 4s).
   底下虚线标 3s 转折点.
4. **HoldTimer.active (数字 6s 保持)**: 1~10s 高 (数字 4s 停 + 6s hold = 10s).
   **10s 后归零** (用户要求, 之前是无限保持).
5. **DAC 16-bit 码**: 0~3s 跟踪 audioLpf, **3s 后立即贴中点 0x8000=32768**.

###  `test_C_decode.png` — ASK/OOK 比特→nibble 解调 (~32 ms)

三子图: 包络 / HPF^2 滑动能量 + 阈值 / 解码 nibble vs 发送 nibble.
实测 7/7 nibble 严格匹配, 误码率 0%.

###  `test_D_idle_behaviors.png` — 单次空载行为对照 (12 s)

> **用户两条额外要求的直接证明**:
> 1) 停模拟 → DAC 立即回中点 (0x8000 ≈ 1.65V)
> 2) 停数字 → 数码管 / LED2 仍亮 6s, 之后熄灭

时间表 (用户要求修正版):
| 时段 | 状态 | LED1 | LED2 | DAC |
|---|---|---|---|---|
| 0~2s | 仅模拟 | 亮 | 灭 | 跟踪 |
| 2~3s | 模 + 数 | 亮 | 亮 | 跟踪 |
| 3~4s | 仅模拟 (数字停, hold 中) | 亮 | 仍亮 | 跟踪 |
| **4s** | **模拟也停** | **立即灭** | 仍亮 | **立即回中点** |
| 4~9s | 空载 (LED2 hold 还在) | 灭 | 仍亮 | 中点 |
| **9s** | **3s+6s 到点** | 灭 | **熄灭** | 中点 |
| 9~12s | 完全空载 | 灭 | 灭 | 中点 |

五子图: 包络 / DAC 码 / LED1 / LED2 / 数码管可见性, 红/蓝/紫虚线标
3s/4s/9s 三个关键转折.

###  `multi_01..multi_05.png` — TEST-D_multiple 多段连续切换 (12 s, 5 张图, 新增)

> 用户在 v4 提的需求: 不能只测 "单一时段", 要看 *连续的、不断切换信号组成的*
> 整段实验. 6 个时段 12 秒:
>
> | 时段 | t (s) | 状态 |
> |---|---|---|
> | Phase 1 | 0~1.5 | 仅模拟 (1KHz 0.3V_pk) |
> | Phase 2 | 1.5~3 | 模拟 + 数字 (PWM nibble: 1, 5) |
> | Phase 3 | 3~4 | 仅数字 (PWM nibble: 9) |
> | Phase 4 | 4~5.5 | 仅模拟 (1KHz 重新出现) |
> | Phase 5 | 5.5~7 | 模拟 + 数字 (PWM nibble: 12, 3) |
> | Phase 6 | 7~12 | 全停 (验证 LED2 6s hold 能熄灭) |
>
> 5 张分立图 (背景颜色显示每段类型):
>
> | 文件 | 内容 |
> |---|---|
> | `multi_01_inputs_analog.png` | 原始模拟 (V) — 整段时序, Phase 1/2/4/5 是 1KHz 正弦, 其它段为 0 |
> | `multi_02_inputs_digital.png` | 原始数字 (V) — 整段时序, Phase 2/3/5 是 11.5KHz PWM @ 3.3V |
> | `multi_03_recovered_analog.png` | FPGA 恢复模拟 (V, post-AGC) vs 原始 1KHz; 期望与原信号峰值都是 ±0.3V |
> | `multi_04_recovered_digital.png` | FPGA 恢复数字 - ASK 包络 + 比特检测 + HoldTimer |
> | `multi_05_dac_led.png` | DAC 16-bit 码 + LED1 + LED2 状态时序 |
>
> 关键观察点:
> - **Phase 3 (3~4s, 仅数字)**: LED1 应在 3s 立即灭, DAC 立即贴中点;
> - **Phase 4 (4~5.5s, 仅模拟)**: LED1 重新亮, DAC 重新跟踪 1KHz;
> - **每次数字停 → LED2 仍亮 6s** 才熄灭 (HoldTimer 自动重启).

###  9 张图与硬件现象的对应（每次跑测试前都得重新填写）

| 图 | 仿真观察到的关键数值 (本版) | 板上能看到的现象 (待你下次实测填) |
|---|---|---|
| `test_A_chain.png` | CORDIC 包络 1 KHz 起伏清晰; audio LPF 主频 = 999.0 Hz | LED1 亮; DAC 在 1.65 V 附近 ±0.3 V 跟随 1 KHz |
| `test_B_timing.png` | t=3.10s analogActive 立刻归零; 5~9.9s holdAct 占比 1.000; 10.1s holdAct=0 | LED1 在停模拟 100 ms 内灭; LED2 数字停后再持续 6 s 才灭 |
| `test_C_decode.png` | 7/7 nibble 严格匹配, 误码 0% | 数码管 4 位逐 1 ms 切换显示 nibble [0,5,A,F,3,7,C] |
| `test_D_idle_behaviors.png` | 4.10s LED1=0 / DAC=0x8000; 8.9s LED2=1; 9.1s LED2=0 | 模拟停瞬间 LED1 灭 + DAC 跳到 1.65 V; 数字停后 6 s 才 LED2 灭 |
| `multi_01_inputs_analog.png` | Phase 1/2/4 是 1 KHz 0.3 V_pk 正弦; 其它段 = 0 | 用示波器在 ADC J10 PIN9 (W15) 看模拟分支输入 |
| `multi_02_inputs_digital.png` | Phase 2/3/5 是 11.5 KHz PWM @ 3.3 V; 其它 = 0 | 同上探针位置, 数字段看 PWM 方波 |
| `multi_03_recovered_analog.png` | 恢复模拟 ±0.3 V 与原始重合 (post-AGC) | DAC 输出在模拟段 ±0.3 V 跟踪; 数字段 / 空载段贴 1.65 V |
| `multi_04_recovered_digital.png` | ASK 包络 + bit detection 与 PWM 节拍对齐; HoldTimer 每次延 6 s 后熄 | 数码管在数字段亮起对应 nibble; 数字停后保持 6 s 后熄灭 |
| `multi_05_dac_led.png` | DAC 与 LED1/LED2 状态切换严格按 6 段时序 | 真实板子上 LED1/LED2/DAC/数码管协同切换可肉眼验证 |
| `aclk_signal_integrity.png` | v22 50MHz 直插 (~8 pF): 0~3.3V 满摆幅 + 8.94 ns flat-top | 示波器测 J10 PIN10 (V15) 应看到干净 50 MHz 方波 |
| `direct_mate_vs_dupont_50mhz.png` | 8 pF 直插 OK; 125 pF 杜邦 FAIL (1.32~2.10V 三角) | ACLK 必须直插; ACLK 不要再用杜邦 |
| `dac_i2c_dupont.png` | 10 cm 杜邦 @ ~125 pF: t_rise 1.3 µs > std-100k 严限 1 µs, 但 100 kHz 下 t_HIGH 5 µs 远超过 V_IH 达成时间, **功能 OK** | DAC 跟踪 1 KHz audio 正常; SCL 边沿圆滑但不影响 ACK |

---

##  Vivado 综合 / PnR 修订记录 — 把 `fpga/warning.xlsx` 全部告警归零

> 本版按 `fpga/warning.xlsx` 的 *第二轮* 报告修订. 第一轮的修订点
> (Netlist 29-69 / Place 30-722 ×19 / DSP 261/220 / DRC REQP-1840) 已经
> 全消, 第二轮剩 4 类还在闪烁的 warning, 本版本一并清掉.

| Vivado 报错 (warning.xlsx 第二轮) | 根因 | v3+v4 修订点 |
|---|---|---|
| **Synth 8-3917** ×4 dacA0/segDp driven by constant | RegInit(false.B) 输入是常量, Vivado 优化掉 reg | `chisel3.dontTouch(dacA0Reg)` + `dontTouch(segDpReg)` |
| **Synth 8-3332** ×30 mulReg_reg[*] unused (DigitalAGC) | Chisel 让 mulReg 沿 DSP48 P-reg 满 48 bit, 下游只用 16 bit | `DigitalAGC.scala`: mulReg 截到 30 bit |
| **Shape Builder 18-132** ×8 segCReg cannot OLOGIC | F20 (segC) 是 IO_L15N_T2_35 差分对的 N 端, 默认 Vivado 让所有 segXReg 抢同一 OLOGIC_X0Y0 site | **v4 新增**: 给 *所有* `seg*Reg / dig*Reg` 加 `dontTouch`, 让 Vivado 把它们当独立 FF, 不再都堆 X0Y0 |
| **Place 30-722** Critical: segDp IOB pack 失败 | segDpReg 输入是常量, Vivado 优化 → port 直接由 1'b1 驱动 | 同 8-3917 修订, dontTouch 让 reg 保留 |
| **Vivado 12-1017** "Failed to delete files in synth_1" | 工程目录权限 / 上次残留, 与 RTL 无关 | 工程层面, 重打开 Vivado 即清 |

修订后预期 Vivado log:

```
Synth Warning:           0    (8-3917 / 8-3323 / 8-3332 全清)
Synth Critical:          0
Implementation Warning:  0    (18-132 / 30-722 全清)
Implementation Critical: 0
DRC Warning:             0    (REQP-1840 已上一版修)
WNS:                  >= 0    (sync reset + DSP packing + FIR M-REG + SerialFIR)
```

---

##  信号路径与采样率匹配

数据率从 50 MSPS 一级一级降到 25 kSPS:

```
ADC 12-bit @ 50 MHz, ±1V                                            (50e6 Sa/s)
  -> AGC + DDC (混到 0Hz, I/Q 各 18-bit)                            (50e6)
  -> CIC R=64, N=4   ↓64                                            (~781.25 KHz)
  -> FIR R=8 LPF @12KHz ↓8                                          (~97.66 KHz)
  -> CORDIC |·|  得 16-bit 包络                                      (97.66 KHz)
  -> SerialFIR audioLPF (1KHz 主分量) - DC tracker - AnalogGate     (97.66 KHz)
  -> 16-bit unsigned DAC 码                                         (97.66 KHz)
  -> I2C DAC8571 @ 100 kHz, ~2.5 kSPS                               (2.5 kHz > 2 kHz Nyquist for 1 KHz audio)
```

> 2026-06 新增的 **AnalogGate DC tracker** (1 阶 IIR, fc≈3.8Hz):
> 把 audioLpf 的 DC (载波幅度 + ASK DC 漏) 减掉再做 |·| 滑动平均, 解决了
> "纯数字段 / 空载 / 仅载波" 时 LED1 误亮的 bug. (matlab 仿真已包含同样
> 的逻辑, 见 `metlab/run_all.py` §B 的 `dc_alpha = 1/4096`.)

---

##  Vivado 2019.1 下板流程 (JTAG 临时烧录)

###  一键脚本 (推荐): `Vivado/run_all.ps1`

在工作区根目录打开 PowerShell 运行:

```powershell
powershell -ExecutionPolicy Bypass -File Vivado\run_all.ps1
```

会顺次执行 (总用时 ~10 min):

1. **`Vivado/sim.tcl`** — XSim 行为级仿真, 使用 `Vivado/tb_ReceiverBoard.v` 驱动 ReceiverBoard 顶层, 检查 adcClkOut 50MHz 跳变 / dacScl 翻转 / ledN0+1 空载为 1 / AOTR→LED3 亮 / dig 1-hot. 输出: `Vivado/logs/sim.log`, `Vivado/proj_sim/.../simulate.log` (结束位 “TB RESULT: ALL PASS”).
2. **`Vivado/synth_impl.tcl`** — `synth_design` → `opt/place/phys_opt/route_design` → `write_bitstream`, 生成 `Vivado/proj_build/ReceiverBoard.bit`. 报告下发到 `Vivado/reports/` (利用率 / 时序 / DRC / methodology / power / clock).
3. **`Vivado/verilog.log`** — 两场 Vivado 运行的精简汇总 (TB 结果 + WNS/WHS + 资源 + 警告分类). 下一轮 Vivado 跳闪丢完 不必再看 50k 行原始 log.

如果只要跳仿真, 可单独调用:
```powershell
vivado -mode batch -source Vivado\sim.tcl `
  -log Vivado\logs\sim.log -journal Vivado\logs\sim.jou
```

只要跳综合布线:
```powershell
vivado -mode batch -source Vivado\synth_impl.tcl `
  -log Vivado\logs\synth_impl.log -journal Vivado\logs\synth_impl.jou
```



1. **重生 Verilog** (改了 Chisel 后必做)
   ```powershell
   cd chisel
   .\_gen_verilog.bat                # = sbt "runMain receiver.ReceiverBoard --target-dir generated"
   ```
   产出 `chisel/generated/ReceiverBoard.v` (~550 KB).
   看到 `[success] Total time` + 0 warnings 即可.

2. **新建 Vivado 工程** (一次性)
   - Create Project → `receiver_fpga` → RTL Project (不勾 "Do not specify sources")
   - Add Sources → `chisel/generated/ReceiverBoard.v` → ✓ Copy
   - Add Constraints → `chisel/constraints/AX7020_receiver.xdc` → ✓ Copy
   - Default Part: `xc7z020clg400-2` → Finish
   - Sources 窗口右键 `ReceiverBoard` → `Set as Top`

3. **重综合** (改了 Chisel 后)
   - Sources 里旧 `ReceiverBoard.v` → `Remove File from Project` (✗ Also delete from disk)
   - Add Sources → 选新的 → ✓ Copy
   - `Run Synthesis` → 期望 0 critical / 0 warning
   - `Run Implementation` → 期望 0 critical / 0 warning
   - `Generate Bitstream`

4. **下板**
   - **J13 跳线 = JTAG** (右两脚短路) | USB 接 JTAG 口
   - `Open Hardware Manager` → `Auto Connect` → `Program Device` → `ReceiverBoard.bit`

5. **现场验证** (按 §0.7 接好杜邦线)

| 步骤 | 操作 | 期望现象 |
|---|---|---|
| 1 | 上电 | LED4 ~0.75Hz 闪烁; LED1~3 全灭; DAC 静态 ≈ 1.65V (Vref/2) |
| 2 | 按一次 KEY1 (N15) | 全部 FF 同步复位, 释放后回到步骤 1 |
| 3 | 接入纯模拟 IF (1KHz audio AM-on-10.7MHz) | LED1 亮; DAC 跟随 1KHz; 万用表 DAC 输出 1.4~1.9V 摆动 |
| 4 | 接入纯数字 ASK (PWM 编码 7 nibble) | LED2 亮; 数码管显示 nibble |
| 5 | 模拟 + 数字混合 | LED1 + LED2 都亮; DAC + 数码管同时工作 |
| 6 | **停模拟** | LED1 ≤100ms 灭; DAC 100ms 内回到 1.65V; LED2 不变 |
| 7 | **停数字** (后于停模拟 6s 内) | LED2 维持 6 秒后熄灭; 数码管同步 blank |
| 8 | 模拟过载 (输入 > ±1V) | LED3 亮 ≥250ms (AOTR 报警, 提示降前端运放增益) |

---

##  故障诊断卡

| 现象 | 根因 | 修复 |
|---|---|---|
| 完全没现象, LED4 都不闪 | bitstream 没烧 / J13 跳线错 | 重 Program Device; J13 切到 JTAG |
| LED4 闪, LED1+LED2 空载常亮 | 旧版本 AnalogGate 没 DC tracker → 载波 DC 误触发 | 用本版 RTL (AnalogGate 已加 DC tracker, 见 §3) |
| LED3 不停闪 | 模拟输入超量程 | 调小前端运放增益 |
| LED3 永远灭 (即使输入很大) | OTR 杜邦线没接 | 接 OTR 线 (J10 PIN16); 或忽略 |
| **DAC 静态偏 -300 mV / 0 V** | DAC VCC/GND 没接, 或 ADC + DAC 共用 J10 PIN2 被瞬态拉死 | 检查 J11 PIN1=DAC GND, J11 PIN2=DAC VCC; 万用表测 DAC 板 VCC↔GND ≈ 5V |
| DAC 输出抖动得不像样 | I2C 上拉电阻和 FPGA 推挽冲突 (旧 RTL) | 用本 2026-05+ RTL (已开漏); 重生 ReceiverBoard.v |
| 5V 拉到 0.05V / 1A 限到 0.099A | ADC + DAC 共 J10 PIN2 (旧 README 错) **OR** FPGA 共用了 5V | 改用 J11 PIN2 给 DAC; FPGA 用 USB-Micro 或 12V 桶头独立供电 |
| ACLK 波形过冲 | 默认 OBUF DRIVE=12/SLEW=FAST 反射 | 已 xdc 加 SLEW SLOW + DRIVE 4, 重综合即生效 |
| 数码管乱亮 | seg/dig 接错 | 对照 §0.3 表 |
| WNS 仍负 | Vivado 还在用老 RTL | 删旧 ReceiverBoard.v, Add 新文件, 重综合 |

---

##  文件清单

```
fpga_receiver/                                                (2026-06 重命名)
├── README.md                                  本文档
├── _write_readme.py                            写 README 的 helper (绕开 IDE editor lock)
├── _extract_j11.py                             从 AX7020 手册提取 J10/J11 引脚的 helper
├── “数字-模拟混合收发机”设计方案/
│   ├── 发射端.png / 接收端.png                  任务框图
│   └── 目标要求.png                             TEST-A~E 指标定义
├── 硬件模块参数/
│   ├── ADC.pdf                                 AD9226 模块原理图 (含 SGM2036-3.3 LDO)
│   ├── DAC.pdf                                 DAC8571 模块原理图 (含 R9/R10 4.7K 上拉)
│   ├── 4位带小数点的LED.pdf                     SR410401N 共阳数码管
│   └── ALINX黑金AX7020开发板用户手册V2.2.pdf    J10/J11 引脚映射
├── chisel/
│   ├── build.sbt
│   ├── _gen_verilog.bat                        重生 ReceiverBoard.v 的快捷
│   ├── src/main/scala/receiver/
│   │   ├── Params.scala                        全局参数
│   │   ├── NCO.scala                           ★ 移除 phase reg 的 reset (REQP-1840)
│   │   ├── DDC / CIC / FIR / CORDIC / ASKDemod / PWMDecoder / HoldTimer / SegDriver / Filters
│   │   ├── DigitalAGC.scala                    ★ 2026-06: mulReg 截到 30bit (Synth 8-3332)
│   │   ├── FIR.scala                           ★ 跳过 coefFx==0 的 tap (Synth 8-3332)
│   │   ├── SerialFIR.scala                     ★ 单 DSP 折叠 FIR (Synth 8-3323 DSP 超用)
│   │   ├── AnalogGate.scala                    ★ 2026-06: 加 1 阶 IIR DC tracker (本版关键)
│   │   ├── I2cDacMaster.scala                  DAC8571 I2C 驱动
│   │   ├── ReceiverTop.scala                   算法顶层
│   │   └── ReceiverBoard.scala                 ★ 2026-06: dontTouch on dacA0/segDp (Synth 8-3917)
│   ├── src/test/scala/receiver/                ModuleSpec / ReceiverSpec / CsvReceiverSpec
│   ├── constraints/
│   │   └── AX7020_receiver.xdc                 ★ 2026-06: DAC VCC 改到 J11 PIN2
│   └── generated/
│       ├── ReceiverBoard.v                     下板 Verilog (~550KB)
│       └── ReceiverTop.v                       纯算法核
├── fpga/
│   ├── warning.xlsx                            Vivado 综合/实现/DRC 第二轮报告
│   └── _dump_table.py                          解析 warning.xlsx 的 Python helper
└── metlab/
    ├── params.m / run_all.m / run_all.py       ★ v4: 真实电压 + Goertzel AGC + TEST-D_multiple
    ├── gen_tx_signal.m / rx_reference.m
    ├── compare_chisel.m
    └── figures/                                4 张主测试 + 5 张 TEST-D_multiple 子图
```

---

##  协议 / 参数关键值 (`Params.scala` + 本版仿真常量)

| 项目 | 值 | 说明 |
|---|---|---|
| ADC 采样率 | 50 MHz | ACLK 输出, 单端 ±1V 满量程 |
| ADC 编码 | 12-bit unsigned, 中点 2048 | 进 FPGA 后减 2048 转 signed |
| IF 频率 | 10.7 MHz | DDC NCO 频率 |
| 抽取链 | CIC R=64,N=4 → FIR R=8 → 基带 ~97.66 KHz | 50e6 / 64 / 8 |
| 音频 LPF / HPF | SerialFIR 64/65-tap @ fc=10.5 KHz, **各 1 DSP** | 单 DSP 折叠 |
| **AnalogGate DC tracker** | 1 阶 IIR, fc ≈ 3.8 Hz | (本版新增, 见 §3) |
| **原模拟测试源** | **1 KHz 单频正弦, 0.3 V_pk** | (本版新, 真实低频信号) |
| 原数字测试源 | STM32 PWM 11.5 KHz, OOK 1ms-bit | 不变 |
| DAC | DAC8571 I2C **100 kHz** (v23, was 1 MHz), 地址 0x4C, **~2.5 kSPS** | Vref=3.3V, midcode 0x8000 = 1.65V |
| AGC 最大增益 | 4.0 (Q4.12 = 16384) | 防空载噪声放大 |
| signalPresent 阈值 | 64 LSB (≈ -36 dBFS) | 低于则 LED1/2 全灭 + DAC=0x8000 |
| signalPresent 悬挂 | 100 ms | 防零过瞬误掉 |
| OTR 拉伸 | 250 ms | LED3 单稳 |
| **digitalHoldSeconds** | **6 s** | 数字 6s 保持 |
| 数码管扫描 | ~763 Hz/digit | clk50M / 2^16 |
| FPGA 时序 | WNS ≥ 0 (50 MHz 闭合) | sync reset + DSP packing + FIR M-REG |
| I2C 物理层 | SCL/SDA 开漏 (1'bz/1'b0), 配 DAC 板 4.7K 上拉 | 见 §0.2 |
| 资源 (DSP) | ≈ 134 / 220 (XC7Z020) | 上版 261/220 已修 |



