# SysConfig 配置说明

本示例不会直接修改 `empty.syscfg`。以下名称是推荐命名；SysConfig 版本不同，页面文字
可能略有差异，判断标准是生成的 `ti_msp_dl_config.c/.h` 是否实现了相同硬件连接。

## 1. 推荐 LaunchPad 引脚

现有工程已经占用 OLED、矩阵键盘和 SWD 引脚，建议新增：

| 功能 | MCU 引脚 | LaunchPad 接口 | 理由 |
| --- | --- | --- | --- |
| 功率反馈 ADC | PA25 / ADC0.2 | BoosterPack pin 2 | 当前未占用，官方接口标注 ADC0.2 |
| VCA 控制 DAC | PA15 / DAC_OUT | BoosterPack pin 30 | G3507 外部 DAC12 输出专用引脚 |
| TPA SHUTDOWN | PA27 / GPIO | BoosterPack pin 8 | 当前未占用，靠近接口且无需外设复用 |

PA15 启用 DAC_OUT 后不要再连接外部信号源或配置其他功能。ADC 前端、DAC 反相器和
LaunchPad 必须共地；OUTP/OUTN 仍然不能接地。

## 2. ADC12：`ADC_AGC`

1. 添加一个 **ADC12**，实例选 `ADC0`，命名为 `ADC_AGC`；
2. 模式选 **Single Sample**，12-bit、Unsigned；
3. Conversion Memory 0 输入选 `ADC0.2 / PA25`，参考选 `VDDA/VSSA`；
4. Trigger Source 选 **Event**，不要用软件循环延时触发；
5. Repeat 关闭。ADC 被 arm 后，每个 Timer Event 完成一次单点转换；
6. Sample Timer 使用自动采样，采样时间先留出足够建立时间。外部有源滤波输出阻抗低，
   无需追求 ADC 极限速率；
7. 打开 **FIFO**；
8. 打开 **Configure DMA**；
9. Enabled DMA Triggers 选 `DL_ADC12_DMA_MEM10_RESULT_LOADED`。这是 TI 官方
   `adc12_max_freq_dma` 示例用于 FIFO/DMA 的配置，本项目模块也按它检查；
10. 不需要开 ADC NVIC；本示例轮询 DMA 通道原始完成位。

生成代码应能找到类似内容：

```c
#define ADC_AGC_INST ADC0
DL_ADC12_initSingleSample(... DL_ADC12_TRIG_SRC_EVENT ...);
DL_ADC12_enableFIFO(ADC_AGC_INST);
DL_ADC12_enableDMA(ADC_AGC_INST);
DL_ADC12_enableDMATrigger(
    ADC_AGC_INST, DL_ADC12_DMA_MEM10_RESULT_LOADED);
DL_ADC12_setSubscriberChanID(ADC_AGC_INST, 1);
```

如果你的 SysConfig 在 Event Trigger 下要求不同的 Repeat 设置，以 TI SDK 同版本
`adc12_triggered_by_timer_event` 行为为准：示波器/测试 GPIO 验证必须是每 10 µs 一个
样本，而不是第一次事件后以 ADC 最高速度连续跑。

## 3. ADC 对应 DMA：`DMA_ADC_AGC`

从 ADC 的 **Configure DMA** 页面创建通道，建议使用 Channel 0 并命名
`DMA_ADC_AGC`：

```text
Trigger               ADC0 event
Trigger Type          External
Transfer Mode         Single Transfer
Source Increment      Unchanged
Destination Increment Increment
Source Width          Word
Destination Width     Word
Address Mode          FIFO to Buffer / f2b
```

ADC FIFO 一个 32-bit Word 打包两个 16-bit 样本，所以代码向 DMA 请求
`DEMO_SAMPLE_COUNT/2` 个 Word。不要把 DMA 宽度改成 Half-word，也不要把传输个数当成
字节数。

生成头文件应有：

```c
#define DMA_ADC_AGC_CHAN_ID 0
#define ADC_AGC_INST_DMA_TRIGGER DMA_ADC0_EVT_GEN_BD_TRIG
```

`demo_board_config.h` 中的 `DEMO_AGC_DMA_COMPLETION_INTERRUPT` 必须与通道相符：

```c
Channel 0 -> DL_DMA_INTERRUPT_CHANNEL0
Channel 1 -> DL_DMA_INTERRUPT_CHANNEL1
...
```

若 SysConfig 自动分配了非 0 通道，必须同时改通道 ID 和完成掩码，不能只改一个。

## 4. 采样 Timer：`TIMER_ADC_TRIGGER`

