# C 标准库 `math.h` 竞赛速查与信号处理用法

本文面向本工程使用的 MSPM0G3507，目标是在比赛现场快速回答四个问题：

1. 某个数学功能应该调用哪个函数；
2. 参数和返回值分别表示什么；
3. 在信号采集、FFT、波形与频谱显示中怎样使用；
4. 在没有硬件浮点单元的单片机上怎样避免不必要的运算开销。

> 本文讲的是 C 标准库数学接口。`math.h` 负责“把数据算出来”，屏幕绘图仍调用本工程的 `graphics.h`、`plot.h` 和 `signal_display.h`。

---

## 1. 最基本的调用方式

```c
#include <math.h>
```

大多数数学函数有三种浮点版本：

| 数据类型 | 函数命名 | 示例 |
| --- | --- | --- |
| `float` | 函数名以 `f` 结尾 | `sinf(x)`、`sqrtf(x)`、`log10f(x)` |
| `double` | 无后缀 | `sin(x)`、`sqrt(x)`、`log10(x)` |
| `long double` | 函数名以 `l` 结尾 | `sinl(x)`、`sqrtl(x)`、`log10l(x)` |

本工程优先使用 `float` 和 `...f()` 版本：

```c
float angleRad = 0.5f;
float value = sinf(angleRad);
```

不要把 `float` 变量无意中送进 `double` 版本：

```c
/* 不推荐：sin() 和 0.5 都按 double 运算。 */
float y1 = (float)(sin(angleRad) * 0.5);

/* 推荐：整个表达式按 float 运算。 */
float y2 = sinf(angleRad) * 0.5f;
```

### 1.1 本工程为什么优先使用 `float`

MSPM0G3507 的 Cortex-M0+ 内核没有硬件 FPU，本工程当前也采用软浮点 ABI。`float`、`double` 以及三角函数、对数函数等都主要由软件运行库计算，因此应把浮点运算放在主循环或低速任务中，避免放进高频中断。

使用 `float` 的主要好处是数据占 4 字节，数组更省 RAM，也能避免无意中引入更重的双精度运算。它不代表每一种表达式都一定比 `double` 快，但更适合作为本项目的默认浮点类型。

### 1.2 π 和角度单位

C 标准并不保证提供 `M_PI`。虽然部分工具链会在特定特性宏下提供它，比赛代码不要依赖这一点。建议在自己的公共头文件中定义：

```c
#define MATH_PI_F          (3.14159265358979323846f)
#define MATH_TWO_PI_F      (2.0f * MATH_PI_F)
#define MATH_DEG_TO_RAD_F  (MATH_PI_F / 180.0f)
#define MATH_RAD_TO_DEG_F  (180.0f / MATH_PI_F)
```

`sinf()`、`cosf()`、`tanf()`、`asinf()`、`acosf()`、`atanf()` 和 `atan2f()` 都使用弧度，不使用角度。

```c
float angleDeg = 30.0f;
float y = sinf(angleDeg * MATH_DEG_TO_RAD_F);  /* 约为 0.5 */
```

### 1.3 整数绝对值不在 `math.h` 中

```c
#include <stdlib.h>

int       abs(int value);
long      labs(long value);
long long llabs(long long value);
```

浮点绝对值才使用 `math.h` 中的 `fabsf()`、`fabs()` 和 `fabsl()`。

---

## 2. 一页函数速查表

下面优先列出适合本工程的 `float` 版本。把末尾的 `f` 去掉就是 `double` 版本。

### 2.1 绝对值、上下限和符号

| 函数 | 作用与返回值 | 典型场景 |
| --- | --- | --- |
| `fabsf(x)` | 返回 `x` 的绝对值 | 误差、幅值、浮点近似比较 |
| `fminf(a, b)` | 返回两者中较小值 | 限幅、坐标边界 |
| `fmaxf(a, b)` | 返回两者中较大值 | 限幅、对数输入下限 |
| `fdimf(a, b)` | 返回 `max(a - b, 0)` | 只保留正差值 |
| `copysignf(mag, sign)` | 返回绝对值等于 `mag`、符号取自 `sign` 的数 | 保留方向或重建带符号幅值 |
| `fmaf(a, b, c)` | 计算 `a * b + c`，按融合乘加语义只做一次最终舍入 | 累加、线性变换；本芯片仍可能由软件实现 |

