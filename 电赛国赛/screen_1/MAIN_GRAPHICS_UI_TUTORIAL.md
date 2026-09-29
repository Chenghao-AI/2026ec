# 使用 Graphics 通用绘图函数构建赛场 UI

## 1. 文档目标

本文档以工程根目录中的 `main.c` 频谱仪页面为蓝本，详细说明：

- 如何把 480×320 屏幕划分为标题、数据卡片、图表和状态栏；
- 如何给每个 UI 元素确定坐标和尺寸；
- 如何使用 `Graphics_*` 绘制文字、直线、折线、圆形和数值；
- 如何使用 ST7796 底层函数完成清屏和实心区域；
- 如何将演示频谱替换为真实 ADC/FFT 数据；
- 如何在比赛现场快速搭建一套新 UI。

当前 `main.c` 故意不使用 `ui.h` 和 `plot.h`，目的是展示“从空白屏幕开始手工组织页面”的完整过程。

---

## 2. 当前代码分层

```text
main.c
├── 决定页面布局、坐标、颜色和显示内容
├── 组织标题栏、卡片、图表、频谱轨迹和底栏
│
├── graphics.c / graphics.h
│   ├── 文字、整数、浮点数和单位
│   ├── 任意斜率直线、折线
│   └── 圆、实心圆
│
└── st7796.c / st7796.h
    ├── 屏幕硬件初始化
    ├── 全屏填充、矩形填充
    └── SPI 命令与 RGB565 像素传输
```

一个完整页面并不是由某个“神奇 UI 函数”一次生成的，而是由多个基本图元按顺序叠加得到的。

---

## 3. 程序启动流程

`main()` 只需要三个主要步骤：

```c
int main(void)
{
    SYSCFG_DL_init();
    ST7796_Init();
    draw_spectrum_page();

    while (1) {
        __WFI();
    }
}
```

### 3.1 `SYSCFG_DL_init()`

根据 `Electronic Competition.syscfg` 生成的配置初始化：

- MCU 默认 32 MHz 时钟；
- SPI1；
- LCD `CS/DC/RESET` GPIO；
- 键盘 GPIO。

即使该页面没有使用键盘，也可以保留现有 SysConfig。

### 3.2 `ST7796_Init()`

完成：

- LCD 硬件复位；
- ST7796S 寄存器配置；
- RGB565 颜色模式；
- 480×320 横屏方向；
- 初始背景填充。

未调用屏幕初始化前，不能调用任何 `Graphics_*` 或 `ST7796_*` 绘图函数。

### 3.3 `draw_spectrum_page()`

完整绘制页面一次。由于 ST7796S 内部自带显存，MCU 停止发送数据后，屏幕仍然保留最后画面。

### 3.4 `__WFI()`

CPU 进入等待中断状态，避免在空循环中持续运行。如果后续需要扫描键盘或更新数据，应将该结构替换为主循环任务。

---

## 4. 480×320 坐标系

```text
(0,0)     X 增大 →                         (479,0)
  ┌────────────────────────────────────┐
  │                                    │
  │                                    │
Y │                                    │
增 │                                    │
大 │                                    │
↓ │                                    │
  └────────────────────────────────────┘
(0,319)                              (479,319)
```

- X 坐标有效范围：`0...479`；
- Y 坐标有效范围：`0...319`；
- `(x,y)` 通常表示元素左上角；
- `width/height` 表示像素数，不是右下角坐标。

例如：

```c
ST7796_FillRect(16U, 58U, 140U, 48U, color);
```

实际覆盖：

```text
X = 16...155
Y = 58...105
```

计算公式：

```text
右边界 = x + width  - 1
下边界 = y + height - 1
```

---

## 5. 当前频谱仪页面布局

