#ifndef SIGNAL_DISPLAY_H
#define SIGNAL_DISPLAY_H

#include <stdbool.h>
#include <stdint.h>

#include "plot.h"
#include "st7796.h"

/**
 * @file signal_display.h
 * @brief 大批量采样/变换结果到 ST7796 图表之间的数据适配层。
 *
 * 推荐数据流：
 * ADC/DMA 原始数组 -> 滤波/FFT 等算法 -> 本模块格式转换与保峰压缩
 * -> plot.c 像素映射 -> st7796.c 通过 SPI 发送到屏幕。
 *
 * 屏幕并不能直接理解 ADC 码或 FFT 数组；必须先把数据统一成：
 * - 时域波形：int16_t 有符号样本；
 * - 频域图：uint16_t 非负幅值。
 *
 * 本模块的高层 SignalDisplay_Draw*() 函数可直接接收远多于屏幕宽度的样本，
 * 内部使用固定静态缓冲区完成压缩，不使用 malloc，不会复制整个大数组。
 * 所有接口均为同步阻塞调用，且高层绘图接口共享静态缓冲区，因此不可重入，
 * 不要同时在中断与主循环中调用。
 */

/** @brief 高层适配层最多保留的显示点数，等于屏幕横向像素数。 */
#define SIGNAL_DISPLAY_MAX_POINTS ST7796_WIDTH

/**
 * @brief 把 uint16_t 原始量线性映射成 int16_t 工程量的标定参数。
 *
 * 映射关系为：inputMinimum -> outputMinimum，
 * inputMaximum -> outputMaximum；区间外输入会先钳位到端点。
 * outputMinimum 可以大于 outputMaximum，用于反相传感器。
 *
 * 12 位、3.3 V ADC 的交流耦合示例（输出表示相对 1.65 V 偏置的 mV）：
 * @code
 * const SignalLinearMap adcToMillivolts = {
 *     0U, 4095U, -1650, 1650
 * };
 * @endcode
 */
typedef struct {
    uint16_t inputMinimum; /**< 原始输入下端点，例如 ADC 最小码 0。 */
    uint16_t inputMaximum; /**< 原始输入上端点，必须大于 inputMinimum。 */
    int16_t outputMinimum; /**< 下端点对应的输出工程量。 */
    int16_t outputMaximum; /**< 上端点对应的输出工程量。 */
} SignalLinearMap;

/**
 * @brief 频谱峰值搜索结果。
 */
typedef struct {
    uint32_t binIndex;   /**< 峰值所在的原始频谱 bin 下标。 */
    uint16_t magnitude;  /**< 峰值幅度，单位与输入 magnitudes 一致。 */
    uint32_t frequencyHz;/**< 按 sampleRateHz/fftLength 换算出的频率，单位 Hz。 */
} SignalSpectrumPeak;

/**
 * @brief 批量把 uint16_t 原始数据线性转换为 int16_t 工程量。
 *
 * @param input 原始数组首地址，不可为 NULL。
 * @param inputCount 原始元素数，必须大于 0。
 * @param map 线性标定参数，不可为 NULL，且 inputMaximum>inputMinimum。
 * @param output 输出数组首地址，不可为 NULL。
 * @param outputCapacity output 可容纳的 int16_t 元素数，必须不少于 inputCount。
 * @return 成功转换全部元素返回 true；参数无效或容量不足返回 false。
 *
 * @note 输入与输出数组不得重叠。函数使用整数定点运算并四舍五入，不依赖浮点库。
 * @par 适用场景
 * 把 ADC 码转换成 mV、温度、位移等适合显示和后续计算的有符号工程量。
 */
bool Signal_ConvertU16ToI16(const uint16_t *input, uint32_t inputCount,
                            const SignalLinearMap *map, int16_t *output,
                            uint32_t outputCapacity);

/**
 * @brief 把 uint32_t 算法结果按满量程缩放成 uint16_t 非负幅值。
 *
 * @param input uint32_t 输入数组，例如 FFT 功率或累加能量，不可为 NULL。
 * @param inputCount 输入元素数，必须大于 0。
 * @param inputFullScale 输入满量程，必须大于 0；超过它的值会被钳位。
 * @param outputFullScale 输出满量程，必须大于 0，最大为 65535。
 * @param output uint16_t 输出数组首地址，不可为 NULL。
 * @param outputCapacity output 容量，必须不少于 inputCount。
 * @return 成功转换全部元素返回 true；参数无效或容量不足返回 false。
 *
 * @note 输入与输出不得重叠。换算使用四舍五入和 64 位中间量，避免乘法溢出。
 * @par 适用场景
 * 将 32 位 FFT 功率、平方和或累加结果压到 plot.h 接受的 uint16_t 幅值范围。
 */