常用限幅写法：

```c
float limited = fminf(fmaxf(value, minValue), maxValue);
```

使用前应保证 `minValue <= maxValue`。另外，`fminf()`/`fmaxf()` 在只有一个参数为 NaN 时通常返回另一个数，因此它们不能代替 `isfinite()` 输入检查，否则可能把异常数据悄悄变成看似正常的限幅结果。

### 2.2 平方根、幂和距离

| 函数 | 作用与返回值 | 定义域/注意事项 | 典型场景 |
| --- | --- | --- | --- |
| `sqrtf(x)` | 返回平方根 | 实数范围要求 `x >= 0` | RMS、模长、标准差 |
| `cbrtf(x)` | 返回立方根 | 负数也有效 | 三次关系反解 |
| `powf(base, exponent)` | 返回 `base` 的 `exponent` 次幂 | 负底数配非整数指数通常产生 NaN | 任意实数幂 |
| `hypotf(x, y)` | 返回 `sqrt(x*x + y*y)` | 比直接表达式更能避免中间溢出/下溢 | 复数模长、二维距离 |

平方和小整数次幂不要调用 `powf()`：

```c
float square = x * x;          /* 比 powf(x, 2.0f) 更直接。 */
float cube   = x * x * x;
```

### 2.3 指数和对数

| 函数 | 作用与返回值 | 定义域/注意事项 | 典型场景 |
| --- | --- | --- | --- |
| `expf(x)` | 返回 `e^x` | `x` 很大时溢出为无穷大 | 指数衰减、滤波系数 |
| `exp2f(x)` | 返回 `2^x` | 同样可能溢出 | 以 2 为底的标度 |
| `expm1f(x)` | 返回 `e^x - 1` | `x` 很小时比 `expf(x)-1` 更准确 | 小时间常数、小增量 |
| `logf(x)` | 返回自然对数 `ln(x)` | `x > 0` | 指数模型反解 |
| `log10f(x)` | 返回常用对数 `log10(x)` | `x > 0` | dB 换算 |
| `log2f(x)` | 返回 `log2(x)` | `x > 0` | 位数、二进制尺度 |
| `log1pf(x)` | 返回 `ln(1+x)` | `x > -1`；`x` 很小时更准确 | 小相对变化 |

幅度与功率的 dB 公式不同：

```c
amplitudeDb = 20.0f * log10f(amplitude / referenceAmplitude);
powerDb     = 10.0f * log10f(power / referencePower);
```

### 2.4 三角函数和反三角函数

| 函数 | 参数与返回值 | 典型场景 |
| --- | --- | --- |
| `sinf(angleRad)` | 输入弧度，返回正弦值 `[-1, 1]` | 正弦波、坐标变换、窗函数 |
| `cosf(angleRad)` | 输入弧度，返回余弦值 `[-1, 1]` | 余弦波、IQ 解调、窗函数 |
| `tanf(angleRad)` | 输入弧度，返回正切值 | 斜率；接近 `π/2 + kπ` 时数值会很大 |
| `asinf(x)` | `x` 应在 `[-1, 1]`，返回 `[-π/2, π/2]` | 由正弦值反求角度 |
| `acosf(x)` | `x` 应在 `[-1, 1]`，返回 `[0, π]` | 由余弦值反求角度 |
| `atanf(x)` | 返回 `[-π/2, π/2]` | 已知单个比值求角度 |
| `atan2f(y, x)` | 根据点 `(x, y)` 返回带象限角度，通常在 `[-π, π]` | FFT 相位、矢量方向；参数顺序是先 `y` 后 `x` |

求相位应优先使用 `atan2f(imag, real)`，不要使用 `atanf(imag / real)`。前者能区分四个象限，也不会先执行一次可能除零的除法。

### 2.5 双曲函数（较少使用）

