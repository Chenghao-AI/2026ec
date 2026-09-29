# Agent 调试代码 - 下板 ILA 查看频谱完整工作流

## 概述

本文档记录基于 **Vivado 2019.1 + ILA + MATLAB** 的 FPGA 硬件调试完整工作流。核心目标：通过 JTAG 将 FPGA 内部 ILA 探针数据实时抓取到 PC，进行频谱可视化分析。

---

## 1. 文件体系总览

```
FPGA_windows/
├── Vivado/
│   ├── tcl/2026_G/                    ← Vivado TCL 自动化脚本
│   │   ├── build.tcl                  ⭐ 主构建：综合 → 布局布线 → 写 bitstream
│   │   ├── gen_ila.tcl                ⭐ 生成 ILA IP
│   │   │
│   │   ├── ── 硬件调试 TCL ──────────
│   │   ├── hw_debug2.tcl              ⭐ 核心：连接 → 编程 → arm ILA → 等待触发 → 上传 CSV
│   │   ├── full_capture.tcl           完整捕获：等待 STATUS=FULL（buffer 填满）
│   │   ├── immediate_capture.tcl      立即触发模式测试
│   │   ├── capture_fft.tcl            FFT 捕获：设 DATA_DEPTH=256 快速填满
│   │   ├── force_capture.tcl          强制捕获（失败：stop_hw_ila 命令不存在）
│   │   │
│   │   ├── ── ILA 属性检查 TCL ─────
│   │   ├── check_ila_props.tcl        列出 ILA 所有属性
│   │   ├── check_ila_props2.tcl      额外属性检查
│   │   ├── check_current.tcl          检查当前状态
│   │   ├── check_cmds.tcl             检查可用命令
│   │   ├── check_cmds2.tcl
│   │   ├── check_cmds3.tcl
│   │   ├── check_probes.tcl           检查 probes
│   │   ├── check_ila_run.tcl          检查 ILA 运行状态
│   │   ├── check_ila2~12.tcl         各种 ILA 测试迭代
│   │   │
│   │   ├── ── 辅助 TCL ─────────────
│   │   ├── add_ila_sources.tcl        添加 ILA 源文件
│   │   ├── add_ila_to_project.tcl     添加 ILA 到项目
│   │   ├── replace_ila.tcl            替换 ILA
│   │   ├── regen_ila.tcl             重新生成 ILA
│   │   ├── create_new_ila.tcl        创建新 ILA
│   │   ├── reset_ila.tcl             重置 ILA
│   │   ├── add_sources.tcl           添加源文件
│   │   ├── synth_only.tcl            仅综合
│   │   ├── sim.tcl                   仿真
│   │   ├── direct_read.tcl           直接读取
│   │   ├── direct_write.tcl          直接写入
│   │   ├── capture_correct.tcl       正确捕获
│   │   ├── final_capture.tcl         最终捕获
│   │   ├── final_v2.tcl              最终版本2
│   │   ├── capture_full.tcl          完整捕获
│   │   ├── capture_v6.tcl            捕获版本6
│   │   ├── small_capture.tcl         小数据捕获
│   │   ├── check_upload.tcl          检查上传
│   │   │   (共 45 个 tcl 文件)
│   │   │
│   │   ├── mk_hann_rom.py            ⭐ 生成 Hann 窗 ROM 数据
│   │   ├── fix_tcl_brackets.py       修复 TCL 括号
│   │   └── clean_xpr.py              清理 XPR 项目
│   │
│   ├── other_tools/                   ← 独立 Python 工具
│   │   ├── analyze_ila_data.py       ⭐ 分析 ILA CSV 数据（频谱分析）
│   │   ├── add_ila_to_project.py     添加 ILA 到项目
│   │   ├── fix_ila.py                修复 ILA 问题
│   │   └── gen_ila_xci.py            生成 ILA XCI 文件
│   │
│   ├── verliog/A0_1/                  ← Vivado 工程
│   │   ├── A0_1.xpr                  工程文件
│   │   └── A0_1.srcs/                源码
│   │       ├── sources_1/ip/         IP 核（FFT、CORDIC、ILA）
│   │       ├── sources_1/imports/    Verilog 源文件
│   │       └── constrs_1/            约束文件
│   │
│   └── result/2026_G/                ← 测试结果目录
│       ├── impl/                      综合实现结果
│       │   ├── top.bit               ⭐ FPGA 比特流
│       │   └── top.ltx               ⭐ ILA 探针文件
│       ├── hw/                        硬件调试结果
│       │   ├── ila_data.csv          ⭐ ILA 捕获的原始数据
│       │   └── ila_data_full.csv    完整 ILA 数据
│       └── sim/                       仿真结果
│
├── matlab/2026_G/                     ← MATLAB 分析
│   ├── code/
│   │   ├── plot_ila_spectrum.m       ⭐ 从 ILA CSV 绘制频谱图
│   │   ├── debug_ila.m               调试 ILA 数据
│   │   └── plot_spectrum.m           从仿真 CSV 绘制
│   ├── figure/                        生成的图片
│   └── result/                        分析报告
│
└── other_tools/                       ← 通用工具
    ├── gen_hann_table.py             生成 Hann 窗表
    ├── gen_coeff_mem_2026_G.py       生成系数存储器
    └── gen_luts_2026_G.py            生成 LUT 表
```

