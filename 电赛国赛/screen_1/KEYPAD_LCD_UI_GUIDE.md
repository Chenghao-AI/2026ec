# MSPM0G3507 矩阵键盘与 ST7796 UI 接口说明

## 1. 文档目的

本文档说明 `Electronic Competition` 工程中已有的：

- 4×4 矩阵键盘按键事件接口；
- ST7796 480×320 横屏坐标系；
- 填充、直线、矩形和 RGB565 像素图像绘制接口；
- 当前 UI 背景、数据卡片、频谱图和波形图的精确布局；
- 文字坐标、字号和实际占用尺寸的计算方法。
- 可直接传入 ADC 采样数组和 FFT 幅值数组的通用图表接口；
- 大型采样数组的格式转换、波形包络/频谱最大值压缩与实时刷新方法。

屏幕驱动与 UI 分为两层：

```text
main.c / 比赛业务逻辑
        ↓
ui.c       页面框架、卡片和 Demo 页面
signal_display.c ADC/算法数据转换、大数组压缩和一键绘图
plot.c     坐标网格、采样波形、FFT 频谱和自动缩放
graphics.c 任意直线、折线、圆、文字和数值
        ↓
st7796.c   矩形、横线、竖线、像素数据和 SPI 通信
```

当采样点或 FFT bin 明显多于屏幕宽度时，应优先使用
`Hardware/signal_display.h` 中的 `SignalDisplay_*()` 接口，详见
`SIGNAL_DISPLAY_PIPELINE.md`。它会在调用 `plot.c` 前执行波形包络或频谱最大值压缩，避免
简单抽点漏掉窄脉冲或载波峰。

---

## 2. 键盘按键事件

头文件：`Hardware/keypad.h`

```c
#define KEYPAD_NONE (0U)

void Keypad_Init(void);
uint8_t Keypad_GetPress(void);
```

### 2.1 `Keypad_Init()`

在 `SYSCFG_DL_init()` 之后调用一次，用于清空键盘扫描和消抖状态。

```c
SYSCFG_DL_init();
Keypad_Init();
```

### 2.2 `Keypad_GetPress()`

获取一次“新按下”事件：

| 返回值 | 含义 |
|---:|---|
| `0` | 没有新按键，即 `KEYPAD_NONE` |
| `1` | 实体 S1 按下 |
| `2` | 实体 S2 按下 |
| `...` | `...` |
| `16` | 实体 S16 按下 |

函数内部已包含约 20 ms 软件消抖，并且只在按键从“未按下”转为“按下”时返回一次键值。长按不会每个循环都触发。

推荐用 `switch` 组织比赛功能：

```c
uint8_t key = Keypad_GetPress();

switch (key) {
    case 1U:
        /* S1 事件 */
        break;

    case 2U:
        /* S2 事件 */
        break;

    case 3U:
        /* S3 事件 */
        break;

    case KEYPAD_NONE:
    default:
        break;
}
```

---

## 3. 屏幕坐标系

屏幕在驱动初始化后为 480×320 横屏。

```text
(0, 0)  ┌──────────────────────────────┐  (479, 0)
        │                              │
        │        480 像素宽             │
        │                              │
        │        320 像素高             │
        │                              │
(0,319) └──────────────────────────────┘  (479,319)
```

- X 轴从左往右增大，有效范围 `0～479`。
- Y 轴从上往下增大，有效范围 `0～319`。
- 位置参数 `(x, y)` 通常表示图形左上角。
- 尺寸参数 `width` 和 `height` 表示像素数，而不是右下角坐标。

例如：

```c
ST7796_FillRect(20U, 60U, 100U, 40U, color);
```

表示从 `(20,60)` 开始绘制宽 100、高 40 的实心矩形，最后一个像素坐标为 `(119,99)`。

---

## 4. RGB565 颜色

头文件 `Hardware/st7796.h` 提供：

```c
RGB565(red, green, blue)
```

RGB 参数均使用 `0～255` 的常用颜色范围：