| 函数 | 作用 | 注意事项 |
| --- | --- | --- |
| `sinhf(x)`、`coshf(x)`、`tanhf(x)` | 双曲正弦、余弦、正切 | `tanhf()` 可用于软限幅；整体开销较高 |
| `asinhf(x)` | 反双曲正弦 | 任意有限实数可用 |
| `acoshf(x)` | 反双曲余弦 | 要求 `x >= 1` |
| `atanhf(x)` | 反双曲正切 | 要求 `-1 < x < 1` |

### 2.6 取整和浮点转整数

| 函数 | 返回类型 | 舍入规则 | 典型场景 |
| --- | --- | --- | --- |
| `floorf(x)` | `float` | 向负无穷取整 | 区间下标、左边界 |
| `ceilf(x)` | `float` | 向正无穷取整 | 向上估算所需格数 |
| `truncf(x)` | `float` | 直接丢弃小数，向 0 取整 | 截断小数部分 |
| `roundf(x)` | `float` | 最近整数，正好一半时远离 0 | 一般四舍五入 |
| `lroundf(x)` | `long` | 与 `roundf` 同规则，并返回整数 | 显示数值、像素坐标 |
| `llroundf(x)` | `long long` | 与 `roundf` 同规则，并返回整数 | 更大整数结果 |
| `rintf(x)` | `float` | 依当前浮点舍入模式，可能报告浮点异常 | 特殊数值算法 |
| `nearbyintf(x)` | `float` | 依当前浮点舍入模式，不报告不精确异常 | 特殊数值算法 |

注意负数的差别：

```text
x = -2.7
floorf(x) = -3
ceilf(x)  = -2
truncf(x) = -2
roundf(x) = -3
```

### 2.7 余数、拆分和二进制缩放

| 函数 | 作用与返回值 | 典型场景 |
| --- | --- | --- |
| `fmodf(x, y)` | 返回 `x - trunc(x/y) * y`，结果符号通常跟随 `x` | 相位/角度周期回绕 |
| `remainderf(x, y)` | 使用最接近整数的商求 IEEE 余数，结果可正可负 | 对称余差；不要与 `fmodf` 混用 |
| `remquof(x, y, &quo)` | 返回 IEEE 余数，并给出商的部分低位 | 特殊周期算法 |
| `modff(x, &integerPart)` | 返回带符号小数部分，同时写出整数部分 | 拆分显示或协议字段 |
| `frexpf(x, &exponent)` | 把 `x` 拆成尾数和 2 的指数 | 浮点格式分析、归一化 |
| `ldexpf(x, exponent)` | 返回 `x * 2^exponent` | 二进制快速缩放 |
| `scalbnf(x, exponent)` | 返回 `x * FLT_RADIX^exponent` | 按浮点基数缩放；常见平台基数为 2 |

`fmodf(x, y)`、`remainderf(x, y)` 和 `remquof(x, y, ...)` 都要求 `y != 0`；第二参数为 0 属于定义域错误，通常产生 NaN。

负角度使用 `fmodf()` 后可能仍为负，需要再加一个周期：

```c
float wrapped = fmodf(angleRad, MATH_TWO_PI_F);
if (wrapped < 0.0f) {
    wrapped += MATH_TWO_PI_F;
}
```

### 2.8 数值分类和异常检查

以下通常是宏，结果可直接用于 `if`：

| 接口 | 为真时表示 |
| --- | --- |
| `isfinite(x)` | `x` 是正常有限值、次正规值或 0，不是 NaN/无穷大 |
| `isnan(x)` | `x` 是 NaN（非数） |
| `isinf(x)` | `x` 是正无穷或负无穷 |
| `isnormal(x)` | `x` 是规格化的非零有限值 |
| `signbit(x)` | `x` 的符号位为负，包括 `-0.0f` |
| `fpclassify(x)` | 返回 `FP_NAN`、`FP_INFINITE`、`FP_ZERO`、`FP_SUBNORMAL` 或 `FP_NORMAL` |

比较宏还有 `isgreater(a,b)`、`isgreaterequal(a,b)`、`isless(a,b)`、`islessequal(a,b)`、`islessgreater(a,b)` 和 `isunordered(a,b)`，它们能显式处理 NaN，但普通业务判断通常先用 `isfinite()` 就够了。

