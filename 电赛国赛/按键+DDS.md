# MSPM0G3507 按键程控 AD9959 四通道正弦波实验

## 1. 当前结论

本实验可以在工程 `empty_LP_MSPM0G3507_nortos_ticlang` 上实现，矩阵键盘继续复用现有 `keyboard` 模块，AD9959 驱动封装在 `DDS/sin_wave` 中。

当前调整后的 SPI1 引脚选择正确：

- `PB9 = SPI1_SCK`，连接 DDS SCLK；
- `PB8 = SPI1_PICO`，连接 DDS SDIO0/SD0；
- `PB17` 连接 DDS CS，由 GPIO 手动控制；
- 键盘 C1 从 PB8 改到 PB18后，不再与 SPI1_PICO 冲突；
- PB22 不再使用，因此 J5 保持原状即可。

但按当前接线记录，开始代码阶段前还必须完成两项修正：

1. `DDS SDIO3/SD3 → DDS GND`。AD9959 在单比特串行模式下把 SDIO3 用作 SYNC_I/O 输入，官方明确要求不用时接逻辑 0，不能悬空。
2. `DDS PDN/PWR_DWN → DDS GND`。模块原理图中该输入没有板载下拉，悬空可能使 DDS 意外进入掉电状态。

`SDIO1/SD1`、`SDIO2/SD2` 和真正标为 `NC` 的引脚可以保持悬空。

## 2. 最终硬件连接

所有接线、拔线和跳帽操作必须在 LaunchPad 与 DDS 均断电时进行。

### 2.1 4×4 矩阵键盘

| 键盘引脚 | MSPM0G3507 引脚 | 配置用途 |
| --- | --- | --- |
| R1 | PB7 | 行扫描输出 |
| R2 | PB6 | 行扫描输出 |
| R3 | PB0 | 行扫描输出 |
| R4 | PB16 | 行扫描输出 |
| C1 | **PB18** | 列输入、内部上拉 |
| C2 | PB15 | 列输入、内部上拉 |
| C3 | PB1 | 列输入、内部上拉 |
| C4 | PB12 | 列输入、内部上拉 |

只需在 SysConfig 中把原 `KEYBOARD_C1` 的物理引脚从 PB8 改为 PB18；`keyboard.c` 通过生成的引脚宏访问 C1，不需要因为这次换线而改变键值算法。

### 2.2 AD9959 数字接口

| DDS 引脚 | MSPM0G3507/连接点 | 状态与用途 |
| --- | --- | --- |
| SCLK | PB9 | SPI1 硬件时钟 |
| SDIO0 / SD0 | PB8 | SPI1_PICO，单比特写数据 |
| CS | PB17 | GPIO 手动片选，低有效 |
| I/O_UPDATE / IU | PA11 | GPIO，上升沿使寄存器更新生效 |
| RESET / RST | PB20 | GPIO，高脉冲复位 |
| P0 | PB13 | GPIO 输出低 |
| P1 | PA18 | GPIO 输出低 |
| P2 | PA10 | GPIO 输出低 |
| P3 | PA24 | GPIO 输出低 |
| SDIO1 / SD1 | 悬空 | 单比特模式不用 |
| SDIO2 / SD2 | 悬空 | 本实验不读寄存器 |
| SDIO3 / SD3 | **DDS GND** | SYNC_I/O 不使用时必须为低，禁止悬空 |
| PDN / PWR_DWN | **DDS GND** | 禁止悬空，保持正常工作状态 |
| NC | 悬空 | 不连接 |

### 2.3 电源和地

- DDS 模块使用稳定 5 V 电源，建议供电能力不低于 1 A。
- DDS GND、5 V 电源 GND、LaunchPad GND 必须共地。
- 不得把 5 V 接到 MSPM0 的 GPIO、3.3 V 或调试信号脚。
- 初次上电前用万用表确认 5 V 与 GND 没有短路，并逐根检查 PB8、PB9、PB17。

### 2.4 LaunchPad 跳帽状态

| 跳帽 | 当前状态 | 结论 |
| --- | --- | --- |
| J5 | 保持原状 | 正确；PB22 未使用，无需拔除 |
| J8 | 已拔下 | 正确；隔离 PA18 与板载 S1/BSL_Invoke 电路 |
| J22 | 已拔下 | 正确；隔离 PA11 与板载 XDS UART 发送端 |
| J21 | 可保持原状 | PA10 连接到 XDS UART 接收端，不形成输出对冲 |
| SWD/XDS110 跳帽 | 保持正常调试状态 | PA19/SWDIO、PA20/SWCLK 不得占用或改接 |

## 3. 实施目标

### 3.1 DDS 通道对应关系

