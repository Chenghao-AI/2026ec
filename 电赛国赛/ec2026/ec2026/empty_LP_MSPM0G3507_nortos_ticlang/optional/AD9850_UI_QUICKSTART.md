# AD9850 + MSPM0G3507 UI 快速联调

这份说明对应 `examples/ad9850_ui/main.c` 独立入口。目标是上电默认输出 1 MHz
正弦波，并通过 OLED 菜单立即调整频率，不包含扫频、调相或幅值控制。工程根目录的
通用 `empty.c` 保持不变。

## 1. 先确认模块引脚

常见 AD9850 成品模块一般能找到：

```text
VCC / 5V
GND
DATA（有些板标 D7 或 SERIAL DATA）
W_CLK
FQ_UD（有些板标 UPDATE）
RESET
SIN_OUT / ZOUT1 / ZOUT2
SQ_OUT（可选方波输出，本例不使用）
```

如果是裸芯片或把 D0~D7 全部引出的板，串行启动还要求：

```text
D2 = 0
D1 = 1
D0 = 1
串行 DATA 接 D7
```

多数常见 DDS 模块已经固定了 D2/D1/D0，但不要只凭板子颜色判断，最好看原理图或用
万用表确认。

## 2. 推荐控制线和 LaunchPad 接口

| MSPM0G3507 | LaunchPad BoosterPack pin | AD9850 | SysConfig 名称 |
| --- | ---: | --- | --- |
| PA25 | 2 | DATA / D7 | `DATA` |
| PA26 | 5 | W_CLK | `W_CLK` |
| PA27 | 8 | FQ_UD / UPDATE | `FQ_UD` |
| PA8 | 4 | RESET | `RESET` |
| GND | 20 或 22 | GND | — |

PA8 在板上也标为 UART_TX；当前工程没有启用 UART，可以作为 RESET GPIO。若以后恢复
Backchannel UART，应换一个空闲 GPIO 或处理对应跳线，不能让两个功能同时占用 PA8。

### 2.1 供电和逻辑电平

AD9850 芯片可在 3.3 V 或 5 V 工作，但两种接法不能混为一谈。

**方案 A：整块模块确认能在 3.3 V 工作**

```text
LaunchPad 3V3 -> 模块 VCC
四根 GPIO 直接连接
LaunchPad GND -> 模块 GND
```

这时 AD9850 的 3.3 V 逻辑高门限为 2.4 V，MSPM0 直接驱动合适。但很多廉价模块上的
125 MHz 有源晶振是 5 V 型，AD9850 芯片能跑 3.3 V 不代表整块模块能跑 3.3 V。

**方案 B：常见模块使用 5 V，推荐**

```text
LaunchPad 5V 或独立 5V -> 模块 VCC
LaunchPad GND            -> 模块 GND

PA25/26/27/8 -> 74AHCT125/74HCT125 输入
AHCT125 5V 供电，OE 拉低
AHCT125 四路输出 -> DATA/W_CLK/FQ_UD/RESET
```

AD9850 在 5 V 供电时，数据手册的逻辑高最低值为 3.5 V，所以 MSPM0 的 3.3 V 高电平
直连不属于保证范围。要选 `AHCT/HCT` 输入门限的缓冲器；普通 5 V `74HC125` 也可能
要求接近 3.5 V 的高电平，不能当作同一种器件。

所有情况下必须共地。5 V 绝不能回灌到 MSPM0 GPIO。

### 2.2 示波器

```text
示波器 CH1 探头尖端 -> 模块 SIN_OUT / ZOUT
示波器地夹          -> 模块 GND
```

首次使用 10× 探头、1 MΩ 输入。某些模块的正弦输出网络不是为示波器 50 Ω 端接设计的，
直接切到 50 Ω 会让幅度明显变化。方波脚不是本例要观察的正弦输出。

## 3. SysConfig 配置

不需要 SPI、Timer、PWM 或中断，只需要四个普通 GPIO 输出：

1. 打开 `empty.syscfg`；
2. 添加一个 **GPIO Pin Group**；
3. Group Name 填 `GPIO_AD9850`；
4. Port 选择 `PORTA`；
5. 创建四个 pin，全部设为 `Digital Output`、`Initial Output Low`：