```c
float result = log10f(input);
if (!isfinite(result)) {
    /* 不把 NaN/Inf 继续送入绘图坐标计算。 */
    result = 0.0f;
}
```

### 2.9 其他标准数学函数

| 函数 | 作用 | 适用场景 |
| --- | --- | --- |
| `erff(x)`、`erfcf(x)` | 误差函数和互补误差函数 | 高斯概率、通信误码率估算 |
| `tgammaf(x)`、`lgammaf(x)` | Gamma 函数及其绝对值自然对数 | 概率分布、特殊数学模型 |
| `nextafterf(x, y)` | 返回从 `x` 朝 `y` 方向相邻的可表示浮点数 | 浮点边界测试 |
| `nanf(tag)` | 生成 NaN | 特殊错误标记；嵌入式业务通常更推荐状态返回值 |

这些函数并不属于高频竞赛常用项，而且软件计算开销较高，需要时再使用。

---

## 3. 信号处理中的直接调用模板

### 3.1 计算复数或 FFT 频点的幅值

```c
float Signal_ComplexMagnitude(float realPart, float imagPart)
{
    return hypotf(realPart, imagPart);
}
```

若输入已知有界、平方不会溢出，并且只为比较哪个 FFT 频点最大，不必对每个频点求平方根：

```c
float magnitudeSquared = realPart * realPart + imagPart * imagPart;
```

先比较 `magnitudeSquared`，只对最终需要显示的频点调用一次 `sqrtf()` 或 `hypotf()`，可以显著减少运算量。如果 `realPart`/`imagPart` 可能接近浮点上限，应先缩放或直接使用 `hypotf()`，避免中间平方溢出。

这里得到的是 FFT 系数的原始模长。若要显示真实电压、幅度谱或 dB，还必须结合 ADC 标定、前端增益、FFT 长度、单边/双边频谱约定以及窗函数的相干增益进行归一化。

### 3.2 计算相位

```c
float Signal_PhaseDegrees(float realPart, float imagPart)
{
    float phaseRad = atan2f(imagPart, realPart);
    return phaseRad * MATH_RAD_TO_DEG_F;
}
```

参数顺序一定是 `atan2f(y, x)`，对应这里的 `atan2f(imagPart, realPart)`。

### 3.3 幅度和功率换算为 dB

```c
float Signal_AmplitudeToDb(float amplitude, float referenceAmplitude)
{
    const float ratioFloor = 1.0e-12f;

    if (!isfinite(amplitude) || !isfinite(referenceAmplitude) ||
        (amplitude < 0.0f) || (referenceAmplitude <= 0.0f)) {
        return NAN;
    }

    return 20.0f * log10f(
        fmaxf(amplitude / referenceAmplitude, ratioFloor));
}

float Signal_PowerToDb(float power, float referencePower)
{
    const float ratioFloor = 1.0e-12f;

    if (!isfinite(power) || !isfinite(referencePower) ||
        (power < 0.0f) || (referencePower <= 0.0f)) {
        return NAN;
    }

    return 10.0f * log10f(
        fmaxf(power / referencePower, ratioFloor));
}
```

注意：

- 幅度比使用 `20 * log10(...)`；
- 功率比使用 `10 * log10(...)`；
- `referenceAmplitude` 或 `referencePower` 必须大于 0；
- `fmaxf()` 给对数输入设置下限，防止输入 0 后得到负无穷；
- 若系统需要显示真实噪声底，应根据 ADC 位数、前端增益和标定结果设置下限，而不是机械照抄 `1.0e-12f`。

### 3.4 计算 `int16_t` 采样数组的 RMS

下面先用 64 位整数累加平方，只在最后求一次浮点平方根，适合 MSPM0：

```c
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <math.h>

bool Signal_CalculateRmsI16(const int16_t *samples,
                            uint32_t sampleCount,
                            float *rmsOut)
{
    uint64_t sumSquares = 0U;
    uint32_t index;

    if ((samples == NULL) || (sampleCount == 0U) || (rmsOut == NULL)) {
        return false;
    }

    for (index = 0U; index < sampleCount; index++) {
        int32_t sample = samples[index];
        uint32_t square = (uint32_t)(sample * sample);
        sumSquares += (uint64_t)square;
    }

    *rmsOut = sqrtf((float)sumSquares / (float)sampleCount);
    return true;
}
```