| 模块 SMA | AD9959 内部通道 | 初始频率 | 频率范围与步进 | 初始 Vpp | Vpp 范围与步进 |
| --- | --- | ---: | --- | ---: | --- |
| S1 | CH0 / IOUT0 | 100 kHz | 100～1000 kHz，步进 100 kHz | 50 mV | 50～200 mV，步进 30 mV |
| S2 | CH1 / IOUT1 | 1000 kHz | 1000～10000 kHz，步进 1000 kHz | 50 mV | 50～200 mV，步进 30 mV |
| S4 | CH2 / IOUT2 | 10000 kHz | 10000～100000 kHz，步进 10000 kHz | 50 mV | 50～200 mV，步进 30 mV |
| S5 | CH3 / IOUT3 | 90000 kHz | 90000～110000 kHz，步进 1000 kHz | 50 mV | 50～200 mV，步进 30 mV |

达到上限后再按一次键，恢复下限：

- 幅度：`50→80→110→140→170→200→50 mVpp`；
- 各通道频率按照上表步进，到上限后回到各自下限。

### 3.2 按键功能

| 键盘按键/返回值 | 功能 |
| --- | --- |
| S1 / 1 | S1/CH0 幅度步进 |
| S2 / 2 | S2/CH1 幅度步进 |
| S3 / 3 | S4/CH2 幅度步进 |
| S4 / 4 | S5/CH3 幅度步进 |
| S5 / 5 | S1/CH0 频率步进 |
| S6 / 6 | S2/CH1 频率步进 |
| S7 / 7 | S4/CH2 频率步进 |
| S8 / 8 | S5/CH3 频率步进 |

程序必须按“新按下一次只步进一次”处理：按住期间不连续步进，检测到释放后才接受下一次按键。

## 4. 工程与通信方法

### 4.1 工程结构

保留现有：

```text
empty_LP_MSPM0G3507_nortos_ticlang/
├─ empty.c
├─ empty.syscfg
├─ keyboard/
│  ├─ keyboard.c
│  └─ keyboard.h
└─ DDS/
   └─ sin_wave/
      ├─ sin_wave.c
      └─ sin_wave.h
```

职责划分：

- `keyboard`：只负责扫描键盘并返回键值；
- `sin_wave`：负责 AD9959 初始化、寄存器通信、四通道状态和频率/幅度更新；
- `empty.c`：设置四路六参数范围，将键值映射到相应通道，并保存 Watch 变量。

### 4.2 AD9959 串行模式

本实验采用 AD9959 复位后的单比特串行模式，只向芯片写寄存器：

- SCLK：PB9，由 SPI1 硬件产生；
- SDIO0：PB8，由 SPI1_PICO 硬件发送；
- CS：PB17，由 GPIO 手动拉低和拉高；
- SDIO1、SDIO2不参与通信；
- SDIO3固定接地，防止 SYNC_I/O 意外中止事务；
- 数据为 8 位、MSB first、SPI Mode 0；
- 初始 SPI 时钟使用 1 MHz，适合杜邦线联调；
- 不使用 POCI/MISO、SPI 中断或 DMA。

PB17 虽然可复用为 SPI1_CS1，本工程仍采用 GPIO 手动 CS。这样可以明确保证 AD9959 的“指令字节 + 整个寄存器数据”发送期间 CS 始终保持低，最后一个数据位发送完成后才拉高。SCLK 和 SDIO0仍由 SPI1 硬件完成。

## 5. SysConfig 修改

打开工程根目录的 `empty.syscfg`，只做以下修改。保存后必须确保没有红色错误或引脚冲突。

### 5.1 修改现有 KEYBOARD 实例

保持 R1～R4、C2～C4 的现有配置，只修改：

```text
KEYBOARD / C1：PB8 → PB18
```

最终键盘配置：

| 名称 | 引脚 | Direction | Initial Value | Internal Resistor | Hi-Z | Interrupt |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | PB7 | Output | SET/High | Pull-Up | Enable | Disable |
| R2 | PB6 | Output | SET/High | Pull-Up | Enable | Disable |
| R3 | PB0 | Output | SET/High | Pull-Up | Enable | Disable |
| R4 | PB16 | Output | SET/High | Pull-Up | Enable | Disable |
| C1 | PB18 | Input | 不适用 | Pull-Up | 不适用 | Disable |
| C2 | PB15 | Input | 不适用 | Pull-Up | 不适用 | Disable |
| C3 | PB1 | Input | 不适用 | Pull-Up | 不适用 | Disable |
| C4 | PB12 | Input | 不适用 | Pull-Up | 不适用 | Disable |

### 5.2 新增 DDS_SPI

新增一个 SPI 实例并设置：

| 项目 | 设置值 |
| --- | --- |
| Instance Name | `DDS_SPI` |
| Peripheral | `SPI1` |
| Mode | `Controller` |
| Communication Direction | `PICO only` |
| Frame Format | `Motorola 3-wire` |
| Clock Polarity | `Low / SPO=0` |
| Phase | `First edge / SPH=0` |
| Frame Size | `8 bits` |
| Bit Order | `MSB` |
| Clock Source | `BUSCLK`/默认 |
| Target Bit Rate | `1000000 Hz` |
| Parity、Packing、Loopback | `Disabled` |
| Interrupts | 全部 `Disabled` |
| DMA Events | 全部 `None/Disabled` |

PinMux：