```c
uint16_t black = RGB565(0U, 0U, 0U);
uint16_t white = RGB565(255U, 255U, 255U);
uint16_t red   = RGB565(255U, 0U, 0U);
uint16_t cyan  = RGB565(34U, 211U, 238U);
```

当前 UI 主要颜色位于 `Hardware/ui.c` 顶部：

| 名称 | 用途 |
|---|---|
| `COLOR_BG` | 全局深色背景 |
| `COLOR_HEADER` | 顶部和底部状态栏 |
| `COLOR_PANEL` | 图表背景 |
| `COLOR_PANEL_2` | 数据卡片背景 |
| `COLOR_GRID` | 坐标网格 |
| `COLOR_CYAN` | 主曲线和强调色 |
| `COLOR_GOLD` | 重点数据和标线 |
| `COLOR_WHITE` | 主文字 |
| `COLOR_MUTED` | 次要文字 |

---

## 5. ST7796 基本绘图函数

公开接口位于 `Hardware/st7796.h`。

### 5.1 初始化屏幕

```c
void ST7796_Init(void);
```

完成复位、ST7796 寄存器初始化、RGB565 颜色格式和 480×320 横屏方向设置。只需在开机时调用一次。

### 5.2 填充整屏

```c
void ST7796_FillScreen(uint16_t color);
```

示例：

```c
ST7796_FillScreen(RGB565(5U, 12U, 22U));
```

典型用途：进入新页面前清屏并设置背景。

### 5.3 填充实心矩形

```c
void ST7796_FillRect(
    uint16_t x,
    uint16_t y,
    uint16_t width,
    uint16_t height,
    uint16_t color);
```

示例：

```c
/* 在 (16,58) 绘制一个 216×54 的数据卡片背景 */
ST7796_FillRect(16U, 58U, 216U, 54U, COLOR_PANEL_2);
```

函数会裁剪超出屏幕右边和下边的部分。如果 `x >= 480`、`y >= 320`、`width == 0` 或 `height == 0`，则不绘制。

### 5.4 水平直线

```c
void ST7796_DrawHLine(
    uint16_t x,
    uint16_t y,
    uint16_t width,
    uint16_t color);
```

示例：

```c
/* 从 (20,150) 开始画一条长 300 像素的水平线 */
ST7796_DrawHLine(20U, 150U, 300U, COLOR_CYAN);
```

### 5.5 垂直直线

```c
void ST7796_DrawVLine(
    uint16_t x,
    uint16_t y,
    uint16_t height,
    uint16_t color);
```

示例：

```c
/* 从 (100,80) 开始画一条高 180 像素的垂直线 */
ST7796_DrawVLine(100U, 80U, 180U, COLOR_CYAN);
```

### 5.6 矩形边框

```c
void ST7796_DrawRect(
    uint16_t x,
    uint16_t y,
    uint16_t width,
    uint16_t height,
    uint16_t color);
```

示例：

```c
/* 绘制左上角 (16,122)、大小 448×158 的图表边框 */
ST7796_DrawRect(16U, 122U, 448U, 158U, COLOR_CYAN);
```

该函数只画四条边，不会修改矩形内部。

### 5.7 绘制 RGB565 像素数组

```c
void ST7796_DrawRGB565(
    uint16_t x,
    uint16_t y,
    uint16_t width,
    uint16_t height,
    const uint16_t *pixels);
```

`pixels` 按从左到右、从上到下的顺序存放，像素总数必须至少为：

```text
width × height
```

一维数组中 `(x,y)` 对应的索引计算方式为：

```c
index = local_y * width + local_x;
```

这是当前文字、频谱和波形最终写入屏幕时使用的底层接口。

---

## 6. 当前 UI 的精确布局

当前页面使用以下坐标：

```text
y=0    ┌────────────────────────────────────────┐
       │ 标题栏：x=0, y=0, w=480, h=46        │
y=46   ├────────────────────────────────────────┤
       │ 卡片1：(16,58), 216×54                │
       │ 卡片2：(248,58), 216×54               │
y=112  │                                        │
       │ 图表：(16,122), 448×158                │
y=280  │                                        │
y=292  ├────────────────────────────────────────┤
       │ 底部栏：x=0, y=292, w=480, h=28       │
y=319  └────────────────────────────────────────┘
```