bool Signal_ConvertU32ToU16(const uint32_t *input, uint32_t inputCount,
                            uint32_t inputFullScale,
                            uint16_t outputFullScale, uint16_t *output,
                            uint32_t outputCapacity);

/**
 * @brief 将大批 int16_t 波形压缩成逐显示列的最小值/最大值包络。
 *
 * @param input 原始有符号波形，不可为 NULL。
 * @param inputCount 原始样本数，至少为 1，可大于 65535。
 * @param minimumOutput 每个时间桶的数值最小值数组，不可为 NULL。
 * @param maximumOutput 每个时间桶的数值最大值数组，不可为 NULL。
 * @param outputCapacity 两个输出数组各自可容纳的元素数，至少为 1。
 * @return 返回实际写入两个数组的 uint16_t 列数；参数无效返回 0。
 *
 * @note 当 inputCount<=outputCapacity 时，每个输入点各占一列且 min=max；否则
 * 将输入均匀分桶，每个桶输出一对最小/最大值。input、minimumOutput 和
 * maximumOutput 三块内存不得重叠。
 * @par 适用场景
 * 将 1024、4096 等大采样块压到 448/480 个屏幕列，随后交给
 * Plot_DrawWaveformEnvelope()，避免漏掉窄脉冲和正负尖峰。
 */
uint16_t Signal_ReduceWaveformEnvelopeI16(
    const int16_t *input, uint32_t inputCount, int16_t *minimumOutput,
    int16_t *maximumOutput, uint16_t outputCapacity);

/**
 * @brief 对 uint16_t 原始波形同时执行线性标定和逐列包络压缩。
 *
 * @param input 原始 ADC/传感器数组，不可为 NULL。
 * @param inputCount 原始样本数，至少为 1。
 * @param map uint16_t 到 int16_t 的线性标定参数，不可为 NULL。
 * @param minimumOutput 每个时间桶映射后的数值最小值数组，不可为 NULL。
 * @param maximumOutput 每个时间桶映射后的数值最大值数组，不可为 NULL。
 * @param outputCapacity 两个输出数组各自的容量，至少为 1。
 * @return 返回实际写入两个数组的 uint16_t 列数；参数无效返回 0。
 *
 * @note 只扫描一次大数组，不需要先申请 inputCount 个 int16_t 中间元素。
 * 即使 map 是反向映射，也保证 minimumOutput[i]<=maximumOutput[i]。
 * input 与两个输出数组不得重叠，两个输出数组也不得互相重叠。
 * @par 适用场景
 * 直接将大型 ADC DMA 缓冲区转换成 mV 包络并压缩到屏幕宽度。
 */
uint16_t Signal_MapAndReduceWaveformEnvelopeU16(
    const uint16_t *input, uint32_t inputCount,
    const SignalLinearMap *map, int16_t *minimumOutput,
    int16_t *maximumOutput, uint16_t outputCapacity);

/**
 * @brief 将大型 uint16_t 频谱按区间最大值压缩到指定容量。
 *
 * @param input 非负频谱幅值数组，不可为 NULL。
 * @param inputCount 原始 bin 数，至少为 1。
 * @param output 压缩结果数组，不可为 NULL。
 * @param outputCapacity 输出最多容纳的 bin 数，至少为 1。
 * @return 返回实际写入的 uint16_t bin 数；参数无效返回 0。
 *
 * @note 当输入多于输出容量时，每个输出 bin 取对应输入区间的最大值，因而窄谱峰
 * 不会像简单等间隔抽点那样消失。输入与输出不得重叠。
 * @par 适用场景
 * 将 1024/2048 点 FFT 的单边频谱压缩到 448/480 个屏幕列。
 */
uint16_t Signal_ReduceSpectrumU16(const uint16_t *input,
                                  uint32_t inputCount, uint16_t *output,
                                  uint16_t outputCapacity);

/**
 * @brief 对 uint32_t 频谱同时执行满量程换算和区间最大值压缩。
 *
 * @param input uint32_t 频谱/功率数组，不可为 NULL。
 * @param inputCount 原始 bin 数，至少为 1。
 * @param inputFullScale 输入满量程，必须大于 0。
 * @param outputFullScale 输出满量程，必须大于 0。
 * @param output uint16_t 压缩结果数组，不可为 NULL。
 * @param outputCapacity 输出容量，至少为 1。
 * @return 返回实际写入的 uint16_t bin 数；参数无效返回 0。
 *
 * @note 先在每个区间寻找 uint32_t 最大值，再映射为 uint16_t，避免为完整
 * 大数组分配转换缓冲。输入与输出不得重叠。
 * @par 适用场景
 * 直接适配以 uint32_t 功率输出的 FFT/能量算法。
 */
uint16_t Signal_ScaleAndReduceSpectrumU32(const uint32_t *input,
                                          uint32_t inputCount,
                                          uint32_t inputFullScale,
                                          uint16_t outputFullScale,
                                          uint16_t *output,
                                          uint16_t outputCapacity);