| 区域 | X | Y | 宽 | 高 | 作用 |
|---|---:|---:|---:|---:|---|
| 顶部标题栏 | 0 | 0 | 480 | 48 | 标题、子标题和运行状态 |
| CENTER 卡片 | 16 | 58 | 140 | 48 | 中心频率 |
| SPAN 卡片 | 170 | 58 | 140 | 48 | 扫频宽度 |
| PEAK 卡片 | 324 | 58 | 140 | 48 | 峰值幅度 |
| 频谱图 | 16 | 118 | 448 | 160 | 网格、频谱和刻度 |
| 底部参数栏 | 0 | 289 | 480 | 31 | RBW、ATT、REF 和 HOLD |

区域之间保留适当空白：

```text
0...47    标题栏
48...57   10 px 间隔
58...105  数据卡片
106...117 12 px 间隔
118...277 频谱图
278...288 11 px 间隔
289...319 底部栏
```

这种布局方法比在代码中随意试坐标更稳定。比赛现场建议先在纸上或表格中列出所有区域，再编写代码。

---

## 6. 颜色规划

颜色通过 `RGB565(r,g,b)` 宏生成，`r/g/b` 都使用 `0...255`。

```c
#define COLOR_BACKGROUND RGB565(4U, 11U, 20U)
#define COLOR_HEADER     RGB565(7U, 31U, 49U)
#define COLOR_PANEL      RGB565(10U, 28U, 44U)
#define COLOR_CYAN       RGB565(31U, 211U, 238U)
#define COLOR_GOLD       RGB565(255U, 188U, 69U)
#define COLOR_WHITE      RGB565(239U, 247U, 251U)
```

推荐维持以下层次：

- 全局背景：最深；
- 标题和底栏：比背景略亮；
- 卡片和图表：另一层深色；
- 次要文字：灰蓝色；
- 主文字：接近白色；
- 主轨迹：青色；
- 峰值/警告/重点：金色；
- 正常状态：绿色。

一个页面中强调色不宜太多，否则重点会消失。

---

## 7. `draw_data_card()` 数据卡片

```c
static void draw_data_card(uint16_t x,
                           const char *label,
                           const char *value,
                           uint16_t accent);
```

### 参数

| 参数 | 含义 |
|---|---|
| `x` | 卡片左上角 X 坐标 |
| `label` | 小号标签，例如 `"CENTER"` |
| `value` | 大号数值，例如 `"50.000 KHZ"` |
| `accent` | RGB565 强调颜色 |

函数内部顺序：

1. 填充 140×48 卡片背景；
2. 在左侧填充 4×48 强调色条；
3. 在 `(x+12,65)` 绘制标签；
4. 在 `(x+12,83)` 绘制主数值。

要改成可自由放置的卡片，可增加 `y/width/height` 参数，或直接使用已经实现的 `UI_DrawCard()`。

---

## 8. `draw_header()` 标题栏

标题栏演示了四种常用操作：

```c
ST7796_FillRect(...);       /* 大面积背景 */
Graphics_DrawText(...);     /* 标题与子标题 */
Graphics_FillCircle(...);   /* 状态点 */
Graphics_DrawText(...);     /* RUN 状态 */
```

状态点：

```c
Graphics_FillCircle(431, 17, 4, COLOR_GREEN);
```

参数依次为：

```text
圆心 X = 431
圆心 Y = 17
半径   = 4
颜色   = COLOR_GREEN
```

---

## 9. `draw_graph_grid()` 坐标网格

频谱区使用宏统一管理：

```c
#define GRAPH_X      16U
#define GRAPH_Y      118U
#define GRAPH_WIDTH  448U
#define GRAPH_HEIGHT 160U
```

第 `division` 条垂直线的 X 坐标：

```c
x = GRAPH_X + division * (GRAPH_WIDTH - 1) / 10;
```

使用 `GRAPH_WIDTH - 1` 是为了使最后一条线正好落在右边界，而不是越出1像素。

水平线使用同样的方式：

```c
y = GRAPH_Y + division * (GRAPH_HEIGHT - 1) / 5;
```

修改网格数量时，同时修改循环上限和除数即可。

---

## 10. `draw_spectrum_trace()` 频谱轨迹