---

## 2. 核心工作流

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          完整调试工作流                                  │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   1. 构建    │───▶│  2. 硬件连接  │───▶│  3. 触发捕获  │───▶│  4. 数据导出  │
│  build.tcl   │    │ hw_debug2.tcl│    │ run_hw_ila   │    │upload_hw_ila │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
                                                                          │
                                                                          ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  7. 迭代优化  │◀───│  6. 分析报告  │◀───│  5. 频谱绘图  │◀───│ CSV 文件     │
│  修改代码     │    │ analyze_ila  │    │ plot_spectrum│    │ila_data.csv  │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

---

## 3. 详细步骤

### 3.1 构建阶段 (build.tcl)

```tcl
# 功能：综合 → 布局布线 → 生成 .bit + .ltx
# 命令：
vivado -mode batch -nolog -nojournal -source build.tcl

# 输出：
#   result/2026_G/impl/top.bit    ← FPGA 比特流
#   result/2026_G/impl/top.ltx    ← ILA 探针文件
```

**关键参数**：
- ILA DATA_DEPTH = 8192
- TRIGGER_MODE = BASIC_ONLY (只读)
- TRIGGER_POSITION 可设置 (默认 4096)

### 3.2 硬件调试阶段 (hw_debug2.tcl)

```tcl
# 功能：连接 FPGA → 编程 → arm ILA → 监控状态 → 上传数据

# 核心流程：
1. open_hw + connect_hw_server (localhost:3121)
2. open_hw_target → current_hw_device
3. set_property PROGRAM.FILE + PROBES.FILE
4. program_hw_devices → refresh_hw_device -update_hw_probes true
5. set_property CONTROL.TRIGGER_POSITION 8192
6. run_hw_ila (arm ILA)
7. 轮询 STATUS.CORE_STATUS (最多 30s)
8. upload_hw_ila_data + write_hw_ila_data -csv_file
```

**ILA 有效命令**：
- `run_hw_ila $ila` - 触发 ILA 采集
- `upload_hw_ila_data $ila` - 上传数据
- `write_hw_ila_data -csv_file $path $data` - 导出 CSV
- `get_property STATUS.CORE_STATUS $ila` - 查询状态

**已验证不可用**：
- `stop_hw_ila` - 命令不存在
- `get_hw_ila_probes` - 命令不存在
- `set_property CONTROL.TRIGGER_MODE` - 只读属性

### 3.3 数据分析阶段

#### Python 分析 (analyze_ila_data.py)

```python
# 功能：解析 CSV → 找峰值 → 计算频率 → 验证精度

# 输入：ila_data.csv (8 列)
#   Sample, Window, TRIGGER, mag[15:0], bin[10:0], valid, adc[11:0], frame_end

# 输出：
#   - 控制台报告（峰值频率、幅度、误差）
#   - analysis_result.txt

# 关键参数：
FS = 4_000_000      # 4 MHz 采样率
FFT_N = 8192
DELTA_F = 488.28    # Hz 频率分辨率
expected_freq = 200000  # Hz 期望频率
```

#### MATLAB 绘图 (plot_ila_spectrum.m)

```matlab
% 功能：从 ILA CSV 绘制 4 幅图
%   1. 完整频谱 (0~2 MHz)
%   2. 信号区间放大 (180~220 kHz)
%   3. ADC 时域波形
%   4. 局部频谱 (0~600 kHz)

% 输出：
%   figure/ila_spectrum.png    ← 频谱图
%   result/spectrum_report.txt ← 分析报告
```

---

## 4. ILA 探针配置

### 4.1 探针信息（已验证）

