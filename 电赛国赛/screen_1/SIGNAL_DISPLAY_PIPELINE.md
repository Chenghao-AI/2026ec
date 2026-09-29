# 大批量采样数据到屏幕的通用流程

## 1. 先明确“把数据发给屏幕”是什么意思

ST7796 屏幕不能直接理解 ADC 数组、FFT 结果、频率或电压。屏幕只接收 RGB565
像素。因此真正的数据链路是：

```text
ADC / 外部数据包
        ↓
DMA 或接收驱动得到内存数组
        ↓
滤波、校准、FFT、幅值计算等算法
        ↓
signal_display：格式转换 + 大数据压缩
        ↓
plot：把数值映射成网格、波形或频谱像素
        ↓
st7796：通过 SPI 把 RGB565 像素发送到屏幕
```

新增文件：

- `Hardware/signal_display.h`：公开函数、参数和使用说明；
- `Hardware/signal_display.c`：转换、波形包络/频谱最大值压缩和一键绘图实现。

---

## 2. 为什么不能把几千个点直接画到 480 像素屏幕

横屏只有 480 列，实际图表通常只有 400～448 列。假设一次 ADC 采集 4096 点：

- 简单每隔 9 个点抽一个点，可能刚好跳过很窄的尖峰；
- 对频谱求平均会把很窄但很强的载波峰摊薄；
- 建立 480×320 全帧缓存需要约 300 KB，而 MSPM0G3507 只有 32 KB SRAM。

本模块采用：

- 时域波形：每个屏幕 x 列同时保留该时间桶的最小值、最大值，并画成同列竖直包络；
- 频谱：每个频率桶保留最大幅值；
- 临时显示缓冲：波形包络使用两组 480 个 16 位元素，频谱与其复用，最多占
  1920 字节；
- 全部使用静态存储和调用者数组，不使用 `malloc`。

---

## 3. 屏幕侧的两种标准数据格式

### 时域波形

```c
int16_t waveform[];
```

适合表示：

- 正负 ADC 偏差；
- mV、mA、温度等有符号工程量；
- 滤波、相关、解调后的有符号结果。

### 频谱幅值

```c
uint16_t magnitude[];
```

适合表示：

- FFT 幅值；
- FFT 功率归一化结果；
- 各通道能量；
- 任何非负柱状数据。

`signal_display` 的作用，就是把算法的各种原始格式转成这两种格式，再安全压缩
到屏幕宽度。

如果数据来自另一块单片机、串口或外部 SPI，从通信接收缓冲到这里之前还应有
一层数据包解析。推荐数据包至少包含：固定帧头、数据类型、样本数、序号、负载
和 CRC，并明确大小端。解析并校验成功后，再把得到的 `int16_t`/`uint16_t`
数组交给本模块。由于通信接口和包格式尚未确定，本模块不猜测 UART/SPI 协议，
避免把错误字节序或残缺数据直接当成采样值。

---

## 4. ADC 原始码直接显示为电压波形

假设：

- 12 位 ADC，码值 0～4095；
- 输入围绕 1.65 V 偏置；
- 希望屏幕显示为 -1650～+1650 mV；
- DMA 一次得到 4096 点。

所有大型数组必须定义为 `static` 或全局数组，不要定义在函数局部栈中：

```c
#include "signal_display.h"

#define ADC_SAMPLE_COUNT (4096U)

static uint16_t g_adcSamples[ADC_SAMPLE_COUNT];

static const SignalLinearMap g_adcToMillivolts = {
    0U,       /* ADC 输入最小码 */
    4095U,    /* ADC 输入最大码 */
    -1650,    /* 码值 0 映射为 -1650 mV */
    1650      /* 码值 4095 映射为 +1650 mV */
};
```

这里的 `-1650..+1650 mV` 是“相对 1.65 V 偏置”的交流电压，不是 ADC 引脚
对地的绝对电压。如果要显示单端绝对电压，应改为：

```c
static const SignalLinearMap g_adcToAbsoluteMillivolts = {
    0U, 4095U, 0, 3300
};
```

自动量程直接显示：

```c
PlotStyle style = PLOT_STYLE_DARK;

style.traceColor = RGB565(34U, 211U, 238U);
style.traceThickness = 2U;

(void)SignalDisplay_DrawMappedWaveformAuto(
    16U, 122U, 448U, 158U,
    g_adcSamples, ADC_SAMPLE_COUNT,
    &g_adcToMillivolts,
    true,               /* 纵轴关于 0 对称 */
    &style);
```