### 10.1 底噪

底噪使用确定性公式，每次启动都相同：

```c
noise = 4U + ((index * 11U + 5U) % 8U);
```

它不是测量数据，只是用于 UI 演示。

### 10.2 频率映射

当频率范围为0...100 kHz时：

```text
0 kHz   → X = GRAPH_X
50 kHz  → X = GRAPH_X + GRAPH_WIDTH / 2
100 kHz → X = GRAPH_X + GRAPH_WIDTH - 1
```

通用频率到 X 坐标公式：

```c
x = GRAPH_X +
    (frequency - startFrequency) * (GRAPH_WIDTH - 1) /
    (stopFrequency - startFrequency);
```

要避免 `stopFrequency == startFrequency`。数值较大时建议使用 `uint32_t` 或 `int32_t` 中间变量。

### 10.3 幅值映射

当幅值0对应基线、`magnitudeMaximum` 对应图表顶部时：

```c
height = magnitude * usableHeight / magnitudeMaximum;
yTop = GRAPH_BOTTOM - height;
```

绘制：

```c
Graphics_DrawLine(x, GRAPH_BOTTOM, x, yTop, color);
```

由于这是垂直线，`Graphics_DrawLine()` 会自动调用更快的 ST7796 垂线实现。

---

## 11. `Graphics_*` 常用函数速查

### 11.1 文字

```c
Graphics_DrawText(x, y, text, scale, foreground, background);
```

| 参数 | 含义 |
|---|---|
| `x,y` | 文字左上角 |
| `text` | C 字符串 |
| `scale` | 字号，1...4 |
| `foreground` | 文字颜色 |
| `background` | 字符矩形背景色 |

字符尺寸：

```text
单字符宽 = 6 × scale
单字符高 = 7 × scale
```

在图表上覆盖文字时，`background` 应与文字所在区域的背景一致，否则字符周围会出现明显色块。

### 11.2 整数与单位

```c
Graphics_DrawIntWithUnit(x, y, value, unit,
                         scale, foreground, background);
```

示例：

```c
Graphics_DrawIntWithUnit(20U, 80U, 200, "MV", 2U,
                         COLOR_WHITE, COLOR_PANEL);
```

### 11.3 浮点数与单位

```c
Graphics_DrawFloatWithUnit(x, y, value, decimals, unit,
                           scale, foreground, background);
```

示例：

```c
Graphics_DrawFloatWithUnit(20U, 80U, 50.000F, 3U, "KHZ", 2U,
                           COLOR_WHITE, COLOR_PANEL);
```

MSPM0G3507 没有浮点单元，浮点格式化通过软件完成。高频刷新时优先使用定点整数。

### 11.4 任意直线

```c
Graphics_DrawLine(x0, y0, x1, y1, color);
```

- `(x0,y0)`：线段起点；
- `(x1,y1)`：线段终点；
- 坐标为 `int16_t`，允许线段起点或终点在屏幕外；
- 函数会自动裁剪到有效屏幕范围。

### 11.5 折线

```c
GraphicsPoint points[] = {
    {20, 180},
    {80, 120},
    {160, 170},
    {260, 90}
};

Graphics_DrawPolyline(points, 4U, COLOR_CYAN);
```

第二个参数是点数，不是线段数。4个点形成3条线段。

### 11.6 圆形

```c
Graphics_DrawCircle(centerX, centerY, radius, color);
Graphics_FillCircle(centerX, centerY, radius, color);
```

适合绘制：

- 状态指示灯；
- 数据点标记；
- 旋钮/仪表框；
- 警告符号。

---

## 12. 绘制顺序与覆盖关系

LCD 上没有 HTML/CSS 层级，后写入的像素会直接覆盖旧像素。

推荐顺序：

```text
1. 全屏背景
2. 大块容器（标题栏、卡片、图表背景）
3. 网格和边框
4. 数据曲线/频谱柱
5. 刻度、数值和标签
6. 峰值指示、光标和弹窗
```