/**
 * @brief 按固定纵轴量程直接绘制 int16_t 波形，大数组自动改画逐列包络。
 *
 * 参数含义与 Plot_DrawWaveform() 相同，区别是 sampleCount 为 uint32_t，允许
 * 输入大数组；sampleCount>width 时保留每列最小/最大值并绘制竖直包络，
 * sampleCount<=width 时仍按普通连续折线绘制。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏；也决定最多保留点数。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param samples int16_t 原始/算法波形数组，不可为 NULL。
 * @param sampleCount samples 的有效样本数，至少为 2。
 * @param minimum 固定纵轴最小值。
 * @param maximum 固定纵轴最大值，必须严格大于 minimum。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功绘制返回 true；参数、绘图区或量程无效返回 false。
 * @par 适用场景
 * 已完成滤波/变换并得到 int16_t 波形，且需要固定刻度比较多个刷新帧。
 */
bool SignalDisplay_DrawWaveform(uint16_t x, uint16_t y, uint16_t width,
                                uint16_t height, const int16_t *samples,
                                uint32_t sampleCount, int16_t minimum,
                                int16_t maximum, const PlotStyle *style);

/**
 * @brief 自动计算纵轴量程并绘制 int16_t 波形，大数组自动改画逐列包络。
 *
 * 参数含义与 Plot_DrawWaveformAuto() 相同；symmetric=true 适合以 0 为中心
 * 的交流信号，false 适合带直流偏置的趋势数据。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param samples int16_t 原始/算法波形数组，不可为 NULL。
 * @param sampleCount samples 的有效样本数，至少为 2。
 * @param symmetric true 使用关于 0 对称量程，false 使用带边距的实际范围。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功绘制返回 true；参数或绘图区无效返回 false。
 * @par 适用场景
 * 调试阶段快速显示幅度未知的大型采样数组。
 */
bool SignalDisplay_DrawWaveformAuto(uint16_t x, uint16_t y,
                                    uint16_t width, uint16_t height,
                                    const int16_t *samples,
                                    uint32_t sampleCount, bool symmetric,
                                    const PlotStyle *style);

/**
 * @brief 将 uint16_t 原始数组标定后按固定量程绘图，大数组自动改画包络。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param samples uint16_t ADC/传感器原始数组，不可为 NULL。
 * @param sampleCount samples 的有效样本数，至少为 2。
 * @param map 原始输入到 int16_t 工程量的线性映射，不可为 NULL。
 * @param minimum 映射后工程量的固定纵轴最小值。
 * @param maximum 映射后工程量的固定纵轴最大值，必须大于 minimum。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功绘制返回 true；参数、映射、区域或量程无效返回 false。
 * @par 适用场景
 * 把 ADC DMA 原始码直接显示成固定 mV/V/温度刻度，无需完整中间数组。
 */
bool SignalDisplay_DrawMappedWaveform(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint16_t *samples, uint32_t sampleCount,
    const SignalLinearMap *map, int16_t minimum, int16_t maximum,
    const PlotStyle *style);

/**
 * @brief 将 uint16_t 原始数组标定并自动量程绘图，大数组自动改画包络。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param samples uint16_t ADC/传感器原始数组，不可为 NULL。
 * @param sampleCount samples 的有效样本数，至少为 2。
 * @param map 原始输入到 int16_t 工程量的线性映射，不可为 NULL。
 * @param symmetric true 使用关于 0 对称量程，false 使用带边距的实际范围。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功绘制返回 true；参数、映射或区域无效返回 false。
 * @par 适用场景
 * 快速查看尚未确定显示量程的 ADC/传感器原始数据。
 */
bool SignalDisplay_DrawMappedWaveformAuto(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint16_t *samples, uint32_t sampleCount,
    const SignalLinearMap *map, bool symmetric, const PlotStyle *style);

/**
 * @brief 最大值保持压缩大型 uint16_t 频谱并按固定满量程直接绘制。
 *
 * 参数含义与 Plot_DrawSpectrum() 相同，区别是 binCount 为 uint32_t，允许输入
 * 大型频谱并在绘制前自动压缩到可用数据列数；启用边框时为 width-2 列。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param magnitudes uint16_t 非负频谱幅值数组，不可为 NULL。
 * @param binCount magnitudes 的有效 bin 数，至少为 1。
 * @param maximum 固定纵轴满量程，必须大于 0。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功绘制返回 true；参数、区域或满量程无效返回 false。
 * @par 适用场景
 * 需要固定幅度刻度、方便逐帧比较的实时频谱或能量分布。
 */
bool SignalDisplay_DrawSpectrum(uint16_t x, uint16_t y, uint16_t width,
                                uint16_t height,
                                const uint16_t *magnitudes,
                                uint32_t binCount, uint16_t maximum,
                                const PlotStyle *style);