### 6.1 顶部标题栏

```c
ST7796_FillRect(0U, 0U, 480U, 46U, COLOR_HEADER);
```

- 页面标题起点：`(16,14)`，字号 `2`。
- 右侧状态起点：`(378,18)`，字号 `1`。
- 底部有一条 `y=44`、高度 2 像素的青色分隔线。

### 6.2 数据卡片

```text
左卡片：x=16,  y=58, width=216, height=54
右卡片：x=248, y=58, width=216, height=54
```

卡片内部：

- 左边 4 像素宽的强调色条；
- 标签文字起点：`(x+14,66)`，字号 `1`；
- 数值文字起点：`(x+14,85)`，字号 `2`。

### 6.3 图表区域

`Hardware/ui.c` 中定义：

```c
#define PLOT_X (16U)
#define PLOT_Y (122U)
#define PLOT_W (448U)
#define PLOT_H (158U)
```

因此图表范围为：

```text
左上角：(16,122)
右下角：(463,279)
宽度：448 像素
高度：158 像素
```

### 6.4 底部状态栏

```c
ST7796_FillRect(0U, 292U, 480U, 28U, COLOR_HEADER);
```

当前显示 S1/S2 功能提示和 `MSPM0` 标识。

---

## 7. 公开文字与数值绘制

通用文字实现已从 Demo `ui.c` 拆分到 `Hardware/graphics.c` 中，所有公开声明位于 `Hardware/graphics.h`，可以在 `main.c` 或任意业务模块中调用。

### 7.1 单字符函数

```c
void Graphics_DrawChar(
    uint16_t x,
    uint16_t y,
    char character,
    uint8_t scale,
    uint16_t foreground,
    uint16_t background);
```

### 7.2 字符串函数

```c
void Graphics_DrawText(
    uint16_t x,
    uint16_t y,
    const char *text,
    uint8_t scale,
    uint16_t foreground,
    uint16_t background);
```

参数含义：

| 参数 | 含义 |
|---|---|
| `x` | 整段文字左上角 X 坐标 |
| `y` | 整段文字左上角 Y 坐标 |
| `text` | 以 `\0` 结尾的 C 字符串 |
| `scale` | 放大倍数，当前支持 `1～4` |
| `foreground` | 文字颜色 |
| `background` | 字符背景颜色 |

当前字模是 5×7 像素，每个字符右侧附带 1 列间距。实际占用尺寸为：

```text
单字符宽度 = 6 × scale
单字符高度 = 7 × scale
字符串宽度 = 字符数 × 6 × scale
字符串高度 = 7 × scale
```

字号对应尺寸：

| `scale` | 单字符占用宽度 | 高度 |
|---:|---:|---:|
| 1 | 6 px | 7 px |
| 2 | 12 px | 14 px |
| 3 | 18 px | 21 px |
| 4 | 24 px | 28 px |

例如：

```c
Graphics_DrawText(20U, 40U, "FREQ 100 KHZ", 2U,
                  RGB565(255U, 255U, 255U),
                  RGB565(5U, 12U, 22U));
```

`"FREQ 100 KHZ"` 共 12 个字符，字号 2 时占用：

```text
宽度 = 12 × 6 × 2 = 144 px
高度 = 7 × 2 = 14 px
```

即从 `(20,40)` 开始，预留至少 144×14 的区域。

当前字符集支持：

- `A～Z`；
- `a～z`，显示时转换为大写；
- `0～9`；
- 空格、`.`、`,`、`:`、`-`、`/`、`+`、`%`、`=`、`(`、`)`。

当前不支持汉字和完整 ASCII 字符集。

### 7.3 文字尺寸计算

```c
uint16_t Graphics_TextWidth(const char *text, uint8_t scale);
uint16_t Graphics_TextHeight(uint8_t scale);
```

可用于居中文字或在绘制前检查是否越界：