常见错误：

```c
Graphics_DrawText(...);    /* 先画文字 */
ST7796_FillRect(...);       /* 后画背景，文字被覆盖 */
```

正确方式：

```c
ST7796_FillRect(...);       /* 先画背景 */
Graphics_DrawText(...);    /* 再画文字 */
```

---

## 13. 比赛现场创建新 UI 的标准流程

### 第一步：明确页面目的

先写出本页需要回答的问题，例如：

- 当前测量量是什么？
- 哪个数值最重要？
- 需要波形、频谱还是纯数值？
- 需要哪些运行状态？

### 第二步：划分区域

建议使用表格：

| 元素 | x | y | width | height |
|---|---:|---:|---:|---:|
| 标题栏 | 0 | 0 | 480 | 48 |
| 数值区 | 16 | 60 | 448 | 50 |
| 波形区 | 16 | 120 | 448 | 160 |
| 状态栏 | 0 | 292 | 480 | 28 |

检查每个区域的：

```text
x + width  <= 480
y + height <= 320
```

### 第三步：定义颜色

在 `main.c` 顶部定义颜色宏，避免在每个函数内重复写 RGB 数值。

### 第四步：先画静态框架

先完成：

- 背景；
- 标题栏；
- 卡片；
- 图表背景；
- 网格；
- 不变的文字。

暂时不接 ADC，先确认页面布局正确。

### 第五步：用模拟数据验证图表

像当前 `draw_spectrum_trace()` 一样，先用可重复的整数公式生成波形或频谱。这样可以将 UI 问题与采样/算法问题分开。

### 第六步：接入真实数据

将模拟数据生成替换为：

- ADC DMA 数组；
- 滤波后的采样数组；
- FFT 幅值数组；
- 频率、幅值、相位等计算结果。

### 第七步：加入键盘事件

将不同页面分成函数：

```c
static void draw_spectrum_page(void);
static void draw_waveform_page(void);
static void draw_settings_page(void);
```

再通过 `Keypad_GetPress()` 切换。

---

## 14. 接入键盘的主循环模板

```c
#include "keypad.h"

int main(void)
{
    uint8_t key;

    SYSCFG_DL_init();
    ST7796_Init();
    Keypad_Init();
    draw_spectrum_page();

    while (1) {
        key = Keypad_GetPress();

        switch (key) {
            case 1U:
                draw_spectrum_page();
                break;

            case 2U:
                draw_waveform_page();
                break;

            case 3U:
                draw_settings_page();
                break;

            case KEYPAD_NONE:
            default:
                break;
        }

        delay_cycles(160000U); /* 32 MHz 时约5 ms */
    }
}
```

只在页面需要切换或数据需要更新时重绘，不要在每个循环无条件清屏。

---

## 15. 将演示频谱替换为 FFT 数组

假设 FFT 幅值数组为：

```c
uint16_t magnitude[128];
```

可以手工映射：

```c
static void draw_fft_bars(const uint16_t *magnitude,
                          uint16_t binCount,
                          uint16_t maximum)
{
    uint16_t bin;

    if ((magnitude == NULL) || (binCount == 0U) || (maximum == 0U)) {
        return;
    }

    for (bin = 0U; bin < binCount; bin++) {
        uint16_t x = (uint16_t)(GRAPH_X +
                     ((uint32_t)bin * (GRAPH_WIDTH - 1U)) / binCount);
        uint16_t value = magnitude[bin];
        uint16_t height;

        if (value > maximum) {
            value = maximum;
        }

        height = (uint16_t)(((uint32_t)value * 120U) / maximum);
        Graphics_DrawLine((int16_t)x, (int16_t)GRAPH_BOTTOM,
                          (int16_t)x,
                          (int16_t)(GRAPH_BOTTOM - height),
                          COLOR_CYAN);
    }
}
```

实际比赛中，如果已允许使用 `plot.h`，直接调用 `Plot_DrawSpectrum()` 或 `Plot_DrawSpectrumAuto()` 会更方便。本节手工实现的价值是理解坐标映射原理。