```
hw_ila_1 配置：
├── DATA_DEPTH = 8192
├── TRIGGER_MODE = BASIC_ONLY (只读)
├── TRIGGER_POSITION = 4096 (可设置)
├── MAX_DATA_DEPTH = 8192
└── 端口配置：
    ├── PORT_0: WIDTH=13, IS_DATA=0, IS_TRIGGER=0
    ├── PORT_1: WIDTH=12, IS_DATA=0, IS_TRIGGER=0
    ├── PORT_2: WIDTH=13, IS_DATA=0, IS_TRIGGER=0
    ├── PORT_3: WIDTH=16, IS_DATA=0, IS_TRIGGER=0
    ├── PORT_4: WIDTH=1,  IS_DATA=0, IS_TRIGGER=0
    └── PORT_5: WIDTH=1,  IS_DATA=0, IS_TRIGGER=0
```

### 4.2 探针映射

| ILA 探针 | 位宽 | 对应信号 |
|---------|------|---------|
| PORT_0 | 13-bit | mag[15:0] (低13位) |
| PORT_1 | 12-bit | bin[10:0] (低12位) |
| PORT_2 | 13-bit | adc[11:0] (低13位) |
| PORT_3 | 16-bit | mag[15:0] (完整) |
| PORT_4 | 1-bit | valid |
| PORT_5 | 1-bit | frame_end |

---

## 5. 当前测试结果与问题

### 5.1 测试结果

| 测试项 | 状态 | 结果 |
|-------|------|------|
| ILA 属性读取 | ✅ | 成功列出所有属性 |
| ILA arm | ✅ | run_hw_ila 成功 |
| ILA 状态监控 | ✅ | STATUS=FULL 成功 |
| CSV 上传 | ✅ | upload_hw_ila_data 成功 |
| 触发模式修改 | ❌ | TRIGGER_MODE 只读 |
| 立即停止 | ❌ | stop_hw_ila 不存在 |
| probe 读取 | ⚠️ | get_hw_ila_probes 失败 |

### 5.2 已知问题

1. **30秒内未触发 STOPPED**：
   - ILA 状态显示 FULL (buffer 填满)
   - 但 CORE_STATUS = IDLE，未达到 STOPPED 状态
   - 可能原因：FPGA 设计未正常运行（MMCM 未 lock、ADC 无数据）

2. **有效采样点问题**：
   - hw_probes count = 0
   - 可能原因：.ltx 文件与 .bit 文件版本不匹配

### 5.3 排查清单

```
□ FPGA 电源：确认 CH1 5V / 0.5A 供电正常
□ MMCM LOCK：检查 LOCKED 信号是否为高
□ ADC 连接：确认 ADC 板与 FPGA 接线正确
□ AFG 输出：确认信号源开启，频率/幅度设置正确
□ JTAG 连接：确认 hw_server 连接 localhost:3121 正常
□ bit/ltx 匹配：确认 .bit 和 .ltx 是同一次综合生成的
□ 时钟频率：确认 JTAG FREQ 设置 (建议 3 MHz)
```

---

## 6. 关键参数速查

### 6.1 FFT 参数

| 参数 | 值 | 说明 |
|-----|---|-----|
| 采样率 fs | 4 MHz | 50MHz / (16/2) |
| FFT 点数 N | 8192 | 2^13 |
| 分辨率 Δf | 488.28 Hz | 4e6/8192 |
| 频率范围 | 0~2 MHz | Nyquist |
| 目标范围 | 0~1.25 MHz | 2560 bin |

### 6.2 ADC 参数

| 参数 | 值 | 说明 |
|-----|---|-----|
| 位数 | 12-bit | AD9226 |
| 采样率 | 4 MSPS | 匹配 fs |
| 编码 | 偏移二进制 | 0~4095 |
| 转换 | MSB 取反 | 补码 -2048~+2047 |

### 6.3 JTAG 频率设置

```tcl
# 推荐设置
set_property PARAM.FREQUENCY 3000000 $hw_target  ;# 3 MHz (稳妥)
set_property PARAM.FREQUENCY 5000000 $hw_target  ;# 5 MHz (快速)
```

---

## 7. 迭代优化建议

### 7.1 短期优化

1. **增加等待时间**：将 30s 监控改为 60s 或更长
2. **添加状态日志**：每秒打印 STATUS 和 SAMPLE_COUNT
3. **分段捕获**：使用较小 DATA_DEPTH (如 256) 快速测试
4. **触发条件优化**：尝试 PORT_4 (valid) 作为触发条件

### 7.2 中期优化

1. **自动重连**：添加连接失败重试逻辑
2. **批量测试**：循环测试不同频率点
3. **实时绘图**：边捕获边更新 MATLAB 图形
4. **错误恢复**：添加超时、异常处理

