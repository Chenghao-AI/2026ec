# STM32F407 与 FPGA UART 通信协议

## 1. 使用场景

本协议用于 STM32F407 与 FPGA 之间的双向串口通信。

- STM32F407：负责发送“开始测量”等控制命令，接收 FPGA 的测量结果，并将结果发送到串口屏显示。
- FPGA：负责 ADC 采样、时域与频域分析，并将完整测量结果发送给 STM32。

测量结果包括：

- 至少 3.5 个周期的时域波形数据
- 峰峰值 `Vpp`
- 真有效值 `Vrms`
- 原始频谱点数
- 原始频谱的起始频率、频点间隔和幅值数组

原始频谱点数最大为 10000。STM32 接收原始频谱后，从中搜索并提取基波和谐波的频率与幅值。

---

## 2. UART 参数

STM32 使用 USART2 与 FPGA 通信。

通信参数：

```text
通信方式：异步 UART
波特率：460800 bit/s
数据位：8 bit
校验位：None
停止位：1 bit
硬件流控：Disable
数据方向：Receive and Transmit
电平标准：3.3 V TTL
```

即标准的：

```text
460800-8-N-1
```

硬件连接：

```text
STM32 USART2_TX  → FPGA UART_RX
STM32 USART2_RX  ← FPGA UART_TX
STM32 GND        ↔ FPGA GND
```

STM32 建议配置 USART2_RX DMA，并使用 UART 空闲中断或 `HAL_UARTEx_ReceiveToIdle_DMA()` 接收完整数据流。

---

## 3. 统一通信帧格式

STM32 与 FPGA 发送的所有命令和数据均使用同一种外层帧结构：

```text
┌────────┬────────┬────────┬──────────────┬──────────────┬────────┐
│ 帧头   │ 帧类型 │ 序列号 │ Payload长度  │ Payload      │ CRC16  │
├────────┼────────┼────────┼──────────────┼──────────────┼────────┤
│ 2 Byte │ 1 Byte │ 1 Byte │ 2 Byte       │ N Byte       │ 2 Byte │
└────────┴────────┴────────┴──────────────┴──────────────┴────────┘
```

实际发送顺序：

```text
AA 55 | TYPE | SEQ | LEN_H LEN_L | PAYLOAD... | CRC_H CRC_L
```

所有多字节数据统一采用大端序，即高字节先发送。

例如：

```text
uint16_t 0x1234 → 12 34
uint32_t 100000 → 00 01 86 A0
```

---

## 4. 外层字段定义

### 4.1 帧头

固定为：

```text
AA 55
```

作用：

- 标志一帧数据的开始
- STM32 丢失同步后可重新寻找下一帧
- STM32 仅在“等待帧头”状态下搜索 `AA 55`

注意：帧头是两个字节，不是两个 bit。

### 4.2 帧类型 TYPE

建议定义：

```c
#define FRAME_CMD_START         0x01U
#define FRAME_CMD_STOP          0x02U
#define FRAME_CMD_RESEND        0x03U
#define FRAME_ACK               0x10U
#define FRAME_MEASURE_RESULT    0x20U
#define FRAME_ERROR             0x7FU
```

其中最重要的是：

```text
FRAME_MEASURE_RESULT = 0x20
```

它表示 FPGA 正在发送一整套完整测量结果。

帧类型不是分别表示 Vpp、Vrms、频率或幅值，而是用于说明整个 Payload 应按照哪一种数据结构解析。

### 4.3 序列号 SEQ

长度：1 Byte。

STM32 每启动一次新测量，序列号加 1。FPGA 返回测量结果时使用相同序列号。

作用：

- 判断返回结果是否属于当前测量
- 避免把上一轮迟到的数据误认为当前结果
- 序列号达到 255 后可回到 0

### 4.4 Payload 长度 LEN

长度：2 Byte，大端序。

它只表示 Payload 区域的字节数，不包括：