如果采样值包含较大的直流偏置，而目标是交流有效值，应先减去平均值，再计算平方平均。

### 3.5 计算峰峰值

峰峰值只需要整数比较，不需要 `math.h`：

```c
bool Signal_CalculatePeakToPeakI16(const int16_t *samples,
                                   uint32_t sampleCount,
                                   int32_t *peakToPeakOut)
{
    int16_t minimum;
    int16_t maximum;
    uint32_t index;

    if ((samples == NULL) || (sampleCount == 0U) ||
        (peakToPeakOut == NULL)) {
        return false;
    }

    minimum = samples[0];
    maximum = samples[0];

    for (index = 1U; index < sampleCount; index++) {
        if (samples[index] < minimum) {
            minimum = samples[index];
        }
        if (samples[index] > maximum) {
            maximum = samples[index];
        }
    }

    *peakToPeakOut = (int32_t)maximum - (int32_t)minimum;
    return true;
}
```

### 3.6 生成低速测试正弦波

```c
float phaseRad = 0.0f;
float phaseStep = MATH_TWO_PI_F * signalFrequencyHz / sampleRateHz;

for (uint32_t index = 0U; index < sampleCount; index++) {
    output[index] = amplitude * sinf(phaseRad) + dcOffset;

    phaseRad += phaseStep;
    if (phaseRad >= MATH_TWO_PI_F) {
        phaseRad -= MATH_TWO_PI_F;
    }
}
```

这个简化写法要求 `sampleRateHz > 0`，并假设 `0 <= phaseStep < 2π`，所以每次最多只需减去一个周期。正常的数字信号生成还应满足奈奎斯特条件，即目标频率低于采样率的一半。若接口允许任意正负频率或一次跨越多个周期，应使用 `fmodf()` 加负值修正，或用循环完成回绕。

这适合初始化测试数据或低速演示。高采样率下不要在每个采样中实时调用 `sinf()`，应考虑：

- 预先生成查找表；
- DDS 相位累加器；
- DMA 搬运预生成波形；
- 使用已验证的 DSP 库。

### 3.7 Hann 窗系数

```c
float Window_Hann(uint32_t index, uint32_t length)
{
    if (length <= 1U) {
        return 1.0f;
    }

    return 0.5f - 0.5f * cosf(
        MATH_TWO_PI_F * (float)index / (float)(length - 1U));
}
```

FFT 长度固定时，应在初始化阶段把所有窗系数算进数组，采样处理阶段只做乘法，不要每一帧重新调用大量 `cosf()`。

### 3.8 一阶低通滤波系数

一种常见离散一阶低通写法为：

```c
float alpha = 1.0f - expf(
    -MATH_TWO_PI_F * cutoffFrequencyHz / sampleRateHz);

filtered += alpha * (input - filtered);
```

要求 `sampleRateHz > 0`、`cutoffFrequencyHz >= 0`。系数只在参数变化时重新计算，不要在每个样本中重复调用 `expf()`。

该系数由模拟 RC 极点/时间常数映射得到；只有当截止频率明显低于采样率时，数字滤波器的实际 `-3 dB` 频率才近似等于这里填写的 `cutoffFrequencyHz`。需要精确频响时应按目标离散滤波器重新设计系数。

### 3.9 浮点近似比较

不要直接用 `a == b` 判断计算得到的两个浮点数是否相等：

```c
#include <stdbool.h>

bool Math_NearlyEqualF(float a,
                       float b,
                       float relativeTolerance,
                       float absoluteTolerance)
{
    float difference;
    float scale;

    if (!isfinite(a) || !isfinite(b) ||
        (relativeTolerance < 0.0f) || (absoluteTolerance < 0.0f)) {
        return false;
    }

    difference = fabsf(a - b);
    scale = fmaxf(fabsf(a), fabsf(b));

    return difference <= fmaxf(absoluteTolerance,
                               relativeTolerance * scale);
}
```

容差必须结合量纲选择。例如电压数据可以按 ADC 分辨率设置绝对容差，而不能给所有量都固定一个神秘的 `0.00001f`。