```c
uint16_t width = Graphics_TextWidth("READY", 2U);
uint16_t x = (uint16_t)((ST7796_WIDTH - width) / 2U);
Graphics_DrawText(x, 40U, "READY", 2U, white, background);
```

### 7.4 整数、浮点数和单位

```c
void Graphics_DrawInt(..., int32_t value, ...);
void Graphics_DrawUInt(..., uint32_t value, ...);
void Graphics_DrawFloat(..., float value, uint8_t decimals, ...);
void Graphics_DrawIntWithUnit(..., int32_t value, const char *unit, ...);
void Graphics_DrawFloatWithUnit(..., float value, uint8_t decimals,
                                const char *unit, ...);
```

示例：

```c
Graphics_DrawIntWithUnit(20U, 80U, 100, "KHZ", 2U, white, background);
Graphics_DrawFloatWithUnit(20U, 110U, 200.25F, 2U, "MV", 2U,
                           white, background);
```

`Graphics_DrawFloat()` 当前最多保留 4 位小数。在 Cortex-M0+ 上浮点运算使用软件实现，如果只显示定点采样数据，优先使用整数或自己缩放后显示，可减少运算开销。

---

## 8. 频谱图函数

公开接口位于 `Hardware/plot.h`：

```c
bool Plot_DrawSpectrum(
    uint16_t x, uint16_t y,
    uint16_t width, uint16_t height,
    const uint16_t *magnitudes,
    uint16_t binCount,
    uint16_t maximum,
    const PlotStyle *style);

bool Plot_DrawSpectrumAuto(
    uint16_t x, uint16_t y,
    uint16_t width, uint16_t height,
    const uint16_t *magnitudes,
    uint16_t binCount,
    const PlotStyle *style);
```

参数含义：

| 参数 | 含义 |
|---|---|
| `x, y` | 频谱图左上角坐标 |
| `width, height` | 频谱绘图区大小 |
| `magnitudes` | FFT 幅值或其他非负频谱数组 |
| `binCount` | 数组中的有效 bin 数 |
| `maximum` | Y 轴顶部对应的幅值 |
| `style` | 颜色、网格划分、轴线和线宽配置 |

`Plot_DrawSpectrumAuto()` 会自动搜索数组最大值，并增加约 10% 顶部余量。

示例：

```c
uint16_t fftMagnitude[128];
PlotStyle style = PLOT_STYLE_DARK;

style.traceColor = RGB565(34U, 211U, 238U);
style.xDivisions = 8U;
style.yDivisions = 5U;

Plot_DrawSpectrumAuto(16U, 122U, 448U, 158U,
                      fftMagnitude, 128U, &style);
```

该函数只负责把 bin 索引和幅值映射成图形。如果需要标注 Hz/kHz、dB 或峰值频率，应用 `Graphics_DrawText()` 和数值函数在图表上叠加。现有 `UI_ShowSpectrum()` 已经是该通用函数的完整调用示例。

---

## 9. 波形图函数

公开接口位于 `Hardware/plot.h`：

```c
bool Plot_DrawWaveform(
    uint16_t x, uint16_t y,
    uint16_t width, uint16_t height,
    const int16_t *samples,
    uint16_t sampleCount,
    int16_t minimum,
    int16_t maximum,
    const PlotStyle *style);

bool Plot_DrawWaveformAuto(
    uint16_t x, uint16_t y,
    uint16_t width, uint16_t height,
    const int16_t *samples,
    uint16_t sampleCount,
    bool symmetric,
    const PlotStyle *style);
```

参数含义：

| 参数 | 含义 |
|---|---|
| `x, y` | 波形图左上角坐标 |
| `width, height` | 波形图尺寸 |
| `samples` | ADC 或算法生成的 `int16_t` 采样数组 |
| `sampleCount` | 采样点数，至少为 2 |
| `minimum, maximum` | Y 轴显示范围 |
| `style` | 图表样式 |

X 轴会自动将所有采样点线性映射到指定宽度，采样数量无需等于图表宽度。

`Plot_DrawWaveformAuto()` 会自动计算 Y 轴范围：

- `symmetric=false`：使用最小值到最大值，增加约 5% 余量；
- `symmetric=true`：以0为中心使用对称量程，适合交流波形。