- 帧头
- TYPE
- SEQ
- LEN 自身
- CRC16

不同帧类型可以有不同 Payload 长度；同一种测量结果帧也会因为波形点数不同而具有不同长度。

STM32 收到 LEN 后，即可准确知道接下来需要接收多少个 Payload 字节。

### 4.5 CRC16

使用：

```text
CRC-16/CCITT-FALSE
```

参数：

```text
Polynomial：0x1021
Initial Value：0xFFFF
Input Reflected：False
Output Reflected：False
Final XOR：0x0000
CRC发送顺序：高字节在前
```

CRC 覆盖范围：

```text
TYPE + SEQ + LEN_H + LEN_L + Payload
```

帧头 `AA 55` 不参与 CRC。

STM32 计算出的 CRC 与接收 CRC 一致时，才允许使用该帧数据；否则丢弃并请求 FPGA 重发。

---

## 5. 开始测量命令帧

STM32 向 FPGA 发送：

```text
AA 55 | 01 | SEQ | 00 01 | MODE | CRC_H CRC_L
```

建议 Payload：

```text
MODE：1 Byte
```

定义：

```text
0x01：开始一次完整测量
```

FPGA 校验成功后开始采样、计算并发送完整测量结果。

---

## 6. 完整测量结果帧

帧类型：

```text
TYPE = 0x20
```

完整结构：

```text
AA 55 | 20 | SEQ | LEN_H LEN_L | 测量结果Payload | CRC_H CRC_L
```

### 6.1 测量结果 Payload 排列

```text
状态码
波形点数 N
采样间隔 dt
N 个波形电压值
峰峰值 Vpp
真有效值 Vrms
原始频谱点数 K
频谱起始频率
频点间隔
K 个频谱幅值
```

具体字节格式：

| 字段 | 长度 | 类型 | 单位 |
|---|---:|---|---|
| 状态码 | 1 Byte | `uint8_t` | 0 表示正常 |
| 波形点数 N | 2 Byte | `uint16_t` | 点 |
| 采样间隔 dt | 4 Byte | `uint32_t` | ns |
| 波形数据 | `2 × N` Byte | `int16_t[N]` | 0.01 mV |
| 峰峰值 Vpp | 2 Byte | `uint16_t` | 0.01 mV |
| 真有效值 Vrms | 2 Byte | `uint16_t` | 0.01 mV |
| 原始频谱点数 K | 2 Byte | `uint16_t` | `3 <= K <= 10000` |
| 频谱起始频率 | 4 Byte | `uint32_t` | Hz |
| 频点间隔 | 4 Byte | `uint32_t` | Hz，必须大于 0 |
| 频谱幅值数组 | `2 × K` Byte | `uint16_t[K]` | 0.01 mV |

因此：

```text
Payload长度 = 21 + 2N + 2K
```

因为固定字段长度为：

```text
状态码1 + 波形点数2 + 采样间隔4 + Vpp2 + Vrms2
+ 频谱点数2 + 频谱起始频率4 + 频点间隔4 = 21 Byte
```

### 6.2 时域波形传输方式

波形逻辑上是“时间-电压”二维数组，但因为 ADC 等间隔采样，不需要逐点发送时间。

FPGA只发送：

```text
采样间隔 dt
电压数组 voltage[0...N-1]
```

STM32自行恢复时间：

```text
t[i] = i × dt
```

这样可以减少数据量。

波形电压采用：

```text
int16_t，单位 0.01 mV
```

示例：

```text
100.25 mV → 10025
-50.50 mV → -5050
```

### 6.3 原始频谱传输方式

FPGA 不再提取基波和谐波，而是发送原始频谱。频谱部分依次发送：

```text
原始频谱点数 K
频谱起始频率 spectrum_start_frequency_hz
频点间隔 spectrum_bin_spacing_hz
K 个频谱幅值 spectrum_amplitude_001mv[0...K-1]
```