### 3.10 频率与 FFT bin 的换算

如果采样率和 FFT 长度都是整数，优先使用 64 位整数避免没有必要的浮点运算：

```c
uint32_t FrequencyFromBin(uint32_t binIndex,
                          uint32_t sampleRateHz,
                          uint32_t fftLength)
{
    if ((fftLength == 0U) || (binIndex >= fftLength)) {
        return 0U;
    }

    return (uint32_t)(((uint64_t)binIndex * sampleRateHz) / fftLength);
}
```

示例把 `binIndex >= fftLength` 视为无效输入并返回 0；正式算法也可以改为 `bool + 输出指针`，从而区分“无效输入”和真正的直流 0 Hz。

需要小数频率时再使用：

```c
float frequencyHz = (float)binIndex * (float)sampleRateHz /
                    (float)fftLength;
```

---

## 4. 常见错误、定义域和保护方法

| 表达式 | 风险 | 建议保护 |
| --- | --- | --- |
| `sqrtf(x)` 且 `x < 0` | 产生 NaN/定义域错误 | 先验证输入；只对理论上的微小负舍入误差使用 `fmaxf(x, 0.0f)` |
| `logf(x)`、`log10f(x)` 且 `x == 0` | 产生负无穷 | 设置物理上合理的正下限 |
| `logf(x)`、`log10f(x)` 且 `x < 0` | 产生 NaN | 先检查数据意义和符号 |
| `asinf(x)`、`acosf(x)` 且 `x` 超出 `[-1,1]` | 产生 NaN | 对舍入误差可限幅到 `[-1,1]`；真实越界应报错 |
| `powf(负数, 非整数)` | 通常产生 NaN | 明确底数和指数的物理范围 |
| `atan2f(0, 0)` | 方向没有物理意义 | 幅值为 0 时单独处理相位 |
| `expf(x)` 且 `x` 很大 | 上溢为无穷大 | 在调用前限制模型输入范围 |
| `tanf(x)` 接近 `π/2 + kπ` | 结果非常大或溢出 | 避免在奇点附近使用 |
| 浮点结果直接转整数 | 超出整数范围时结果不可靠 | 先限幅，再用 `lroundf()` 或明确取整规则 |
| NaN/Inf 进入屏幕坐标计算 | 可能产生异常坐标或数组越界 | 在转换为像素前调用 `isfinite()` |

在资源有限的嵌入式程序中，优先在调用前验证输入并返回明确状态。不要把主要错误处理建立在 `errno` 或浮点异常环境上；它们会增加依赖，也不如显式参数检查直观。

`math.h` 还提供常量或宏，例如：

| 名称 | 含义 |
| --- | --- |
| `NAN` | NaN，表示没有有效实数结果 |
| `INFINITY` | 正无穷 |
| `HUGE_VALF` | `float` 版本的巨大值/溢出指示 |

需要检查浮点范围时再包含：

```c
#include <float.h>
```

常见宏包括 `FLT_MAX`、`FLT_MIN` 和 `FLT_EPSILON`。注意 `FLT_MIN` 是最小正规格化值，不是最负的 `float`；负方向边界是 `-FLT_MAX`。

---

## 5. MSPM0G3507 上的性能原则

### 5.1 哪些函数通常较重

在没有硬件 FPU 的本芯片上，下列函数通常都需要软件运行库参与：

- `sinf()`、`cosf()`、`tanf()` 和反三角函数；
- `logf()`、`log10f()`、`expf()`；
- `powf()`；
- `sqrtf()`、`hypotf()`；
- 双曲函数和 Gamma/误差函数。

具体周期数取决于编译器版本、优化选项、输入范围及链接到的运行库实现。不要凭感觉估算，在最终采样率下用定时器或 GPIO 翻转实测。

### 5.2 比赛代码的实用优化顺序

1. 先保证公式正确和输入范围正确；
2. 不在 ADC/DMA 高频中断里做屏幕刷新、FFT、三角函数或对数运算；
3. 常量和滤波系数只在初始化或参数改变时计算；
4. 比较 FFT 峰值时比较模平方，最后才开平方；
5. 高频正弦生成使用查找表或 DDS；
6. 固定窗函数预计算成表；
7. 批量 FFT、向量运算优先使用经过验证且适配 Cortex-M0+ 的 DSP 实现；
8. UI 只按人眼需要的帧率刷新，不必跟 ADC 采样率同步；
9. 确认性能仍不足后，再考虑定点/Q 格式和查找表近似。