固定为 ±2000 mV，便于比较不同刷新帧：

```c
(void)SignalDisplay_DrawMappedWaveform(
    16U, 122U, 448U, 158U,
    g_adcSamples, ADC_SAMPLE_COUNT,
    &g_adcToMillivolts,
    -2000, 2000,
    &style);
```

这两个函数会在一次调用中完成：

1. ADC 码线性换算成 mV；
2. 4096 点压缩成不超过 448 列的最小/最大包络；
3. 绘制背景、网格和波形；
4. 通过 SPI 发给 ST7796。

不需要建立 4096 个 `int16_t` 的中间数组。

---

## 5. 已经得到 int16_t 算法结果时

例如滤波或解调输出：

```c
static int16_t g_filteredSamples[2048];
```

固定量程绘制：

```c
(void)SignalDisplay_DrawWaveform(
    16U, 122U, 448U, 158U,
    g_filteredSamples, 2048U,
    -1200, 1200,
    &PLOT_STYLE_DARK);
```

自动量程绘制：

```c
(void)SignalDisplay_DrawWaveformAuto(
    16U, 122U, 448U, 158U,
    g_filteredSamples, 2048U,
    true,
    &PLOT_STYLE_DARK);
```

比赛成品通常推荐固定量程，避免每帧自动缩放造成波形视觉上忽大忽小。

---

## 6. FFT 幅值数组直接显示为频谱

FFT、窗函数和复数取模属于算法层。本模块要求算法层最后提供非负幅值：

```c
static uint16_t g_fftMagnitude[1024];
```

自动满量程显示：

```c
PlotStyle spectrumStyle = PLOT_STYLE_DARK;

spectrumStyle.drawZeroAxis = false;
spectrumStyle.traceColor = RGB565(255U, 190U, 74U);

(void)SignalDisplay_DrawSpectrumAuto(
    16U, 122U, 448U, 158U,
    g_fftMagnitude, 1024U,
    &spectrumStyle);
```

固定满量程显示：

```c
(void)SignalDisplay_DrawSpectrum(
    16U, 122U, 448U, 158U,
    g_fftMagnitude, 1024U,
    2000U,
    &spectrumStyle);
```

内部会对每个屏幕频率桶取最大值，所以即使 1024 个 bin 放进 448 像素宽区域
（默认边框内是 446 个数据列），也不会因为简单抽点而漏掉窄载波峰。

默认样式启用了边框，因此 448 像素宽的区域实际有 446 个频谱数据列；压缩层会
自动使用这 446 列，并把首、末频率桶放在左右边框内侧，DC/最高频端不会被边框
吃掉。

---

## 7. FFT 输出是 uint32_t 功率时

若算法输出的是 32 位幅值、功率或能量数组，可不建立中间数组，一次完成缩放、
压缩和绘制：

```c
static uint32_t g_fftPower[1024];

/* 固定输入满量程，适合比赛成品跨帧比较。 */
(void)SignalDisplay_DrawSpectrumU32(
    16U, 122U, 448U, 158U,
    g_fftPower, 1024U,
    1000000U,
    &spectrumStyle);

/* 不知道满量程时先用自动版本调试。 */
(void)SignalDisplay_DrawSpectrumU32Auto(
    16U, 122U, 448U, 158U,
    g_fftPower, 1024U,
    &spectrumStyle);
```

若需要先生成一份独立显示快照、尽早释放 DMA 原始缓冲，再使用两阶段接口：

```c
static uint32_t g_fftPower[1024];
/* 448 像素宽且启用左右边框时，可用数据列 = 448-2 = 446。 */
static uint16_t g_displayMagnitude[446];

uint16_t displayCount = Signal_ScaleAndReduceSpectrumU32(
    g_fftPower,
    1024U,
    1000000U,             /* 输入功率满量程 */
    1000U,                /* 输出显示满量程 */
    g_displayMagnitude,
    446U);

if (displayCount > 0U) {
    (void)Plot_DrawSpectrum(
        16U, 122U, 448U, 158U,
        g_displayMagnitude, displayCount,
        1000U,
        &PLOT_STYLE_DARK);
}
```

若你的 FFT 库输出交错复数 Q15、Q31 或 float，需要先按该库的输出格式完成
复数取模。不要在没有确认格式前直接把 FFT 输出强制转换成 `uint16_t *`。

---

## 8. 自动寻找载波峰值并显示频率