原始频谱逻辑上是“频率-幅值”二维数组。由于 FFT 频点等间隔，不需要逐点重复发送频率。STM32 自行恢复第 `i` 个频点的频率：

```text
frequency_hz[i] =
    spectrum_start_frequency_hz
    + i × spectrum_bin_spacing_hz
```

频谱幅值采用：

```text
uint16_t，单位 0.01 mV
```

原始频谱点数必须满足：

```text
3 <= K <= 10000
```

STM32 读取频谱元数据后循环解析幅值：

```c
for (uint16_t i = 0; i < spectrum_point_count; i++)
{
    spectrum_amplitude_001mv[i] = Read_U16_BE();
}
```

频谱数据放在 Payload 最后，因此解析完 `K` 个幅值后，Payload 应当正好结束。STM32 随后从原始频谱中搜索并提取基波和谐波的频率与幅值。

---

## 7. STM32 解析逻辑

STM32 接收流程：

```text
搜索帧头 AA 55
→ 读取 TYPE
→ 读取 SEQ
→ 读取 Payload 长度 LEN
→ 接收 LEN 个 Payload 字节
→ 接收 CRC16
→ 校验 CRC
→ 根据 TYPE 选择解析函数
→ 保存测量结果
→ 主循环更新串口屏
```

解析 `FRAME_MEASURE_RESULT` 时，通过偏移量 `offset` 顺序读取：

```text
status
N
dt
N个波形点
Vpp
Vrms
K
频谱起始频率
频点间隔
K个频谱幅值
```

解析完成后必须检查：

```text
offset == Payload长度
```

否则丢弃该帧。

同时还应检查：

```text
2 <= N <= 2048
3 <= K <= 10000
频点间隔 > 0
Payload长度 == 21 + 2N + 2K
```

---

## 7.1 STM32 最大波形点数

STM32 端明确支持的最大波形点数为：

```text
FPGA_MAX_WAVE_POINTS = 2048
```

波形数组使用 `int16_t`，因此占用内存：

```text
2048 × 2 Byte = 4096 Byte
```

该上限能够覆盖 4 MHz 采样率、10 kHz 最低基波频率、至少 3.5 个周期的最坏情况：

```text
N = 3.5 × 4,000,000 / 10,000 = 1400 点
```

2048 点可以覆盖 1400 点需求，并保留足够余量。STM32 接收后必须检查：

```text
2 <= N <= 2048
```

若超出范围，则丢弃该帧，避免数组越界。

## 7.2 STM32 最大原始频谱点数

STM32 端明确支持的最大原始频谱点数为：

```text
FPGA_MAX_SPECTRUM_POINTS = 10000
```

频谱幅值数组使用 `uint16_t`，因此占用内存：

```text
10000 × 2 Byte = 20000 Byte
```

STM32 接收后必须检查：

```text
3 <= K <= 10000
频点间隔 > 0
```

若超出范围或频点间隔为 0，则丢弃该帧，避免数组越界或无法恢复频率轴。


## 8. STM32 测量结果数据结构

```c
#define FPGA_MAX_WAVE_POINTS      2048U
#define FPGA_MAX_SPECTRUM_POINTS  10000U

typedef struct
{
    uint8_t status;

    uint16_t wave_point_count;
    uint32_t sample_interval_ns;
    int16_t waveform_001mv[FPGA_MAX_WAVE_POINTS];

    uint16_t vpp_001mv;
    uint16_t vrms_001mv;

    uint16_t spectrum_point_count;
    uint32_t spectrum_start_frequency_hz;
    uint32_t spectrum_bin_spacing_hz;
    uint16_t spectrum_amplitude_001mv[FPGA_MAX_SPECTRUM_POINTS];

    uint8_t sequence;
    uint8_t valid;
} FPGA_MeasureResult_t;
```

串口协议解析完成后，将结果写入该结构体。屏幕模块只读取此结构体，不直接处理原始 UART 字节流。

---

## 9. 帧发送节奏、ACK 与重发约束