### 7.3 长期优化

1. **Tcl 封装**：将常用操作封装为函数库
2. **自动化测试**：写 Python 脚本自动执行完整流程
3. **数据对比**：自动对比仿真与实测数据
4. **报告生成**：自动生成 PDF 测试报告

---

## 8. 脚本执行命令

### 8.1 完整调试流程

```powershell
# 1. 构建
cd C:\Users\24307\Desktop\FPGA_windows\Vivado\tcl\2026_G
& 'C:\Xilinx\Vivado\2019.1\bin\vivado.bat' -mode batch -nolog -nojournal -source build.tcl

# 2. 硬件调试
& 'C:\Xilinx\Vivado\2019.1\bin\vivado.bat' -mode batch -nolog -nojournal -source hw_debug2.tcl

# 3. 分析数据 (Python)
python analyze_ila_data.py

# 4. 绘图 (MATLAB)
matlab -batch "cd('C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code'); plot_ila_spectrum"
```

### 8.2 快速测试

```powershell
# 仅检查 ILA 属性
& 'C:\Xilinx\Vivado\2019.1\bin\vivado.bat' -mode batch -nolog -nojournal -source check_ila_props.tcl

# 小数据量捕获
& 'C:\Xilinx\Vivado\2019.1\bin\vivado.bat' -mode batch -nolog -nojournal -source capture_fft.tcl
```

---

## 9. 文件依赖关系

```
build.tcl
    ├── 输出: impl/top.bit
    ├── 输出: impl/top.ltx
    └── 依赖: verliog/A0_1/A0_1.xpr

hw_debug2.tcl
    ├── 输入: impl/top.bit
    ├── 输入: impl/top.ltx
    ├── 输出: hw/ila_data.csv
    └── 依赖: hw_server localhost:3121

analyze_ila_data.py
    ├── 输入: hw/ila_data.csv
    └── 输出: analysis_result.txt

plot_ila_spectrum.m
    ├── 输入: hw/ila_data_full.csv
    ├── 输出: figure/ila_spectrum.png
    └── 输出: result/spectrum_report.txt
```

---

## 10. 版本记录

| 日期 | 版本 | 修改内容 |
|-----|------|---------|
| 2026-07-30 | v1.0 | 初始版本，记录完整工作流 |

---

## 附录 A：TCL 脚本常用命令

```tcl
# 连接硬件
open_hw
connect_hw_server -url localhost:3121
refresh_hw_server -quiet

# 打开目标
get_hw_targets
open_hw_target $hw_target
set_property PARAM.FREQUENCY 3000000 $hw_target

# 编程
get_hw_devices -filter {NAME =~ "xc7z020*"}
current_hw_device $dev
set_property PROGRAM.FILE $bit_file $dev
set_property PROBES.FILE $ltx_file $dev
program_hw_devices $dev
refresh_hw_device -update_hw_probes true $dev

# ILA 操作
get_hw_ilas
set ila [lindex $ilas 0]
get_property CONTROL.DATA_DEPTH $ila
get_property CONTROL.TRIGGER_MODE $ila
get_property CONTROL.TRIGGER_POSITION $ila
get_property STATUS.CORE_STATUS $ila
set_property CONTROL.TRIGGER_POSITION 8192 $ila
run_hw_ila $ila

# 数据上传
set hw_data [upload_hw_ila_data $ila]
write_hw_ila_data -force -csv_file $csv_path $hw_data

# 清理
close_hw_target
disconnect_hw_server
close_hw
```

---

## 附录 B：CSV 格式说明

```
# ILA CSV 导出格式 (8 列)
Sample, Window, TRIGGER, mag, bin, valid, adc, frame_end
0,      0,      0,       0x0000, 0x000, 0x0,  0x000, 0x0
...
```

| 列索引 | 信号名 | 格式 | 说明 |
|-------|-------|------|-----|
| 0 | Sample | 十进制 | 采样序号 |
| 1 | Window | 十进制 | 窗口编号 |
| 2 | TRIGGER | 十进制 | 触发标记 |
| 3 | mag | 十六进制 | 幅度 (16-bit) |
| 4 | bin | 十六进制 | 频率 bin (11-bit) |
| 5 | valid | 十六进制 | 有效标志 |
| 6 | adc | 十六进制 | ADC 原始数据 (12-bit) |
| 7 | frame_end | 十六进制 | 帧结束标志 |

---

*文档生成时间: 2026-07-30*