示例：

```c
int16_t adcSamples[256];
PlotStyle style = PLOT_STYLE_DARK;

style.traceColor = RGB565(255U, 190U, 74U);
style.traceThickness = 2U;

Plot_DrawWaveformAuto(20U, 80U, 440U, 200U,
                      adcSamples, 256U, true, &style);
```

如果已知道 ADC 量程或希望不同刷新帧使用相同 Y 轴，应使用 `Plot_DrawWaveform()` 并手动传入固定 `minimum/maximum`，避免画面比例来回跳动。

---

## 10. 页面背景和数据卡片

以下两个函数已经通过 `Hardware/ui.h` 公开。`ui.c` 现在同时保留“通用页面控件”和“现有 Demo 页面”。

页面框架：

```c
void UI_DrawPageFrame(const char *title, const char *status,
                      const UITheme *theme);
```

它负责：

1. 用 `COLOR_BG` 清空整屏；
2. 绘制顶部标题栏；
3. 绘制标题和右侧状态文字；
4. 绘制底部功能提示栏。

数据卡片：

```c
void UI_DrawCard(uint16_t x, uint16_t y,
                 uint16_t width, uint16_t height,
                 const char *label, const char *value,
                 uint16_t accent, const UITheme *theme);
```

卡片的位置和尺寸已经完全由参数指定。当 `theme == NULL` 时，两个函数使用工程默认的 `UI_THEME_DARK`。

---

## 11. 当前公开程度总结

### 已经成熟且可直接复用

```c
Keypad_Init();
Keypad_GetPress();

ST7796_Init();
ST7796_FillScreen();
ST7796_FillRect();
ST7796_DrawHLine();
ST7796_DrawVLine();
ST7796_DrawRect();
ST7796_DrawRGB565();

Graphics_DrawPixel();
Graphics_DrawLine();
Graphics_DrawPolyline();
Graphics_DrawCircle();
Graphics_FillCircle();
Graphics_DrawChar();
Graphics_DrawText();
Graphics_DrawInt();
Graphics_DrawUInt();
Graphics_DrawFloat();
Graphics_DrawIntWithUnit();
Graphics_DrawFloatWithUnit();

Plot_DrawGrid();
Plot_DrawWaveform();
Plot_DrawWaveformAuto();
Plot_GetWaveformRange();
Plot_DrawSpectrum();
Plot_DrawSpectrumAuto();

UI_DrawPageFrame();
UI_DrawCard();
```

这些函数已经通过实际屏幕和键盘验证。

### Demo 页面兼容接口

```c
UI_ShowSpectrum();
UI_ShowPeriodicSignal();
UI_HandleKey();
```

`UI_ShowSpectrum()` 和 `UI_ShowPeriodicSignal()` 仍保留本次 Demo 的固定标题和数值，但内部已经改为调用 `Plot_*` 通用数组绘图接口。可以把它们当作示例，不必在新题目中继续使用。

---

## 12. 通用图形与图表接口

以下接口已经在当前工程中实现：

```c
Graphics_DrawLine();       /* 任意斜率，含边界裁剪 */
Graphics_DrawPolyline();   /* 折线 */
Graphics_DrawCircle();     /* 圆 */
Graphics_FillCircle();     /* 实心圆 */
Graphics_DrawText();       /* 文字 */
Graphics_DrawInt();        /* 有符号整数 */
Graphics_DrawFloat();      /* 可选小数位 */

Plot_DrawGrid();           /* 空坐标网格 */
Plot_DrawWaveform();       /* 固定 Y 量程波形 */
Plot_DrawWaveformAuto();   /* 自动 Y 量程波形 */
Plot_DrawSpectrum();       /* 固定 Y 量程频谱 */
Plot_DrawSpectrumAuto();   /* 自动 Y 量程频谱 */
```

这种分层能够保证：

- `st7796.c` 只负责屏幕硬件和基本像素操作；
- `graphics.c` 负责通用图元、文字和数值；
- `plot.c` 负责数组到波形/频谱的映射、网格和缩放；
- `ui.c` 负责页面框架、卡片和现有 Demo；
- `main.c` 和各比赛算法只需提供按键事件、采样数组和要显示的数值。