### 9.1 帧内字节间隔

FPGA 发送一帧数据时，任意相邻两个字节之间的间隔不得超过：

```text
50 ms
```

若 STM32 在一帧尚未接收完成时检测到连续 50 ms 没有新字节到达，则认为该帧传输中断，丢弃当前未完成帧并重新等待帧头 `AA 55`。

### 9.2 成功接收后的 ACK

STM32 成功完成以下全部检查后，向 FPGA 发送 ACK：

- 帧头正确
- 帧类型合法
- Payload 长度合法
- CRC16 正确
- `2 <= N <= 2048`
- `3 <= K <= 10000`
- 频点间隔大于 0
- Payload 长度满足 `21 + 2N + 2K`
- 最终解析偏移量等于 Payload 长度

ACK 帧格式：

```text
AA 55 | 10 | 原SEQ | 00 00 | CRC_H CRC_L
```

说明：

- `TYPE = 0x10`
- `SEQ` 使用被确认数据帧的原序列号
- `Payload长度 = 0`
- ACK 帧没有 Payload
- CRC 覆盖 `TYPE + SEQ + LEN_H + LEN_L`

### 9.3 CRC 或格式错误后的重发请求

若 STM32 检测到 CRC 错误或任一协议格式错误，则发送重发请求：

```text
AA 55 | 03 | 原SEQ | 00 00 | CRC_H CRC_L
```

说明：

- `TYPE = 0x03`
- `SEQ` 使用出错数据帧的原序列号
- `Payload长度 = 0`
- 重发请求没有 Payload
- CRC 覆盖 `TYPE + SEQ + LEN_H + LEN_L`

FPGA 必须保存最近一帧完整测量结果。收到 `FRAME_CMD_RESEND` 后，直接重发上一帧，不必重新采样和计算。

### 9.4 下一帧发送条件

FPGA 完整发送一帧后，必须等待 STM32 返回 ACK，才能开始下一次测量结果传输。若收到重发请求，则优先重发上一帧。若在约定超时时间内未收到 ACK，可重发上一帧；建议最多重试 3 次，仍失败则进入通信错误状态。

## 10. 异常处理

STM32 应执行以下处理：

```text
帧头错误：继续搜索 AA 55
帧内超过50 ms未收到下一字节：丢弃当前未完成帧
Payload长度超限：丢弃并发送重发命令
CRC错误：丢弃并发送重发命令
SEQ不匹配：丢弃旧结果
N不满足2 <= N <= 2048：丢弃并发送重发命令
K不满足3 <= K <= 10000：丢弃并发送重发命令
频点间隔为0：丢弃并发送重发命令
Payload长度不等于21 + 2N + 2K：丢弃并发送重发命令
解析结束位置不等于Payload长度：丢弃并发送重发命令
完整接收且全部检查通过：发送ACK
```

FPGA 应保存最近一帧完整结果，以便收到 `FRAME_CMD_RESEND` 后直接重发，无需重新采样。

---

## 11. 最终协议结论

统一外层格式：

```text
AA 55 | TYPE | SEQ | PAYLOAD_LEN | PAYLOAD | CRC16
```

完整测量结果 Payload：

```text
状态码
+ 波形点数N
+ 采样间隔dt
+ N个波形电压点
+ Vpp
+ Vrms
+ 原始频谱点数K
+ 频谱起始频率
+ 频点间隔
+ K个频谱幅值
```

这套协议与当前 STM32 HAL 库解析代码保持一致，关键约束为：

```text
2 <= N <= 2048
3 <= K <= 10000
频点间隔 > 0
Payload长度 = 21 + 2N + 2K
帧内相邻字节间隔 <= 50 ms
成功接收后发送 ACK
CRC或格式错误时发送重发请求
FPGA收到ACK后才继续下一次传输
```

这套协议可满足 STM32 与 FPGA 之间快速、准确并可恢复的测量数据通信。