假设：

- FFT 长度 2048；
- 采样率 500 kHz；
- 使用单边频谱的 bin 0～1024；
- 不想把 DC 当成载波，因此从 bin 1 开始搜索。

```c
SignalSpectrumPeak peak;

if (SignalDisplay_FindSpectrumPeak(
        g_fftMagnitude,
        1025U,
        1U,
        1025U,
        500000U,
        2048U,
        &peak)) {
    Graphics_DrawUInt(30U, 70U, peak.frequencyHz,
                      2U, RGB565(255U,255U,255U),
                      RGB565(12U,39U,58U));
    Graphics_DrawText(126U, 70U, "HZ",
                      2U, RGB565(255U,255U,255U),
                      RGB565(12U,39U,58U));
}
```

`peak.binIndex` 是原始频谱下标，`peak.magnitude` 是原始幅值，
`peak.frequencyHz` 是换算后的频率。

---

## 9. DMA 实时采集时必须管理缓冲区所有权

不要让 DMA 一边改写数组，算法或屏幕函数一边读取同一个数组。最基本结构是：

```text
DMA 正在写缓冲 A（DMA_OWNED）
CPU/FFT 正在读缓冲 B（CPU_OWNED）
        ↓ 一帧采集完成
中断只把完成帧标为 READY，并让 DMA 切到真正空闲的缓冲
        ↓
主循环领取 READY 缓冲，处理完才归还为 FREE
```

伪代码：

```c
#define INVALID_BUFFER (0xFFU)

static volatile uint8_t g_dmaBuffer;
static volatile uint32_t g_droppedFrames;

void DMA_IRQHandler(void)
{
    uint8_t completed = g_dmaBuffer;
    uint8_t next;

    clearDmaInterruptFlag();
    next = findFreeBuffer();             /* 不能返回 READY 或 CPU_OWNED 缓冲 */

    if (next == INVALID_BUFFER) {
        g_droppedFrames++;               /* 没空闲块：丢弃刚采完的这一帧 */
        startDma(completed);              /* 原块仍由 DMA 使用，不交给 CPU */
        return;
    }

    publishReadyBuffer(completed);       /* 放入 READY 队列并保留所有权 */
    markBufferDmaOwned(next);
    g_dmaBuffer = next;
    startDma(next);
}

int main(void)
{
    for (;;) {
        uint8_t buffer = takeReadyBuffer(); /* 原子地从 READY 改为 CPU_OWNED */

        if (buffer != INVALID_BUFFER) {
            run_filter_or_fft(buffer);
            draw_result(buffer);
            releaseBuffer(buffer);       /* 从 CPU_OWNED 改为 FREE */
        }

        /* 键盘和其他状态机仍可在这里运行。 */
    }
}
```

DMA 中断内只切换缓冲、更新状态和置位标志，不要在中断里执行 FFT、文字绘制或
SPI 刷屏。

上面的状态函数是伪代码，需要用临界区或原子操作实现。如果把它简化成单个
`bool frameReady`，就必须明确采用“只保留最新帧、忙时丢帧”的策略。如果一帧
采集时间短于 FFT 加刷屏时间，仅有两个数组仍可能被 DMA 绕回覆盖。比赛代码应
选择以下一种明确策略：

- 三缓冲：DMA 写一个、CPU 处理一个、一个等待/空闲；
- DMA 暂停/触发采集：上一帧处理完再启动下一帧；
- 实时采集但显示降帧：持续采集，只每隔 N 帧处理和显示一次，并统计丢帧；
- 两阶段处理：先调用本模块的 `Signal_Reduce*()` 把大数组压到自己的“可用
  数据列”快照（启用左右边框时为 `width-2`），立即释放原始 DMA 缓冲，再
  慢慢调用 `Plot_*()` 刷屏。

无论采用哪种策略，CPU 正在执行滤波、FFT 或压缩的缓冲都绝不能被 DMA 复用。

---

## 10. 刷新速度与内存纪律

当前屏幕 SPI 约为 4 MHz。单独刷新 448×160 图表区的理论纯像素时间约为：

```text
448 × 160 × 16 bit / 4 MHz ≈ 287 ms
```

因此：