| Pin Name | Assigned Pin | Direction | Initial |
| --- | --- | --- | --- |
| `DATA` | `PA25` | Output | Low |
| `W_CLK` | `PA26` | Output | Low |
| `FQ_UD` | `PA27` | Output | Low |
| `RESET` | `PA8` | Output | Low |

6. 保存 SysConfig 并重新 Build；
7. 在生成的 `Debug/ti_msp_dl_config.h` 中确认存在：

```c
#define GPIO_AD9850_PORT          GPIOA
#define GPIO_AD9850_DATA_PIN      DL_GPIO_PIN_25
#define GPIO_AD9850_W_CLK_PIN     DL_GPIO_PIN_26
#define GPIO_AD9850_FQ_UD_PIN     DL_GPIO_PIN_27
#define GPIO_AD9850_RESET_PIN     DL_GPIO_PIN_8
```

8. 将根目录 `empty.c` 设为 **Exclude from Build**，再把以下入口和两个驱动源文件
   加入 CCS 当前 Build：

```text
examples/ad9850_ui/main.c
optional/rabi_gpio_serial.c
optional/rabi_ad9850.c
```

如果漏掉 GPIO 配置，AD9850 入口会直接给出明确的编译错误；如果漏掉两个驱动 `.c`，
链接时会报告 `rabi_ad9850_*` 或 `rabi_gpio_serial_*` 未定义。测试结束后，重新包含
根目录 `empty.c` 并排除 AD9850 的 `main.c`，即可恢复通用模板。

## 4. UI 使用

上电成功时：

```text
Output:       ON
Freq:   1000.0kHz
State:        OK
```

`State: OK` 只表示 MCU 已完成 40-bit GPIO 发送；AD9850 这条接口没有读回/ACK，因此它
不能证明模块供电、接线或输出一定正确，最终仍要看示波器或逻辑分析仪。

键盘操作：

- `A/B`：移动条目；
- `C`：进入编辑，再按 C 切换数字位；
- 编辑时 `A/B`：增加/减小当前位，频率立即更新；
- `D`：退出编辑；
- Output 条目也为立即生效，可切换 DDS Power-Down。

频率显示单位为 kHz，最低步进 0.1 kHz，也就是 100 Hz；默认范围 0.1~20000.0 kHz。
要改默认值、上限或模块参考时钟，修改 `examples/ad9850_ui/main.c` 顶部的宏和 UI 配置。

## 5. 参考时钟和频率误差

代码默认：

```c
#define AD9850_REFERENCE_CLOCK_HZ 125000000U
```

只有模块确实使用 125 MHz 参考时钟时才正确。如果模块晶振是 100 MHz，必须改成
`100000000U`。输出有固定比例误差时，可以用频率计/示波器测量实际值，例如设定
10 MHz、实测 9.9992 MHz，再据此校准参考时钟宏；不要修改频率调谐字公式。

## 6. 没有波形时按此顺序查

1. 模块 VCC 和 GND 是否正确，125 MHz 晶振是否真的起振；
2. 5 V 模块是否加了 AHCT/HCT 电平转换；
3. DATA 是否接到 D7，而不是 D0；
4. 裸板的 D2/D1/D0 是否为 0/1/1；
5. RESET、W_CLK、FQ_UD 上电是否默认 Low；
6. 逻辑分析仪能否看到初始化后的 40 个 W_CLK 和最后的 FQ_UD 脉冲；
7. 即使 OLED 显示 `OK`，也要确认 DATA/W_CLK/FQ_UD 的实际波形，因为接口没有 ACK；
8. 示波器是否接在正弦输出而不是方波输出，并使用 1 MΩ 输入；
9. 频率调低到 100 kHz 或 1 MHz 再试，排除高频布线和输出滤波问题；
10. 若 40-bit 串行口被毛刺打乱，重新复位/断电，不要继续发送不完整帧。

AD9850 的串行格式是 32-bit 频率字加 8-bit 控制/相位字，最低位先发，40 bit 完成后
由 FQ_UD 上升沿更新输出。官方依据见
[AD9850 Rev. H 数据手册](https://www.analog.com/media/en/technical-documentation/data-sheets/ad9850.pdf)。