### 5.3 把快任务和慢任务分开

推荐的数据流：

```text
ADC/DMA 完成中断
    -> 只记录“新数据块已就绪”标志

主循环
    -> 读取已完成的数据块
    -> 去直流/加窗/FFT/参数计算
    -> 把结果转换为绘图数组
    -> 按较低帧率刷新 LCD
```

这样即使 `log10f()` 或 SPI 刷屏耗时，也不容易破坏采样时序。

### 5.4 不要随意开启激进浮点优化

类似 fast-math 的选项可能允许编译器假设不会出现 NaN/Inf、改变运算重排和舍入行为。它可能提高速度，也可能让 `isfinite()`、边界条件或数值一致性不再符合原先预期。比赛前没有完整回归测试时不要临时开启。

### 5.5 栈和数组

大批量采样数组、FFT 工作区、窗函数表不要定义成大型局部变量。优先使用文件作用域 `static` 数组，明确 RAM 占用；本工程虽已提高链接栈空间，也不能把栈当作大数据缓冲区。

---

## 6. 如何接入本工程的屏幕显示链路

`math.h` 结果进入屏幕通常经过三步：

```text
原始 ADC/DMA 数据
    -> 数学或 DSP 运算（RMS、FFT、幅值、相位、dB）
    -> 整数/浮点结果数组与统计值
    -> signal_display / plot / graphics 绘制
```

建议职责划分如下：

| 层次 | 负责内容 | 不应负责内容 |
| --- | --- | --- |
| 采集层 | ADC、DMA、缓冲区切换、时间戳 | LCD 绘制、复杂对数运算 |
| 算法层 | 滤波、FFT、RMS、峰峰值、dB、标定 | SPI 像素发送 |
| 转换层 | 把算法结果缩放/限幅为绘图所需数组 | 重新采样硬件 |
| 绘图层 | 坐标轴、文字、曲线、频谱柱或包络 | 修改原始采样数据 |

已有接口的具体数据适配方法见 `SIGNAL_DISPLAY_PIPELINE.md`；通用绘图和 UI 布局见 `MAIN_GRAPHICS_UI_TUTORIAL.md`。

一个典型主循环伪代码如下：

```c
if (adcBlockReady) {
    adcBlockReady = false;

    /* 1. 算法层：处理采样数据。 */
    RemoveDcOffset(adcSamples, SAMPLE_COUNT);
    ApplyPrecomputedWindow(adcSamples, hannWindow, SAMPLE_COUNT);
    RunFft(adcSamples, fftReal, fftImag, FFT_LENGTH);

    /* 2. 数学层：只为实际需要的频点计算显示量。 */
    for (uint32_t bin = 0U; bin < DISPLAY_BIN_COUNT; bin++) {
        float magnitude = hypotf(fftReal[bin], fftImag[bin]);
        displaySpectrum[bin] = Signal_AmplitudeToDb(magnitude,
                                                    referenceMagnitude);
    }

    /* 3. 绘图层：按 UI 帧率刷新，不放在采样中断中。 */
    if (displayRefreshDue) {
        DrawSpectrumPage(displaySpectrum, DISPLAY_BIN_COUNT);
    }
}
```

这里的 `RemoveDcOffset()`、`ApplyPrecomputedWindow()`、`RunFft()` 和 `DrawSpectrumPage()` 是职责示意名，并不是 C 标准库函数；应替换为比赛工程中实际采用的算法与绘图接口。

---

## 7. 现场选函数决策表