- ADC 可以高速采样；
- FFT 可以按数据帧运行；
- 屏幕没有必要跟随每个采样块刷新；
- 建议只刷新图表区域，当前配置以约 2～3 FPS 为现实目标；
- 页面标题、底栏等静态区域只在切换页面时重画；
- 大型采样/FFT 数组必须使用 `static`/全局存储；
- 不要建立 480×320 全屏帧缓存；
- 不要使用 `malloc`；
- 不要在 ISR 中调用任何 `SignalDisplay_Draw*()`、`Plot_*()` 或 `Graphics_*()`。

当前通用显示代码的静态 RAM 预算约为：

| 模块 | 静态缓冲 | 字节数 |
|---|---:|---:|
| `graphics.c` | 最大字符像素缓存 24×28×2 | 1344 |
| `plot.c` | 行缓存 + 上边界 + 下边界，各 480×2 | 2880 |
| `signal_display.c` | 两组 480×`int16_t` 包络（与频谱复用） | 1920 |
| 合计 | 不含你的采集与 FFT 数组 | 6144 |

工程链接栈已设置为 2048 字节。由于 SysConfig 生成的 `device_linker.cmd` 自带
512 字节默认值，`.cproject` 还会在全部链接输入之后再次追加 2048 字节设置，
确保最终值不被生成文件覆盖；不要删除 linker tool 的 `commandLinePattern`。
MSPM0G3507 的 32 KB SRAM 还要容纳 SysConfig、全局状态、DMA 缓冲和 FFT 工作区。
例如单个 `uint16_t[4096]` 就占 8192 字节，所以确定 FFT 库后必须再看一次链接
生成的 `.map` 文件，确认 `.stack` 为 `0x800` 并检查剩余 SRAM，不能只凭感觉估算。

---

## 11. 接入工程时的初始化与检查清单

启动顺序至少应包含：

```c
#include "ti_msp_dl_config.h"
#include "st7796.h"
#include "signal_display.h"

int main(void)
{
    SYSCFG_DL_init();
    ST7796_Init();

    /* 此后才能调用 Graphics_*、Plot_* 或 SignalDisplay_Draw*。 */
    for (;;) {
    }
}
```

同时确认：

- `graphics.c`、`plot.c`、`signal_display.c`、`st7796.c` 都在工程构建中；
- 调用期间输入数组保持有效，DMA 不会覆盖它；
- 大数组使用全局或 `static` 存储，不放在局部栈上；
- 检查 `SignalDisplay_Draw*()` 的 `bool` 返回值和 `Signal_Reduce*()` 的返回数量；
- 页面切换时先画静态框架，实时循环只更新确实需要变化的区域。

---

## 12. 最常用函数速查

| 数据状态 | 推荐函数 |
|---|---|
| ADC `uint16_t` 原始码，想直接显示 | `SignalDisplay_DrawMappedWaveformAuto()` |
| ADC 原始码，需要固定纵轴 | `SignalDisplay_DrawMappedWaveform()` |
| 已有 `int16_t` 波形 | `SignalDisplay_DrawWaveform()` |
| 已有 `int16_t` 波形，量程未知 | `SignalDisplay_DrawWaveformAuto()` |
| 已有 `uint16_t` FFT 幅值 | `SignalDisplay_DrawSpectrum()` |
| FFT 幅值范围未知 | `SignalDisplay_DrawSpectrumAuto()` |
| `uint32_t` FFT 幅值/功率，固定量程 | `SignalDisplay_DrawSpectrumU32()` |
| `uint32_t` FFT 幅值/功率，量程未知 | `SignalDisplay_DrawSpectrumU32Auto()` |
| `uint32_t` 结果先生成独立显示快照 | `Signal_ScaleAndReduceSpectrumU32()` 后调用 `Plot_DrawSpectrum()` |
| 查载波峰值频率 | `SignalDisplay_FindSpectrumPeak()` |
| 只做 ADC 批量换算，不立刻绘图 | `Signal_ConvertU16ToI16()` |
| 大型 `int16_t` 波形先生成显示快照 | `Signal_ReduceWaveformEnvelopeI16()` |
| ADC 原始码先生成显示快照 | `Signal_MapAndReduceWaveformEnvelopeU16()` |

峰值频率必须从**原始未压缩 FFT bin**中查找；显示压缩后的数组下标只是屏幕桶，
不能再直接按 `bin×Fs/N` 换算频率。Q15、Q31、float 或交错复数 FFT 输出还需
按所选 FFT 库的格式计算幅值/功率，本模块不会猜测其缩放规则。

头文件中的每个函数均带参数约束、返回值和适用场景说明，比赛时可直接在 CCS
中打开 `Hardware/signal_display.h` 作为速查表。