添加一个空闲的 TIMG（例如 SysConfig 允许的 TIMG7/TIMG0，实际以冲突检查为准）：

1. 命名 `TIMER_ADC_TRIGGER`；
2. Periodic、Down Counting、Repeat；
3. Timer clock 配成实际 **1 MHz**；
4. Period 配成 **10 µs**，即 100 kHz；
5. Start Timer 关闭，`rabi_hw_timer_init()` 会启动；
6. Event 1 Publisher 打开 **ZERO_EVENT**，Publisher Channel 设为 `1`；
7. 不打开 ZERO interrupt/NVIC，本例只使用硬件事件；
8. 回到 ADC，把 Event Subscriber Channel 也设为 `1`。

生成代码应包含类似：

```c
DL_TimerG_enableEvent(TIMER_ADC_TRIGGER_INST,
    DL_TIMERG_EVENT_ROUTE_1, DL_TIMERG_EVENT_ZERO_EVENT);
DL_TimerG_setPublisherChanID(..., 1);
DL_ADC12_setSubscriberChanID(ADC_AGC_INST, 1);
```

把生成注释中的 `timerClkFreq` 实际值填入
`DEMO_AGC_TIMER_CLOCK_HZ`。不要看到 CPU 是 32/80 MHz 就直接填 CPU 频率；这里填的是
经过时钟源和 prescaler 后的 Timer 计数频率。

## 5. DAC12：`DAC_GAIN`

1. 添加 **DAC12**，命名 `DAC_GAIN`；
2. 12-bit、Binary、输出使能；
3. 引脚选 `PA15 / DAC_OUT`；
4. FIFO 关闭、DMA Trigger 关闭、Sample Time Generator 关闭；
5. Amplifier 打开；
6. 参考先用 VDDA/VSSA；若改内部/外部 VREF，同步更新高低参考毫伏宏；
7. 初始 Data=0。真正安全关断仍由 TPA SHUTDOWN 下拉保证。

生成头文件应有 `#define DAC_GAIN_INST DAC0`（具体实例由工具决定）。软件只使用
0~1600 mV，外部 OPA2172 反相得到 0~-1.6 V。

## 6. GPIO：`GPIO_AGC`

添加 GPIO Pin Group，命名 `GPIO_AGC`：

```text
Pin name       AMP_SD
Pin            PA27
Direction      Output
Initial output Low
Drive          Standard
```

硬件另加 47~100 kΩ 下拉，确保复位、烧录、代码跑飞时 TPA2000D1 仍关断。生成宏应类似：

```c
#define GPIO_AGC_PORT GPIOA
#define GPIO_AGC_AMP_SD_PIN DL_GPIO_PIN_27
```

## 7. 映射并启用

打开 `demo_board_config.h`：

1. 将 `DEMO_AGC_HW_READY` 从 0 改为 1；
2. 对照 **刚生成的** `Debug/ti_msp_dl_config.h` 填 ADC、DMA、Timer、DAC、GPIO 名称；
3. 若 DMA 不是 Channel 0，修改完成中断掩码；
4. 若 Timer 计数时钟不是 1 MHz，填真实值；
5. 若 DAC 参考不是实测 3.3 V，填真实上下参考；
6. Clean Project 后重新 Build，避免旧生成文件造成假象。

## 8. 上板前的配置自检

- `PA25` 没有再被 GPIO/OPA/Comparator 占用；
- `PA15` 只作为 DAC_OUT，板上没有其他信号驱动它；
- Timer Publisher 和 ADC Subscriber 是同一个 channel；
- ADC 是 Event Trigger，样本间隔实际 10 µs；
- FIFO 开启，DMA 源固定、目标递增、Word 宽；
- DMA 通道与 `DL_DMA_INTERRUPT_CHANNELx` 匹配；
- TPA SHUTDOWN 上电默认低；
- OLED/键盘原有引脚没有被 SysConfig 自动重分配；
- `DEMO_SAMPLE_COUNT` 保持偶数，DMA 缓冲区保持 4-byte 对齐。

## 9. 离线可参考的 SDK 示例

在当前 MSPM0 SDK 中提前收藏：

```text
examples/nortos/LP_MSPM0G3507/driverlib/adc12_max_freq_dma
examples/nortos/LP_MSPM0G3507/driverlib/adc12_triggered_by_timer_event
examples/nortos/LP_MSPM0G3507/driverlib/dac12_fifo_timer_event
```

前两个分别展示 FIFO/DMA 和 Timer Event→ADC。不要只复制其中一个：本综合示例需要把
两条路径同时配置正确。