| 需求 | 首选接口/做法 |
| --- | --- |
| 浮点绝对值 | `fabsf(x)` |
| 两值限幅 | `fminf()` + `fmaxf()` |
| 平方 | `x * x` |
| 平方根 | `sqrtf(x)` |
| 复数模长 | `hypotf(real, imag)` |
| 只比较 FFT 幅值大小 | 比较 `real*real + imag*imag`，不要逐点开方 |
| 任意次幂 | `powf(base, exponent)` |
| 正弦/余弦波 | `sinf()` / `cosf()`；高频生成改用表或 DDS |
| 四象限相位 | `atan2f(imag, real)` |
| 幅度转 dB | `20.0f * log10f(amplitude/reference)` |
| 功率转 dB | `10.0f * log10f(power/reference)` |
| 向下/向上取整 | `floorf()` / `ceilf()` |
| 四舍五入到整数 | `lroundf()` |
| 周期回绕 | `fmodf()`，负结果再加周期 |
| 检查结果能否用于绘图 | `isfinite(x)` |
| 判断两个浮点值近似相等 | 绝对容差 + 相对容差，不直接 `==` |
| FFT bin 转整数 Hz | 优先 64 位整数乘法再除法 |
| 高频批量计算 | 定点、查找表或已验证 DSP 库 |

---

## 8. CCS 编译与链接提示

本工程的 CCS/TI Arm Clang 编译器驱动通常会自动选择并链接标准 C 运行库中的数学实现，正常情况下只需：

```c
#include <math.h>
```

不需要照搬桌面 GCC 教程随意添加 `-lm`。本工程的 `device.cmd.genlibs` 主要声明 DriverLib 依赖，并不是数学库本身。如果出现 `undefined symbol: sinf`、`sqrtf` 等链接错误，应依次检查：

1. 文件是否真正加入当前 Debug/Release 构建；
2. 函数名与精度后缀是否正确；
3. 最终链接是否仍由 `tiarmclang` 编译器驱动执行，而不是绕过驱动直接调用底层链接器；
4. TI Arm Clang 运行库的搜索路径和自动运行库选择是否被破坏；
5. 若工程同时出现 DriverLib/SysConfig 符号错误，再检查 `device.cmd.genlibs` 和 SysConfig 生成文件；
6. Clean Project 后重新 Build Project。

若 CCS 正开着某个刚被外部更新的工程文件，出现保存提示时选择“从磁盘重新加载”，不要用编辑器里的旧版本覆盖磁盘文件。

---

## 9. 赛前建议保留的最小公共工具

比赛模板中可以自行整理一个小型 `math_utils.h/.c`，只封装真正反复使用的项目约定，例如：

- `Math_ClampF()`：统一限幅；
- `Math_NearlyEqualF()`：统一浮点容差比较；
- `Math_WrapRadiansF()`：角度回绕到 `[0, 2π)`；
- `Signal_ComplexMagnitude()`：复数模长；
- `Signal_PhaseDegrees()`：相位角；
- `Signal_AmplitudeToDb()`、`Signal_PowerToDb()`：统一 dB 基准与噪声底；
- `Signal_CalculateRmsI16()`：统一采样格式和失败返回方式。

不要为了“封装”再给每个标准函数套一层同名壳。公共工具的价值应当是固定项目约定、补上边界检查、减少公式抄错，而不是隐藏标准库。

---

## 10. 最后检查清单

在把数学代码接入采样和 UI 前，逐项确认：

- [ ] 使用了正确的 `float` 版本和 `f` 字面量后缀；
- [ ] 三角函数的角度已转换为弧度；
- [ ] `atan2f()` 参数顺序是 `(y, x)`；
- [ ] `sqrtf()`、对数和反三角函数的输入满足定义域；
- [ ] dB 公式区分幅度比的 20 和功率比的 10；
- [ ] 除数、参考值、FFT 长度和采样率都不为 0；
- [ ] NaN/Inf 不会进入数组下标或屏幕坐标；
- [ ] 高频中断只做必要的数据搬运与标志更新；
- [ ] 窗系数、滤波系数和查找表只在必要时计算；
- [ ] 大数组没有放在栈上；
- [ ] 已在目标采样率和编译优化等级下测过运行时间；
- [ ] 已用已知输入（直流、单音、零输入、满量程）验证数值与单位。

这份清单比死记函数更重要：比赛现场最常见的问题往往不是“不知道 `sqrtf()`”，而是弧度/角度混淆、dB 系数用错、零输入取对数、NaN 进入绘图坐标，或把重计算塞进了高频中断。