/**
 * @brief 最大值保持压缩大型 uint16_t 频谱并自动满量程绘制。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param magnitudes uint16_t 非负频谱幅值数组，不可为 NULL。
 * @param binCount magnitudes 的有效 bin 数，至少为 1，可超过 65535。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功绘制返回 true；参数或区域无效返回 false。
 * @note 启用边框时压缩到 width-2 个数据列，首尾频率桶仍会显示在边框内侧。
 * @par 适用场景
 * 首次接入 FFT、幅值范围未知时快速确认频谱形状和谱峰位置。
 */
bool SignalDisplay_DrawSpectrumAuto(uint16_t x, uint16_t y,
                                    uint16_t width, uint16_t height,
                                    const uint16_t *magnitudes,
                                    uint32_t binCount,
                                    const PlotStyle *style);

/**
 * @brief 将大型 uint32_t 非负频谱缩放、最大值压缩后一次性绘制。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param magnitudes uint32_t 非负幅值、功率或能量数组，不可为 NULL。
 * @param binCount magnitudes 的有效元素数，至少为 1，可超过 65535。
 * @param inputFullScale 输入固定满量程，必须大于 0；超过它的值会钳位到图顶。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功完成缩放、压缩和绘制返回 true；参数无效返回 false。
 *
 * @note 内部把 inputFullScale 映射为 uint16_t 的 65535，再按此固定满量程绘图；
 * 不需要调用者申请中间数组。函数不会执行 FFT 复数取模。
 * @par 适用场景
 * FFT/相关/能量算法直接输出 uint32_t，且多帧需要使用固定幅度刻度时。
 */
bool SignalDisplay_DrawSpectrumU32(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint32_t *magnitudes, uint32_t binCount,
    uint32_t inputFullScale, const PlotStyle *style);

/**
 * @brief 自动寻找 uint32_t 数组满量程，随后缩放、压缩并一次性绘制频谱。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区宽度，必须为 3..480 且区域不可越屏。
 * @param height 绘图区高度，至少为 3 且区域不可越屏。
 * @param magnitudes uint32_t 非负幅值、功率或能量数组，不可为 NULL。
 * @param binCount magnitudes 的有效元素数，至少为 1，可超过 65535。
 * @param style PlotStyle 样式，不可为 NULL。
 * @return 成功自动量程并绘制返回 true；参数无效返回 false。
 *
 * @note 自动满量程取原数组最大值并增加约 10% 余量；全零数组使用满量程 1。
 * 每帧范围变化会导致视觉缩放，比赛成品需跨帧比较时优先使用固定量程版本。
 * @par 适用场景
 * 第一次接入 32 位算法结果、尚不知道合理固定满量程时快速观察频谱形状。
 */
bool SignalDisplay_DrawSpectrumU32Auto(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint32_t *magnitudes, uint32_t binCount,
    const PlotStyle *style);

/**
 * @brief 在指定 bin 区间寻找最大谱峰，并换算峰值频率。
 *
 * @param magnitudes 原始、未经显示压缩的 uint16_t 频谱数组，不可为 NULL。
 * @param binCount 数组有效 bin 总数。
 * @param firstBin 搜索起始下标，包含该 bin；设为 1 可跳过直流分量 DC。
 * @param lastBinExclusive 搜索结束下标，不包含该 bin；必须 <=binCount。
 * @param sampleRateHz 产生该 FFT 数据的采样率，单位 Hz。
 * @param fftLength FFT 点数，必须大于 0。
 * @param peak 输出结果指针，不可为 NULL。
 * @return 成功找到峰值并写入 peak 返回 true；区间或参数无效返回 false。
 *
 * @note 频率按 binIndex*sampleRateHz/fftLength 四舍五入计算；结果超过
 * UINT32_MAX 时饱和为 UINT32_MAX。若多个 bin 幅值相同，返回下标最小的
 * 第一个 bin。lastBinExclusive 还必须 <=fftLength。
 *
 * @warning 只能传入原始 FFT bin 数组。Signal_ReduceSpectrumU16() 的输出下标
 * 表示“显示桶”而非原始 FFT bin，不能用于本函数的频率换算。实数 FFT 的
 * 单边谱通常还应由调用者限制到 0..fftLength/2。
 * @par 适用场景
 * 在频谱 UI 的数据卡片中显示“峰值频率”和“峰值幅度”。
 */
bool SignalDisplay_FindSpectrumPeak(const uint16_t *magnitudes,
                                    uint32_t binCount, uint32_t firstBin,
                                    uint32_t lastBinExclusive,
                                    uint32_t sampleRateHz,
                                    uint32_t fftLength,
                                    SignalSpectrumPeak *peak);

#endif