---

## 16. 局部刷新与性能

当前 SPI 时钟约为4 MHz，全屏480×320×2字节原始像素数据约300 KB。频繁全屏重绘会带来明显延迟。

推荐策略：

### 页面切换时

可以清屏并绘制完整页面：

```c
ST7796_FillScreen(COLOR_BACKGROUND);
draw_complete_page();
```

### 单个数值更新时

只清空数值所在矩形，再重画数值：

```c
ST7796_FillRect(valueX, valueY, valueWidth, valueHeight,
                 COLOR_PANEL_ALT);
Graphics_DrawIntWithUnit(valueX, valueY, newValue, "MV", 2U,
                         COLOR_WHITE, COLOR_PANEL_ALT);
```

### 波形/频谱更新时

1. 只重绘图表区；
2. 重画网格；
3. 重画数据曲线；
4. 重画图表内标注。

不必重画标题栏、卡片背景和底栏。

---

## 17. 常见问题

### 17.1 文字后面有色块

`Graphics_DrawText()` 的 `background` 与实际区域背景不一致。

### 17.2 图形超出屏幕

检查：

```text
x + width  <= 480
y + height <= 320
```

### 17.3 文字显示不完整

使用：

```c
Graphics_TextWidth(text, scale);
Graphics_TextHeight(scale);
```

在绘制前计算实际占用尺寸。

### 17.4 数值变短后留有旧字符

例如 `100.00` 变为 `9.00`时，新文字比旧文字短。应在绘制新值前先清空整个数值区域。

### 17.5 刷新时画面闪烁

- 减少全屏清屏；
- 使用局部刷新；
- 不要在5 ms循环中重画整页；
- 将页面静态部分和动态部分拆开。

### 17.6 屏幕变白或开发板复位

首先检查屏幕供电、GND 共地和杜邦线接触，不要首先怀疑 UI 坐标代码。

---

## 18. CCS 编译与烧录

1. 在 CCS Explorer 中对工程执行 `Refresh`；
2. 确认 `Hardware/graphics.c` 位于工程中；
3. 执行 `Project -> Clean`；
4. 执行 `Build Project`；
5. 确认 Problems 中没有 Error；
6. 连接开发板和屏幕；
7. 点击 Debug/烧录。

默认输出文件：

```text
Debug/Electronic Competition.out
```

---

## 19. 赛场快速检查表

### 代码前

- [ ] 明确页面需显示的核心结果。
- [ ] 在纸上划分 480×320 区域。
- [ ] 为每个区域写出 x/y/width/height。
- [ ] 确定背景、主文字、次文字和强调色。

### 写代码时

- [ ] 先背景，再网格，再数据，最后文字。
- [ ] 用常量或宏统一管理坐标。
- [ ] 使用 `Graphics_TextWidth()` 检查文字宽度。
- [ ] 先用模拟数据验证 UI。
- [ ] 再替换为 ADC/FFT 数据。

### 运行时

- [ ] 页面切换时才全页重画。
- [ ] 实时数值只刷新对应矩形。
- [ ] 图表只刷新图表区域。
- [ ] 不在中断中执行大面积 SPI 绘图。

---

## 20. 相关文件

| 文件 | 作用 |
|---|---|
| `main.c` | 本文档对应的频谱仪页面完整示例 |
| `Hardware/graphics.h` | 通用图形、文字和数值公开接口 |
| `Hardware/graphics.c` | Graphics 具体实现 |
| `Hardware/st7796.h` | ST7796 屏幕底层公开接口 |
| `Hardware/st7796.c` | SPI 与 ST7796S 实现 |
| `Hardware/plot.h` | 可选的通用波形/频谱数组绘制接口 |
| `KEYPAD_LCD_UI_GUIDE.md` | 所有键盘和屏幕 API 参考 |
| `HARDWARE_WIRING_GUIDE.md` | 键盘和屏幕接线说明 |
