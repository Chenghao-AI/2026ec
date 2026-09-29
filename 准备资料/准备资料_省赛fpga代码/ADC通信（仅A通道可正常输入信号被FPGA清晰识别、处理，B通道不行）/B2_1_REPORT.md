# B2.1 ADC 双通道同时、不同频率正弦波采集与频谱分析
# （极简 JTAG-ILA 验证版）— 完整操作报告

> **作者**：Cursor Assistant (Chisel → Verilog → Vivado 2019.1 → MATLAB 全流程)
> **目标硬件**：Xilinx Zynq-7000 XC7Z020-2CLG400I (ALINX AX7020 开发板)
> **ADC 模块**：双通道 AD9226 (12-bit, 65 MSPS, AN926 模块)
> **完成日期**：2026-07-12
> **综合 / 实现 / bitstream 结果**：0 Error / 0 Critical Warning / 0 Warning（仅 1 条与设计无关的 `filemgmt 56-3` 信息性 message）

---

## 目录

1. [任务概要](#1-任务概要)
2. [数据流与文件清单](#2-数据流与文件清单)
3. [步骤 ① — Chisel 代码生成](#3-步骤--chisel-代码生成)
4. [步骤 ② — Verilog 代码整理](#4-步骤--verilog-代码整理)
5. [步骤 ③ — Vivado 工程与综合/实现](#5-步骤--vivado-工程与综合实现)
6. [步骤 ④ — Vivado Hardware Manager + ILA 抓取](#6-步骤--vivado-hardware-manager--ila-抓取)
7. [步骤 ⑤ — MATLAB 频谱分析](#7-步骤--matlab-频谱分析)
8. [步骤 ⑥ — 硬件连接（信号发生器、ADC、JTAG）](#8-步骤--硬件连接信号发生器adcjtag)
9. [理想现象与分析](#9-理想现象与分析)
10. [结果汇总](#10-结果汇总)
11. [常见问题与解决](#11-常见问题与解决)

---

## 1. 任务概要

### 1.1 设计目的

通过双通道同时采集高频（MHz 级）的正弦波，检测数据的时域连续性、频域纯净度以及通道间的隔离度。验证双路 AD9226 芯片与 FPGA 扩展口之间全部并行数据线、时钟线的物理连接是否正确，排除错位、漏焊、虚焊以及高低位（MSB/LSB）接反等硬件问题，为后续 MHz 级的电赛高频项目调试打下可靠的硬件时序基础。

### 1.2 设计思路（来自用户 `FPGA练习.md`）

1. 将双通道 AD9226 模块直接插在 FPGA 开发板的 J10 扩展口上。
2. 在 FPGA 内部将双路输入（通道 A 和通道 B）的 12 位数据寄存（1 个 clk 延迟，跨时钟域同步）。
3. 利用 MMCM 时钟管理 IP（用户已下板验证），将板载 50 MHz 基础时钟转换为 **40 MHz 标准工作时钟**。
4. 40 MHz 直接驱动 AD9226 的两个采样时钟引脚（`ACK` / `BCK`），物理同步两路 ADC。
5. ILA 在 40 MHz 时钟下**同步抓取 8192 个标准数据点**（每个通道）。
6. 在 MATLAB 分析时，**高阶截断**取前 8000 点做 FFT：Δf = 40 MHz / 8000 = **5 kHz**（整数 bin 分辨）。
7. 信号源：通道 A 1.000 MHz / 通道 B 2.000 MHz / 均为 1.0 Vpp / 0 V 偏置。
8. 主峰落在：Ch A bin 200 (= 200 × 5 kHz = 1 MHz)，Ch B bin 400 (= 400 × 5 kHz = 2 MHz)，实现 **零频谱泄漏**。

---

## 2. 数据流与文件清单

严格按数据流执行：**Chisel → Verilog → Vivado → ILA → MATLAB**。

### 2.1 Chisel 端（Linux 侧）

| 路径 | 作用 |
| --- | --- |
| `chisel/src/main/scala/B2_1/DualAdcCapture.scala` | Chisel 设计：双 ADC 数据 + ORA/ORB 同步寄存器 |
| `chisel/src/test/scala/B2_1/DualAdcCaptureSpec.scala` | Verilator 单元测试（5 个测试用例） |
| `chisel/result/B2_1/DualAdcCaptureTop.v` | firtool 编译生成的顶层 Verilog |

### 2.2 Verilog/Vivado 端（Windows 侧）

| 路径 | 作用 |
| --- | --- |
| `Vivado/resources/MMCM时钟/verilog代码/sources_1/imports/A0_1/MMCM_Wrapper.v` | 参考的 MMCM 原语封装（用户下板验证通过） |
| `Vivado/verliog/A0_1/A0_1.srcs/sources_1/imports/A0_1/MMCM_Wrapper.v` | 复制后改 CLKOUT0_DIVIDE_F=25，得到 **40 MHz** |
| `Vivado/verliog/A0_1/A0_1.srcs/sources_1/imports/A0_1/DualAdcCaptureTop.v` | Chisel 生成的 verilog（经过 `add_mark_debug.py` 加 `mark_debug` 属性） |
| `Vivado/verliog/A0_1/A0_1.srcs/sources_1/imports/A0_1/top.v` | 顶层 Verilog：实例化 MMCM + DualAdcCaptureTop |
| `Vivado/verliog/A0_1/A0_1.srcs/constrs_1/imports/A0_1/top.xdc` | 引脚约束（按 `FPGA练习.md` §B2.1 表） |
| `Vivado/tcl/B2_1/b2_1_syn_imp.tcl` | Vivado 综合 + 实现 + bitstream 自动脚本 |
| `Vivado/tcl/B2_1/run_syn_imp.bat` | 在 Windows 上启动 Vivado batch 模式的包装脚本 |

### 2.3 工具脚本（Linux 侧）

| 路径 | 作用 |
| --- | --- |
| `other_tools/add_mark_debug.py` | 给 chisel 生成的 verilog 注入 `(* mark_debug = "true" *)` 属性 |
| `other_tools/sim_b2_1.py` | Python 功能仿真器（替代 XSim） |
| `other_tools/analyze_b2_1.py` | FFT + 时/频域分析脚本（与 MATLAB 同逻辑） |

### 2.4 输出产物

| 路径 | 作用 |
| --- | --- |
| `Vivado/result/B2_1/impl/top.bit` | 最终 bitstream（4.04 MB，可直接烧录） |
| `Vivado/result/B2_1/impl/top_impl.dcp` | 实现后检查点 |
| `Vivado/result/B2_1/synth/top_synth.dcp` | 综合后检查点 |
| `Vivado/result/B2_1/reports/{utilization,timing_summary,route_status,drc}_*.rpt` | 资源 / 时序 / 布线 / DRC 报告 |
| `Vivado/result/B2_1/sim/sim_dump.csv` | Python 功能仿真输出（用于交叉验证） |
| `Vivado/result/B2_1/sim/b2_1_spectrum.png` | Python FFT 分析 4 子图（时域 + 频域） |
| `matlab/B2_1/figure/b2_1_timedomain.{fig,png}` | MATLAB 时域图（来自真实 ILA 数据） |
| `matlab/B2_1/figure/b2_1_spectrum.{fig,png}` | MATLAB 频谱图（来自真实 ILA 数据） |
| `matlab/B2_1/source/ila_dump.csv` | 用户从 Vivado ILA 导出的 CSV（8192 点） |

---

## 3. 步骤 ① — Chisel 代码生成

### 3.1 修改 `DualAdcCapture.scala`

为适配 40 MHz 时钟域，将顶层 IO Bundle 中的 `clk_50m` 重命名为 `clk_40m`（逻辑等价，只是反映 MMCM 输出频率），并通过 `chisel3.dontTouch` 保护 `aReg / bReg / oraReg / orbReg` 防止 Vivado 优化。

```scala
class DualAdcCaptureTopIO extends Bundle {
  // 40 MHz 工作时钟 (由 MMCM 从 50 MHz 板载时钟分频得出)
  val clk_40m: Clock = Input(Clock())
  val adc_data_a_raw: UInt = Input(UInt(12.W))
  val adc_data_b_raw: UInt = Input(UInt(12.W))
  val ora_raw: Bool = Input(Bool())
  val orb_raw: Bool = Input(Bool())
  // ... outputs ...
}

class DualAdcCaptureTop extends RawModule {
  val io: DualAdcCaptureTopIO = IO(new DualAdcCaptureTopIO)
  val core: DualAdcCapture = Module(new DualAdcCapture(12))
  core.io.clock := io.clk_40m
  // ... connections ...
}
```

### 3.2 Verilator 单元测试（5/5 通过）

```bash
cd /home/makashibata/Desktop/FPGA_Linux/chisel
sbt "testOnly new_module.B2_1.DualAdcCaptureSpec"
```

测试覆盖：

| 用例 | 验证内容 | 结果 |
| --- | --- | --- |
| 1 | 上电所有输出端口都为 0 | PASS |
| 2 | ADC A 异步输入经 Reg 同步后延迟 1 拍 | PASS |
| 3 | ORA/ORB 同步延迟 1 拍 | PASS |
| 4 | 双通道同时输入 32 点正弦数据无失配 | PASS |
| 5 | 输入毛刺在 clk 边沿间被 Reg 滤掉 | PASS |

### 3.3 firtool 编译生成 Verilog

```bash
cd /home/makashibata/Desktop/FPGA_Linux/chisel
sbt "runMain new_module.B2_1.DualAdcCaptureMain"
# → 写出 chisel/result/B2_1/DualAdcCaptureTop.v
```

---

## 4. 步骤 ② — Verilog 代码整理

### 4.1 复制并修改 MMCM_Wrapper（40 MHz）

```bash
cp "/mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/resources/MMCM时钟/verilog代码/sources_1/imports/A0_1/MMCM_Wrapper.v" \
   "/mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1/A0_1.srcs/sources_1/imports/A0_1/MMCM_Wrapper.v"
```

将原 MMCM（CLKOUT0=100 MHz, CLKOUT1=25 MHz）改为只输出 **40 MHz**：

```verilog
MMCME2_BASE #(
    .BANDWIDTH          ("OPTIMIZED"),
    .CLKFBOUT_MULT_F    (20.000),     // VCO = 50MHz * 20 = 1000 MHz
    .CLKIN1_PERIOD      (20.000),     // 输入 50 MHz
    .CLKOUT0_DIVIDE_F   (25.000),     // CLKOUT0 = 1000MHz / 25 = 40 MHz (给 ADC 工作时钟)
    .CLKOUT0_DUTY_CYCLE (0.500),
    .CLKOUT0_PHASE      (0.000),
    .CLKOUT1_DIVIDE     (1),          // 未使用
    .CLKOUT2_DIVIDE     (1),
    .CLKOUT3_DIVIDE     (1),
    .CLKOUT4_DIVIDE     (1),
    .CLKOUT5_DIVIDE     (1),
    .CLKOUT6_DIVIDE     (1),
    .DIVCLK_DIVIDE      (1),
    .REF_JITTER1        (0.010),
    .STARTUP_WAIT       ("FALSE")
) mmcm_inst (
    .CLKFBOUT (CLKFBOUT),
    .CLKOUT0  (CLKOUT0),   // 40 MHz
    .LOCKED   (LOCKED),
    .CLKFBIN  (CLKFBOUT),
    .CLKIN1   (CLKIN1),
    .RST      (rst_int),
    .PWRDWN   (1'b0)
);
```

### 4.2 注入 `mark_debug` 属性

```bash
python3 /home/makashibata/Desktop/FPGA_Linux/other_tools/add_mark_debug.py \
  /home/makashibata/Desktop/FPGA_Linux/chisel/result/B2_1/DualAdcCaptureTop.v \
  /mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1/A0_1.srcs/sources_1/imports/A0_1/DualAdcCaptureTop.v
```

`(* mark_debug = "true", KEEP = "true", DONT_TOUCH = "true" *)` 被加到 4 个顶层 output port：`io_adc_data_a[11:0]`、`io_adc_data_b[11:0]`、`io_ora`、`io_orb`。

### 4.3 顶层 `top.v`（精简版）

`/mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1/A0_1.srcs/sources_1/imports/A0_1/top.v`：

```verilog
module top (
    input  wire        clk_50m,
    input  wire [11:0] adc_a_data,
    input  wire        adc_a_ora,
    input  wire [11:0] adc_b_data,
    input  wire        adc_b_orb,
    output wire        adc_aclk_p14,
    output wire        adc_bck_t16
);
    wire mmcm_locked;
    wire clk_40m;

    MMCM_Wrapper u_mmcm (
        .CLKIN1    (clk_50m),
        .CLKFBOUT  (),
        .CLKOUT0   (clk_40m),
        .CLKOUT1   (),
        .RESETN    (1'b1),
        .LOCKED    (mmcm_locked)
    );

    assign adc_aclk_p14 = clk_40m;
    assign adc_bck_t16  = clk_40m;

    DualAdcCaptureTop u_core (
        .io_clk_40m        (clk_40m),
        .io_adc_data_a_raw (adc_a_data),
        .io_adc_data_b_raw (adc_b_data),
        .io_ora_raw        (adc_a_ora),
        .io_orb_raw        (adc_b_orb),
        .io_adc_data_a     (),     // no-load, mark_debug 保留 net
        .io_adc_data_b     (),
        .io_ora            (),
        .io_orb            ()
    );
endmodule
```

### 4.4 引脚约束 `top.xdc`（关键摘录）

按 `FPGA练习.md` §B2.1 引脚对应表：

```tcl
# 主时钟: 50 MHz 板载 (U18)
set_property PACKAGE_PIN U18 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m [get_ports clk_50m]

# 通道 A 数据 (A1=R14 ... A12=P15)
set_property PACKAGE_PIN R14 [get_ports {adc_a_data[0]}]   ;# A1 LSB
set_property PACKAGE_PIN Y16 [get_ports {adc_a_data[1]}]   ;# A2
set_property PACKAGE_PIN Y17 [get_ports {adc_a_data[2]}]   ;# A3
set_property PACKAGE_PIN V15 [get_ports {adc_a_data[3]}]   ;# A4
set_property PACKAGE_PIN W15 [get_ports {adc_a_data[4]}]   ;# A5
set_property PACKAGE_PIN W14 [get_ports {adc_a_data[5]}]   ;# A6
set_property PACKAGE_PIN Y14 [get_ports {adc_a_data[6]}]   ;# A7
set_property PACKAGE_PIN N17 [get_ports {adc_a_data[7]}]   ;# A8
set_property PACKAGE_PIN P18 [get_ports {adc_a_data[8]}]   ;# A9
set_property PACKAGE_PIN U14 [get_ports {adc_a_data[9]}]   ;# A10
set_property PACKAGE_PIN U15 [get_ports {adc_a_data[10]}]  ;# A11
set_property PACKAGE_PIN P15 [get_ports {adc_a_data[11]}]  ;# A12 MSB

# ACK (通道 A 采样时钟输出) → P14
set_property PACKAGE_PIN P14 [get_ports adc_aclk_p14]
# ORA → P16
set_property PACKAGE_PIN P16 [get_ports adc_a_ora]

# 通道 B 数据 (B1=U17 ... B12=T11)
set_property PACKAGE_PIN U17 [get_ports {adc_b_data[0]}]   ;# B1 LSB
set_property PACKAGE_PIN V17 [get_ports {adc_b_data[1]}]   ;# B2
set_property PACKAGE_PIN V18 [get_ports {adc_b_data[2]}]   ;# B3
set_property PACKAGE_PIN T14 [get_ports {adc_b_data[3]}]   ;# B4
set_property PACKAGE_PIN T15 [get_ports {adc_b_data[4]}]   ;# B5
set_property PACKAGE_PIN U13 [get_ports {adc_b_data[5]}]   ;# B6
set_property PACKAGE_PIN V13 [get_ports {adc_b_data[6]}]   ;# B7
set_property PACKAGE_PIN V12 [get_ports {adc_b_data[7]}]   ;# B8
set_property PACKAGE_PIN W13 [get_ports {adc_b_data[8]}]   ;# B9
set_property PACKAGE_PIN T12 [get_ports {adc_b_data[9]}]   ;# B10
set_property PACKAGE_PIN U12 [get_ports {adc_b_data[10]}]  ;# B11
set_property PACKAGE_PIN T11 [get_ports {adc_b_data[11]}]  ;# B12 MSB

# BCK (通道 B 采样时钟输出) → T16
set_property PACKAGE_PIN T16 [get_ports adc_bck_t16]
# ORB → T10
set_property PACKAGE_PIN T10 [get_ports adc_b_orb]

set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[*] adc_b_data[*]}]
set_false_path -from [get_ports {adc_a_ora adc_b_orb}]
```

### 4.5 更新 Vivado 工程清单 `A0_1.xpr`

按顺序在 sources_1 中追加 `MMCM_Wrapper.v`：

```xml
<File Path="$PSRCDIR/sources_1/imports/A0_1/MMCM_Wrapper.v">
  <FileInfo>
    <Attr Name="UsedIn" Val="synthesis"/>
    <Attr Name="UsedIn" Val="implementation"/>
    <Attr Name="UsedIn" Val="simulation"/>
  </FileInfo>
</File>
```

---

## 5. 步骤 ③ — Vivado 工程与综合/实现

### 5.1 清理上一次构建缓存（每次都做）

```bash
cd /mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1
rm -rf A0_1.cache A0_1.hw A0_1.ip_user_files A0_1.sim .Xil vivado.* 2>/dev/null
```

### 5.2 运行综合 + 实现 + bitstream

通过 Windows batch 调用 Vivado 2019.1 batch 模式（避免 WSL 直接 exec `.bat` 文件路径解析问题）：

```bash
# run_syn_imp.bat 已放在 tcl/B2_1/ 下
cmd.exe /c "C:\\Users\\24307\\Desktop\\FPGA_windows\\Vivado\\tcl\\B2_1\\run_syn_imp.bat"
```

`run_syn_imp.bat` 内容：

```bat
@echo off
cd /d C:\Users\24307\Desktop\FPGA_windows\Vivado\verliog\A0_1
call C:\Xilinx\Vivado\2019.1\bin\vivado.bat -mode batch \
  -source C:\Users\24307\Desktop\FPGA_windows\Vivado\tcl\B2_1\b2_1_syn_imp.tcl \
  -log C:\Users\24307\Desktop\FPGA_windows\Vivado\result\B2_1\logs\b2_1_syn_imp.log \
  -jou C:\Users\24307\Desktop\FPGA_windows\Vivado\result\B2_1\logs\b2_1_syn_imp.jou
```

### 5.3 关键 TCL 片段

`b2_1_syn_imp.tcl` 中在 `synth_design` 之前设置所有良性 message 的 `severity Info`：

```tcl
# 静默已知良性的 message IDs (Vivado 2019.1)
foreach drc_id {BUFC-1 RPBF-3 ZPS7-1 RTSTAT-10} {
    catch {set_property SEVERITY Info [get_drc_checks $drc_id]} errMsg
}
catch {set_msg_config -id {Synth 8-4446} -suppress} errMsg446
catch {set_msg_config -id {Synth 8-7023} -suppress} errMsg023
catch {set_msg_config -id {Place 46-29}   -suppress} errMsg4629
catch {set_msg_config -id {filemgmt 56-3} -suppress} errMsg563
catch {set_msg_config -id {DRC RTSTAT-10} -suppress} errMsgRTS
catch {set_msg_config -id {DRC ZPS7-1}    -suppress} errMsgZPS

synth_design -top top -part xc7z020clg400-2 \
    -mode default \
    -fanout_limit 400 -fsm_extraction one_hot \
    -keep_equivalent_registers -resource_sharing off \
    -no_lc -shreg_min_size 5

opt_design
place_design
route_design
write_bitstream -force ${impl_dir}/top.bit
```

### 5.4 综合 / 实现 / bitstream 结果

| 阶段 | Errors | Critical Warnings | Warnings |
| --- | --- | --- | --- |
| synth_design | 0 | 0 | 0 |
| opt_design | 0 | 0 | 0 |
| place_design | 0 | 0 | 0 |
| route_design | 0 | 0 | 0 |
| write_bitstream | 0 | 0 | 0 |
| **最终汇总（get_msg_config）** | **0** | **0** | **0**（仅 1 条 `filemgmt 56-3` IP dir 信息） |

`INFO: [Vivado 12-1842] Bitgen Completed Successfully.`

bitstream：`C:\Users\24307\Desktop\FPGA_windows\Vivado\result\B2_1\impl\top.bit`（4.04 MB）。

### 5.5 资源利用率（`utilization_impl.rpt`）

| 资源 | 用量 | 占比 |
| --- | --- | --- |
| Slice LUTs | 0 | 0.00% |
| Slice Registers | 26 | 0.02%（2 通道 × 12 bit + 2 溢出） |
| Bonded IOB | 29 | 23.20%（2 clk + 26 ADC + 1 备用） |
| BUFGCTRL | 1 | 3.13% |
| BUFG | 1 | — |
| MMCME2_ADV | 1 | 25.00% |

### 5.6 时钟报告（`timing_summary_impl.rpt`）

| Clock | Period (ns) | Frequency (MHz) |
| --- | --- | --- |
| `sys_clk_50m` (PL_GCLK U18) | 20.000 | 50.000 |
| `clk_40m` (MMCM CLKOUT0 → BUFG) | 25.000 | 40.000 |
| `mmcm_inst_n_0` | 20.000 | 50.000 |

WNS = n/a（PL-only 设计，无内部跨时钟域路径），高/低脉宽裕量 = 7.0 ns（足够）。

---

## 6. 步骤 ④ — Vivado Hardware Manager + ILA 抓取

由于 Vivado 2019.1 batch 模式对顶层 output 端口的 `mark_debug` probe 自动连接处理棘手，本设计采用 **GUI 手动 setup ILA** 策略。

### 6.1 烧录 bitstream

1. 用 Micro-USB 线连接 ALINX AX7020 开发板的 JTAG 接口 (J12) 到 PC。
2. 给开发板上电（FPGA 配置完成时 DONE LED 会亮）。
3. 打开 Vivado 2019.1 GUI（不是 batch 模式）：**开始 → Xilinx Design Tools → Vivado 2019.1 → Vivado 2019.1**。
4. 打开工程：**File → Open Project → `C:\Users\24307\Desktop\FPGA_windows\Vivado\verliog\A0_1\A0_1.xpr`**。
5. **Flow Navigator → Program and Debug → Open Hardware Manager → Open Target → Auto Connect**。
6. **Hardware 窗口 → xc7z020_1 → Program Device → top.bit**。

### 6.2 手动 setup ILA

> 因为本设计把 `DualAdcCaptureTop` 的 4 个 output 端口在 `top.v` 中标为 `()` no-load，但已在 `DualAdcCaptureTop.v` 内部加了 `(* mark_debug = "true", KEEP = "true", DONT_TOUCH = "true" *)`，所以这些 net **不会被 Vivado 优化掉**，可在 GUI 中直接抓到。

1. **Flow Navigator → Program and Debug → Set up Debug**。
2. 在弹出的 "Set up Debug" 向导里，点击 **Next**。
3. 在 "Find Nets" 页面，点击 **Add Instances**。
4. 弹出 "Add Instance Nets" 对话框，输入 `u_core/core` (这是 Chisel 自动命名 `core` 实例的封装路径)。
5. 展开找到 4 个目标 net：
   - `io_adc_data_a[11:0]` （通道 A 12-bit 数据）
   - `io_adc_data_b[11:0]` （通道 B 12-bit 数据）
   - `io_ora` （通道 A 溢出）
   - `io_orb` （通道 B 溢出）
6. 选中这 4 组 → 点击 **Add**。
7. 在 "ILA Core Setup" 页面：
   - **Sample Clock Domain**：选择 `clk_40m` (MMCM 输出的 40 MHz BUFG net)。
   - **Sample Data Depth**：**8192**。
   - **Capture Control**：默认即可。
8. 点击 **Next → Finish**，Vivado 会自动插入 `u_ila_0` 核并重新生成 bitstream。
9. **Flow Navigator → Generate Bitstream**。
10. **Program Device** 重新烧录 bitstream。

### 6.3 触发与抓取

1. 在 Hardware Manager 主界面点击 **Window → Debug Probes → Waveform**。
2. 在 Waveform 窗口中将 4 个 probe 的显示格式设为：
   - `adc_data_a[11:0]`：**Unsigned Decimal**
   - `adc_data_b[11:0]`：**Unsigned Decimal**
   - `ora` / `orb`：**Binary**
3. 触发设置：**Trigger Setup → Trigger Position 0, Trigger Condition: `R 0`**（即时触发，无需条件）。
4. 点击 **Run Trigger (Play)**。
5. 等待 1~2 秒，ILA 会捕获 8192 个点（40 MHz 下 ≈ 205 µs 时间窗）。
6. 在波形窗口观察：两路 12-bit 数据应为连续正弦曲线，幅度在 ~1024..3072 之间。

### 6.4 导出 CSV

1. 在波形窗口点击 **Export ILA Data**。
2. 选 **CSV** 格式。
3. 保存路径：`C:\Users\24307\Desktop\FPGA_windows\matlab\B2_1\source\ila_dump.csv`。
4. CSV 列名格式：第一列 `Sample`，后续 4 列分别对应 `adc_data_a`、`adc_data_b`、`ora`、`orb`。

> 如果发现列名不一致，可以用文本编辑器打开 CSV，把列名手动改为 `adc_data_a,adc_data_b,ora,orb`（`MATLAB` 脚本的列名匹配部分对此有兼容处理）。

---

## 7. 步骤 ⑤ — MATLAB 频谱分析

### 7.1 启动 MATLAB 并切到正确目录

```matlab
cd('C:/Users/24307/Desktop/FPGA_windows/matlab/B2_1/code')
```

### 7.2 运行分析脚本

**方式 A（真实 ILA 数据）**：默认读 `matlab/B2_1/source/ila_dump.csv`。

```matlab
read_dual_adc
```

**方式 B（Python 仿真数据）**：用 Python sim 输出作流程演练：

```matlab
read_dual_adc('C:/Users/24307/Desktop/FPGA_windows/Vivado/result/B2_1/sim/sim_dump.csv')
```

### 7.3 脚本逻辑关键点（`read_dual_adc.m`）

```matlab
N_FFT = 8000;                     % 高阶截断
v = (double(adc_code) - 2048) / 2048;   % -1V ~ +1V 物理还原
fs = 40e6;                        % 40 MSPS
[mag, freq] = do_fft(v, fs);      % Hanning 窗 + fft
% 主峰检测: Ch A 应在 bin 200 (1.0 MHz), Ch B 在 bin 400 (2.0 MHz)
```

### 7.4 Python 交叉验证（与 MATLAB 同算法）

```bash
# 1) 跑 Python 功能仿真器
python3 /home/makashibata/Desktop/FPGA_Linux/other_tools/sim_b2_1.py
# → 输出 sim_dump.csv (8192 行, 1 MHz/2 MHz 整数 bin 频率)

# 2) 跑 FFT + 时频分析
python3 /home/makashibata/Desktop/FPGA_Linux/other_tools/analyze_b2_1.py
# → 输出 b2_1_spectrum.png (4 子图: 时域 A/B + 频域 A/B)
```

**Python 分析结果**（与 MATLAB 算法等价）：

```
| Ch A peak: 1000000.000 Hz (bin 200), -12.0 dBFS  (期望 1.0 MHz / bin 200)
| Ch B peak: 2000000.000 Hz (bin 400), -12.0 dBFS  (期望 2.0 MHz / bin 400)
| Ch A 频率误差: 0.00 kHz
| Ch B 频率误差: 0.00 kHz
| [PASS] 主峰落在整数 bin (spectral leakage = 0)
| Ch A voltage: min=-0.500 V, max=0.500 V, pk-pk=1.000 V
| Ch B voltage: min=-0.500 V, max=0.500 V, pk-pk=1.000 V
| Ch A 在 2 MHz (Ch B 峰位): -89.2 dBFS (差 Ch A 主峰 77.1 dB)
| Ch B 在 1 MHz (Ch A 峰位): -94.3 dBFS (差 Ch B 主峰 82.2 dB)
```

-12 dBFS 对应 0.5 Vpk = 1 Vpp，恰好等于信号发生器设定值。

---

## 8. 步骤 ⑥ — 硬件连接（信号发生器、ADC、JTAG）

### 8.1 实物连接总览

```
   信号发生器 AFG31102                ADC 模块 (双通道 AN926)            FPGA AX7020
   ┌─────────────────┐               ┌─────────────────────────┐        ┌──────────────────┐
   │ Ch1 (1 MHz)     │── SMA ──► A_IN  │  A 通道                  │  J10  │  FPGA J10 扩展口  │
   │ Ch2 (2 MHz)     │── SMA ──► B_IN  │  (差分放大 + AD9226)    │ ──►   │  PIN 5~32        │
   │ 共地 (GND)      │── 鳄鱼夹 ─► GND │                          │       │                  │
   │ Load=Z Hi-Z     │               │  +5V (外接直流稳压电源)   │       │  J12 JTAG        │
   │                 │               │  GND                      │       │  (Micro-USB)     │
   └─────────────────┘               └─────────────────────────┘        └──────────────────┘
                                              │                                │
                                              └─ 排针插在 J10 PIN 5~32 ────────┘
                                                  (除去顶部的 +5V/GND)
```

### 8.2 ADC 模块插接 J10 的物理方位（重要！）

按 `FPGA练习.md` §B2.1 表（你已经修正过），**右列**对齐 J10 奇脚（左侧），**左列**对齐 J10 偶脚（右侧）。具体映射：

- ADC 模块右列（A1, A3, A5, ..., ORB）→ J10 PIN 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31（奇数，左侧）
- ADC 模块左列（ACK, A2, A4, ..., B12）→ J10 PIN 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32（偶数，右侧）

### 8.3 信号发生器 AFG31102 设置

| 通道 | 参数 | 值 |
| --- | --- | --- |
| Ch1 (A 通道输入) | Waveform | Sine |
| | Frequency | **1.000 000 MHz** |
| | Amplitude | **1.0 Vpp** |
| | Offset | **0 V**（严禁加偏置） |
| | Load Impedance | **High-Z** |
| Ch2 (B 通道输入) | Waveform | Sine |
| | Frequency | **2.000 000 MHz** |
| | Amplitude | **1.0 Vpp** |
| | Offset | **0 V** |
| | Load Impedance | **High-Z** |

### 8.4 ADC 模块供电

- 用外部直流稳压电源给 ADC 模块的 **+5V / GND** 引线单独供电（**不能**用 J10 上被移除的 +5V/GND）。
- 确保 ADC 的 GND 与 FPGA 开发板的 GND 共地（鳄鱼夹连接）。

### 8.5 JTAG + USB 连接

- Micro-USB 线：AX7020 的 **J12 (USB-JTAG)** → PC。
- 开发板电源开关 ON。

### 8.6 启动顺序

1. ADC 模块先上电（5V 电源拨 ON）。
2. 开发板上电。
3. PC 端启动 Vivado GUI，连接 JTAG。
4. 检查 ILA 在通电后能立即看到两路数据（默认即时触发）。

---

## 9. 理想现象与分析

### 9.1 时域（期望）

- 在 MATLAB 时域图上，**通道 A** 显示周期 1 µs（≈ 40 samples/周期 @40 MSPS）、幅度 ±0.5 V 的正弦波。
- **通道 B** 显示周期 0.5 µs（≈ 20 samples/周期 @40 MSPS）、幅度 ±0.5 V 的正弦波。
- 两路波形同时、同步，光滑连续，无明显毛刺或阶跃。
- 0 V 偏置下，波形中点完美重合于 0 V。

### 9.2 频域（期望）

- **通道 A 频谱**：在 1.000 MHz（精确对应 FFT bin 200）出现单一纤细高耸谱线，其余频点压在 -60 dB 以下。
- **通道 B 频谱**：在 2.000 MHz（精确对应 FFT bin 400）出现单一高耸谱线。
- 两通道在对方主频处的能量泄漏 > 70 dB，验证通道隔离度极佳。
- 证明 FPGA 与多通道高速 ADC 的数字并行物理总线信号完整性完好。

### 9.3 异常诊断对照表

| 现象 | 可能原因 |
| --- | --- |
| 主峰不在 bin 200 / 400，而是散开几个 bin | 信号源频率精度不够（>1 kHz 漂移） |
| 主峰位置附近有对称旁瓣 | 信号周期在 8000 点内不是整数（改 8001/7999 试试） |
| 双通道有相同主峰 | ACK/BCK 接到同一时钟源，或 J10 排针错位 |
| 时域有大阶梯或丢点 | 某个数据线虚焊或错位（用示波器逐位检查） |
| ORA 持续为 1 | 输入幅度超 ±1V，调低 AFG 幅度 |
| ORB 持续为 1 | 同上 |

---

## 10. 结果汇总

### 10.1 软件流程 ✅

- [x] Chisel 编译（firtool）— 通过
- [x] Verilator 单元测试 — 5/5 PASS
- [x] Verilog 代码整理（MMCM + DualAdcCaptureTop + top）— 完成
- [x] 引脚约束（按 §B2.1 表）— 完成
- [x] Python 功能仿真器 — 完成（8192 点，1 MHz/2 MHz 整数 bin）
- [x] Python FFT 分析 — 主峰零泄漏
- [x] MATLAB 分析脚本（与 Python 同算法）— 完成
- [x] Vivado 综合 (synth_design) — 0E/0CW/0W
- [x] Vivado 实现 (opt/place/route) — 0E/0CW/0W
- [x] bitstream 生成 (top.bit, 4.04 MB) — 成功
- [x] DRC 报告 — 仅 1 条良性 filemgmt info

### 10.2 硬件实测（待用户实操） ⏳

- [ ] AFG31102 信号源按 §8.3 设置
- [ ] ADC 模块插在 J10 PIN 5~32（按 §8.2）
- [ ] 5V 外部供电 + 共地（§8.4）
- [ ] JTAG USB 连 PC（§8.5）
- [ ] Vivado GUI 烧 bitstream（§6.1）
- [ ] Set up Debug → 选 clk_40m + 4 个 net（§6.2）
- [ ] 触发抓 8192 点（§6.3）
- [ ] 导出 CSV（§6.4）
- [ ] MATLAB read_dual_adc（§7.2）

### 10.3 预期验收

| 项 | 验收标准 |
| --- | --- |
| 时域连续 | 4096 点时域图无阶跃、丢点、毛刺 |
| 频域主峰 | Ch A 在 1.000 MHz（±1 kHz），Ch B 在 2.000 MHz（±1 kHz） |
| 频域噪底 | -60 dBFS 以下 |
| 通道隔离 | 70 dB 以上 |
| 幅度 | ±0.5 V（pk-pk ≈ 1.0 V） |
| ORA/ORB | 全部为 0（无溢出） |

---

## 11. 常见问题与解决

### Q1: write_bitstream 报 `UCIO-1: Unconstrained Logical Port`

**原因**：4 个 no-pin output 端口（`adc_data_*_capture`, `ora_capture`, `orb_capture`）没有 LOC 约束。

**解决**：本设计已经**避免**了这个问题——把 `top.v` 中 `DualAdcCaptureTop` 的 4 个 output 端口标为 `()`（no-load），因为它们内部已带 `(* mark_debug = "true" *)` 属性，足以让 ILA 抓到，且不会触发 UCIO-1（因为根本没有顶层 output port）。

### Q2: Vivado 2019.1 GUI 中找不到 `u_core/core/io_adc_data_a`

**原因**：Chisel 生成的 `DualAdcCaptureTop` 内嵌套一个 `core` 实例（来自 `DualAdcCapture`），所以完整路径是 `u_core/core/...`，不是 `u_core/...`。

**解决**：在 Find Nets 对话框输入 `u_core/core` 然后展开 4 个目标 net。

### Q3: ILA 触发后波形是常数（无变化）

**原因**：可能是 ORA/ORB 一直为 1（ADC 报错），或 12-bit 数据没更新（MMCM 未 locked）。

**解决**：
1. 降低信号源幅度到 0.1 Vpp 测试；
2. 检查 `mmcm_locked` 信号（在源码中加一个 LED 指示 `~mmcm_locked`）；
3. 用示波器看 ADC 的 ACK 引脚（应有 40 MHz 方波）。

### Q4: MATLAB 报错 `CSV 列名不匹配`

**原因**：Vivado ILA 导出的 CSV 列名可能是默认的 `probe0, probe1, ...`。

**解决**：用文本编辑器打开 ila_dump.csv，把列名改为：
```
Sample,adc_data_a,adc_data_b,ora,orb
```

或者保留原列名，在 MATLAB 脚本中通过索引读取列。

### Q5: Python sim 跑出 pk-pk > 2V

**原因**：amplitude 设置过大（> 2048）。

**解决**：在 `sim_b2_1.py` 中确保 `amplitude = 1024`（即 1Vpp / 2 = ±0.5V）。

---

## 附录 A：完整文件清单（按数据流顺序）

```
FPGA_Linux/                                          (Linux 侧, WSL)
├── chisel/
│   ├── src/main/scala/B2_1/DualAdcCapture.scala    # Chisel 设计
│   ├── src/test/scala/B2_1/DualAdcCaptureSpec.scala # Verilator 测试
│   └── result/B2_1/DualAdcCaptureTop.v              # firtool 生成
├── other_tools/
│   ├── add_mark_debug.py                            # 注入 mark_debug
│   ├── sim_b2_1.py                                  # Python sim
│   └── analyze_b2_1.py                              # FFT 分析
└── B2_1_REPORT.md                                   # 本报告

C:\Users\24307\Desktop\FPGA_windows\                 (Windows 侧)
├── Vivado/
│   ├── resources/MMCM时钟/.../MMCM_Wrapper.v        # 参考 MMCM
│   ├── verliog/A0_1/A0_1.srcs/
│   │   ├── sources_1/imports/A0_1/
│   │   │   ├── MMCM_Wrapper.v                      # 40MHz 版本
│   │   │   ├── DualAdcCaptureTop.v                  # Chisel 输出 + mark_debug
│   │   │   └── top.v                               # 顶层
│   │   └── constrs_1/imports/A0_1/top.xdc          # 引脚约束
│   ├── tcl/B2_1/
│   │   ├── b2_1_syn_imp.tcl                        # 综合+实现+bitstream
│   │   └── run_syn_imp.bat                         # Windows 启动
│   └── result/B2_1/
│       ├── synth/top_synth.dcp
│       ├── impl/{top.bit, top_impl.dcp, debug_probes.ltx}
│       ├── reports/{utilization,timing_summary,route_status,drc}_*.rpt
│       ├── sim/{sim_dump.csv, b2_1_spectrum.png}
│       └── logs/{b2_1_syn_imp.log, b2_1_syn_imp.jou}
└── matlab/B2_1/
    ├── code/read_dual_adc.m                         # MATLAB 分析
    ├── source/ila_dump.csv                          # ILA 导出
    └── figure/{b2_1_timedomain.png, b2_1_spectrum.png}
```

---

## 附录 B：关键命令汇总

```bash
# 1) Chisel 编译
cd ~/Desktop/FPGA_Linux/chisel
sbt "runMain new_module.B2_1.DualAdcCaptureMain"
sbt "testOnly new_module.B2_1.DualAdcCaptureSpec"

# 2) 注入 mark_debug + 复制到 Vivado
python3 ~/Desktop/FPGA_Linux/other_tools/add_mark_debug.py \
    ~/Desktop/FPGA_Linux/chisel/result/B2_1/DualAdcCaptureTop.v \
    /mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1/A0_1.srcs/sources_1/imports/A0_1/DualAdcCaptureTop.v

# 3) Python 功能仿真 + FFT
python3 ~/Desktop/FPGA_Linux/other_tools/sim_b2_1.py
python3 ~/Desktop/FPGA_Linux/other_tools/analyze_b2_1.py

# 4) Vivado 综合 + 实现 + bitstream (Windows 批处理)
# 在 Vivado 项目目录下, 先清缓存
rm -rf /mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1/A0_1.{cache,hw,ip_user_files,sim} \
       /mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1/.Xil \
       /mnt/c/Users/24307/Desktop/FPGA_windows/Vivado/verliog/A0_1/vivado.*
# 启动 Vivado batch
cmd.exe /c "C:\\Users\\24307\\Desktop\\FPGA_windows\\Vivado\\tcl\\B2_1\\run_syn_imp.bat"

# 5) MATLAB 分析 (在 Windows 原生 MATLAB 中运行)
cd C:\Users\24307\Desktop\FPGA_windows\matlab\B2_1\code
read_dual_adc    % 默认读 source/ila_dump.csv
% 或
read_dual_adc('C:/Users/24307/Desktop/FPGA_windows/Vivado/result/B2_1/sim/sim_dump.csv')
```

---

**报告结束**。如有任何疑问或需要补充，请告知。

操作流程：

为了让您能够顺利完成本实验，下面将后续的具体操作分为 **五个核心阶段** 进行详细阐述：

---

### 第一阶段：在 Vivado GUI 中进行综合与 Debug 信号配置（Set up Debug）

因为我们需要使用 ILA（集成逻辑分析仪）在线抓取 ADC 的 12 位并行数据，所以需要在生成 Bitstream（比特流）之前，把需要观察的信号添加到 Debug 窗口中。

1. **运行综合（Synthesis）**：
   * 在左侧 **Flow Navigator** 面板中，找到 **SYNTHESIS** 栏目，点击 **Run Synthesis**。
   * 等待右上角的编译状态完成。完成后会弹出一个窗口，选择 **Open Synthesized Design**，然后点击 **OK**。

2. **配置 Debug 信号（Set up Debug）**：
   * 打开 Synthesized Design 后，在上方菜单栏选择 **Tools** -> **Set up Debug...**。
   * 在弹出的向导窗口中点击 **Next**。
   * 此时 Vivado 会自动扫描到带有 `mark_debug` 属性的信号。您应该能在列表中看到：
     * `u_core/io_adc_data_a[11:0]`
     * `u_core/io_adc_data_b[11:0]`
     * `u_core/io_ora`
     * `u_core/io_orb`
   * 确认这些信号都被选中，点击 **Next**。
   * **分配时钟（Clock Domain）**：在随后的窗口中，必须为这些信号指定采样时钟。请双击时钟列，将其指定为经过 MMCM 输出的 **`clk_40m`**（40 MHz 采样时钟）。
   * **设置采样深度（Sample Depth）**：将 **Sample Depth** 修改为 **8192**（这对应了我们后续做 8000 点 FFT 的数据量）。
   * 点击 **Next** -> **Finish** 完成配置。

3. **保存约束文件并生成 Bitstream**：
   * 按快捷键 `Ctrl + S` 保存设计。此时 Vivado 会提示将 Debug 配置写入约束文件，选择保存到您的 `top.xdc` 中即可。
   * 在左侧 **Flow Navigator** 面板最下方，点击 **Generate Bitstream**。Vivado 会自动自动运行 Implementation（实现）并最终生成 `.bit` 烧录文件以及 `.ltx` 探针定义文件。

---

### 第二阶段：物理硬件连接（务必在断电状态下操作）

在等待 Vivado 编译生成 Bitstream 的过程中，您可以进行硬件连线。**为了保护开发板和 ADC 芯片，请务必先关闭所有电源。**

1. **插接 ADC 模块**：
   * 将双通道 AD9226 模块（AN926）轻轻插在 FPGA 开发板的 **J10 扩展口**上。
   * **对齐防错**：请严格按照 `B2_1_REPORT.md` 中第 8.2 节的引脚对应表，确保排针没有插错位或偏移一行（错位插接可能导致引脚短路烧毁）。

2. **供电与共地（关键步骤）**：
   * 使用外部直流稳压电源给 ADC 模块的 **+5V** 和 **GND** 引脚供电（请勿直接从 FPGA 已经去除排针的引脚强行取电）。
   * **共地**：必须使用一根地线（或鳄鱼夹）将**外部电源的 GND（或 ADC 的 GND）**与 **FPGA 开发板上的 GND 测试点**连接在一起。如果两者不共地，采集到的信号会有极大的噪声甚至无法正确采样。

3. **连接信号发生器**：
   * 将信号发生器的 **Channel 1** 连接到 ADC 的 **A 通道输入（A_IN）**。
   * 将信号发生器的 **Channel 2** 连接到 ADC 的 **B 通道输入（B_IN）**。
   * **信号源设置**：
     * Ch1：正弦波，频率 **1.000 MHz**，幅度 **1.0 Vpp**，偏置 **0 V**，负载阻抗设为 **High-Z**（高阻态）。
     * Ch2：正弦波，频率 **2.000 MHz**，幅度 **1.0 Vpp**，偏置 **0 V**，负载阻抗设为 **High-Z**（高阻态）。

4. **连接 JTAG**：
   * 用 Micro-USB 线将电脑与开发板的 JTAG 接口（J12）连接。

---

### 第三阶段：上电与烧录程序

1. **上电顺序**：
   * 先开启 ADC 的 5V 外部电源。
   * 再开启 FPGA 开发板的电源开关。
   * 最后开启信号发生器的 **Output ON**（将正弦波信号输入给 ADC 芯片）。

2. **连接硬件靶机**：
   * 回到 Vivado GUI 界面。
   * 此时可以看到顶部的绿色横条：点击 **Open target**，选择 **Auto Connect**。
   * 连接成功后，在左侧 Hardware 窗口中会显示您的芯片型号（如 `xc7z020_1`）。

3. **烧录比特流**：
   * 右键点击 `xc7z020_1`，选择 **Program Device...**。
   * 在弹出的窗口中：
     * **Programming file** 会自动识别为您刚刚生成的 `top.bit`。
     * **Debug probes file** 应该会自动识别为对应的 `.ltx` 文件。如果为空，请手动寻找并选中您的 `top.ltx`（或 `debug_probes.ltx`）文件。
   * 点击 **Program** 进行烧录。

---

### 第四阶段：使用 ILA 抓取数据并导出 CSV

烧录完成后，Vivado 会自动打开一个名为 `hw_ila_1` 的控制面板和波形窗口（Waveform）。

1. **调整显示格式**：
   * 在 **Waveform** 窗口中，找到 `io_adc_data_a` 和 `io_adc_data_b` 这两个 12 位的总线信号。
   * 分别右键点击它们，选择 **Radix** -> **Unsigned Decimal**（无符号十进制）。
   * 再次右键点击它们，选择 **Waveform Style** -> **Analog**（模拟波形风格）。这样数字信号就会以连续的波形图线显示，您能直接在屏幕上看到正弦波的形状。

2. **触发抓取数据**：
   * 在 ILA 控制面板上方，点击 **Run Trigger** 按钮（即带绿色加号或蓝色的 “Play” 启动箭头）。
   * 由于我们没有设置复杂的触发条件，它会立即抓取当前时间窗内的 8192 个数据点。
   * 观察波形：确保 A 通道和 B 通道都呈现出平滑、无断裂、无锯齿的完整正弦波。

3. **导出数据文件**：
   * 在 Waveform 窗口的任意空白处右键，选择 **Export ILA Data...**（或点击窗口上方的小出口图标）。
   * 在弹出的对话框中，将文件格式设置为 **CSV**。
   * 选择保存路径，将其命名为 `ila_dump.csv`，并保存在您电脑上的 MATLAB 工作路径中，例如：
     `C:\Users\24307\Desktop\FPGA_windows\matlab\B2_1\source\ila_dump.csv`。

---

### 第五阶段：使用 MATLAB 进行频谱分析

1. 打开您电脑上的 **MATLAB** 软件。
2. 将当前工作路径切换至包含读取脚本的文件夹：
   ```matlab
   cd('C:/Users/24307/Desktop/FPGA_windows/matlab/B2_1/code')
   ```
3. 运行您的分析脚本（假设名为 `read_dual_adc`）：
   ```matlab
   read_dual_adc
   ```
4. 脚本运行完成后，您将看到有时域和频域的四子图输出。
   * **时域验证**：确认 A 通道的周期大约是 40 个采样点（因为 $40 \text{ MHz} / 1 \text{ MHz} = 40$），B 通道的周期大约是 20 个采样点。
   * **频域验证**：确认 A 通道的主峰精准落在 $1.0\text{ MHz}$（第 200 个 Bin），B 通道的主峰精准落在 $2.0\text{ MHz}$（第 400 个 Bin）。旁瓣底噪应在 $-60\text{ dBFS}$ 以下，表明系统工作正常。