### 12.1 任意直线、折线和圆

```c
void Graphics_DrawPixel(int16_t x, int16_t y, uint16_t color);
void Graphics_DrawLine(int16_t x0, int16_t y0,
                       int16_t x1, int16_t y1, uint16_t color);
void Graphics_DrawPolyline(const GraphicsPoint *points,
                           uint16_t count, uint16_t color);
void Graphics_DrawCircle(int16_t centerX, int16_t centerY,
                         int16_t radius, uint16_t color);
void Graphics_FillCircle(int16_t centerX, int16_t centerY,
                         int16_t radius, uint16_t color);
```

`Graphics_DrawLine()` 允许传入超出屏幕的有符号坐标，会先将线段裁剪到 480×320 屏幕内，然后使用 Bresenham 算法绘制。水平和垂直线会自动调用更快的 ST7796 底层函数。

```c
GraphicsPoint points[] = {
    {20, 200}, {80, 120}, {150, 180}, {240, 90}
};

Graphics_DrawLine(10, 10, 300, 200, cyan);
Graphics_DrawPolyline(points, 4U, gold);
Graphics_DrawCircle(350, 100, 40, white);
Graphics_FillCircle(420, 100, 15, green);
```

### 12.2 `PlotStyle` 图表样式

```c
typedef struct {
    uint16_t backgroundColor;
    uint16_t gridColor;
    uint16_t axisColor;
    uint16_t traceColor;
    uint16_t borderColor;
    uint8_t xDivisions;
    uint8_t yDivisions;
    uint8_t traceThickness;
    bool drawBorder;
    bool drawZeroAxis;
} PlotStyle;
```

工程提供默认深色样式：

```c
PlotStyle style = PLOT_STYLE_DARK;
```

复制后可以只修改需要的字段：

```c
style.traceColor = RGB565(255U, 190U, 74U);
style.xDivisions = 10U;
style.yDivisions = 8U;
style.traceThickness = 2U;
style.drawZeroAxis = true;
```

- `xDivisions/yDivisions == 0`：不画对应方向的内部网格。
- `traceThickness == 0`：按1像素处理。
- `drawZeroAxis == true`：只有在 Y 轴范围包含0时才会画零轴。

### 12.3 单独绘制网格和零轴

```c
void Plot_DrawGrid(uint16_t x, uint16_t y,
                   uint16_t width, uint16_t height,
                   int16_t minimum, int16_t maximum,
                   const PlotStyle *style);
```

该函数不绘制数据，只绘制图表背景、网格、边框和零轴，可以用于自己绘制特殊图形。

### 12.4 图表绘制限制和性能

- 图表区域必须完整位于屏幕内，宽高至少为3像素。
- 无效参数时 `Plot_DrawWaveform*()` 和 `Plot_DrawSpectrum*()` 返回 `false`。
- 图表驱动内部使用两个 480 点静态行缓冲区，不需要 480×320 全屏帧缓冲。
- 图表函数不可重入，不要在主循环绘图未结束时又从中断中调用。
- 当前 SPI 为约 4 MHz，大面积图表刷新需要一定时间；不建议在每个 5 ms 主循环都刷新整个图表。

---

## 13. 当前工程的最简使用模板

```c
#include "ti_msp_dl_config.h"
#include "keypad.h"
#include "ui.h"

int main(void)
{
    uint8_t key;

    SYSCFG_DL_init();
    Keypad_Init();
    UI_Init();

    while (1) {
        key = Keypad_GetPress();

        switch (key) {
            case 1U:
                UI_ShowSpectrum();
                break;

            case 2U:
                UI_ShowPeriodicSignal();
                break;

            case KEYPAD_NONE:
            default:
                break;
        }

        /* 32 MHz 时约 5 ms */
        delay_cycles(160000U);
    }
}
```

该模板体现了当前的标准使用流程：键盘只产生事件，UI 函数负责绘制页面，两者之间不直接依赖。