| SPI 信号 | 引脚 |
| --- | --- |
| SCLK | PB9 / SPI1_SCK |
| PICO | PB8 / SPI1_PICO |

`Motorola 3-wire` 表示 MSPM0 SPI 外设不管理 CS，因此 SPI 实例中不要选择 CS0～CS3，也不要分配 POCI。

### 5.3 新增 DDS_PORTA

新增 GPIO 实例：

```text
Instance Name：DDS_PORTA
Port：PORTA
```

包含四个普通推挽输出：

| Pin Name | 引脚 | Initial Value | Internal Resistor | Hi-Z | Interrupt |
| --- | --- | --- | --- | --- | --- |
| IO_UPDATE | PA11 | CLEAR/Low | None | Disable | Disable |
| P1 | PA18 | CLEAR/Low | None | Disable | Disable |
| P2 | PA10 | CLEAR/Low | None | Disable | Disable |
| P3 | PA24 | CLEAR/Low | None | Disable | Disable |

### 5.4 新增 DDS_PORTB

新增 GPIO 实例：

```text
Instance Name：DDS_PORTB
Port：PORTB
```

| Pin Name | 引脚 | Initial Value | Internal Resistor | Hi-Z | Interrupt |
| --- | --- | --- | --- | --- | --- |
| P0 | PB13 | CLEAR/Low | None | Disable | Disable |
| RESET | PB20 | CLEAR/Low | None | Disable | Disable |
| CS | PB17 | **SET/High** | None | Disable | Disable |

RESET 高有效，空闲必须为低；CS 低有效，空闲必须为高。不要设反。

### 5.5 其他配置

- 保持 `SYSCTL.forceDefaultClkConfig = true`；
- 不新增 Timer、PWM、ADC、DAC、DMA 或 NVIC；
- 不修改 PA19/SWDIO、PA20/SWCLK、NRST 和 XDS110 调试配置；
- SDIO1、SDIO2、SDIO3、PDN 均不占用 MCU 引脚，因此不在 SysConfig 中添加对应 GPIO。

## 6. 代码阶段接口约定

`sin_wave.h` 中定义 S1、S2、S4、S5 四个通道配置/输出函数。每个函数只接收六个业务参数：

```text
下限频率kHz，上限频率kHz，频率步进kHz，
下限Vpp_mV，上限Vpp_mV，Vpp步进mV
```

主函数使用：

```text
S1：   100,   1000,   100, 50, 200, 30
S2：  1000,  10000,  1000, 50, 200, 30
S4： 10000, 100000, 10000, 50, 200, 30
S5： 90000, 110000,  1000, 50, 200, 30
```

四个六参数函数用于配置范围并建立初始输出；另外提供通用的“通道频率步进”和“通道幅度步进”辅助接口。DDS 驱动不直接调用 `keyboard_get_key()`，按键与通道的映射留在 `empty.c`，以保持模块可复用。

## 7. 预期结果与测量条件

完成代码后上电，四个 SMA 端口应同时输出正弦波：

- S1：100 kHz、目标 50 mVpp；
- S2：1 MHz、目标 50 mVpp；
- S4：10 MHz、目标 50 mVpp；
- S5：90 MHz、目标 50 mVpp。

按 S1～S8时，只有对应通道的相应参数步进一步，其他通道保持不变。可在 CCS Watch 中观察 `key_value` 以及四通道当前频率、当前目标 Vpp。

Vpp 的定义是 SMA 端接 50 Ω 负载时的峰峰值。AD9959 的幅度寄存器是 10 位比例缩放，不是经过校准的毫伏源；变压器、滤波器和频率响应会产生误差。初次实验先按约 300 mVpp 满量程换算并用 50 Ω 示波器核验；若要求各频点精确达到指定 mV，后续需建立逐通道校准数据。

## 8. 修改 SysConfig 前检查清单

- [ ] 键盘 C1 已实际接到 PB18，PB8 已释放给 DDS SD0。
- [ ] DDS SD0=PB8、SCLK=PB9、CS=PB17。
- [ ] DDS SD1、SD2悬空。
- [ ] DDS SD3已接 DDS GND，不再悬空。
- [ ] DDS PDN/PWR_DWN 已接 DDS GND，不再悬空。
- [ ] DDS NC 保持悬空。
- [ ] J8、J22已拔下；J5保持原状。
- [ ] DDS 使用 5 V，且 DDS、电源、LaunchPad 已共地。
- [ ] PA19、PA20和调试跳帽未改动。

以上硬件项目全部满足后，再按第 5 节手动修改 SysConfig。保存并普通编译成功后，将 `empty.syscfg` 交给代码阶段复核；在配置与代码编译均确认无误前不烧录。

## 9. 依据

- `硬件/DDS_ad9959/原理图.pdf`、`简易使用说明.pdf` 和模块照片；
- Analog Devices《AD9959 Data Sheet》；
- Texas Instruments《MSPM0G350x Mixed-Signal Microcontrollers》数据手册；
- Texas Instruments《LP-MSPM0G3507 LaunchPad Development Kit User's Guide》。
