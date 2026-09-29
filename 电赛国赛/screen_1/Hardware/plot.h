#ifndef PLOT_DRIVER_H
#define PLOT_DRIVER_H

#include <stdbool.h>
#include <stdint.h>

/**
 * @file plot.h
 * @brief 面向竞赛仪器 UI 的网格、时域波形和频谱柱状图绘制接口。
 *
 * 本模块直接把一组 int16_t 时域采样或 uint16_t 频谱幅值映射到指定矩形区域，
 * 并一次性绘制背景、网格、坐标轴、边框和曲线/谱线。坐标系与屏幕一致：
 * 左上角为 (0,0)，x 向右，y 向下；颜色均为 RGB565。
 *
 * 绘图区必须完整位于 480x320 屏幕内，且宽、高均至少为 3 像素。模块内部使用
 * 以屏幕宽度为上限的静态行缓冲区，因此接口不是可重入的，不应在中断和主循环
 * 中并发调用。建议只在主循环或页面刷新函数中绘图。
 */

/**
 * @brief 波形图/频谱图的颜色、网格密度和显示开关集合。
 *
 * 可先复制 PLOT_STYLE_DARK，再按页面需要修改个别字段。结构体只在函数调用
 * 期间被读取，调用结束后不会保存其地址。
 */
typedef struct {
    uint16_t backgroundColor; /**< 绘图区底色，RGB565。 */
    uint16_t gridColor;       /**< 内部网格线颜色，RGB565。 */
    uint16_t axisColor;       /**< 零值轴/频谱基线颜色，RGB565。 */
    uint16_t traceColor;      /**< 波形曲线或频谱柱颜色，RGB565。 */
    uint16_t borderColor;     /**< 绘图区最外圈边框颜色，RGB565。 */
    uint8_t xDivisions;       /**< 横轴分区数；0 或 1 表示不画内部竖网格线。 */
    uint8_t yDivisions;       /**< 纵轴分区数；0 或 1 表示不画内部横网格线。 */
    uint8_t traceThickness;   /**< 波形线宽（像素）；0 按 1 处理。频谱接口忽略此项。 */
    bool drawBorder;          /**< true 绘制一像素外边框，false 不绘制。 */
    bool drawZeroAxis;        /**< true 绘制零值轴/频谱基线，false 不绘制。 */
} PlotStyle;

/**
 * @brief 模块自带的深色仪器风格，只读样式常量。
 *
 * 适合深色背景的示波器、频谱仪和参数测量页面。若要定制，不要修改该 const
 * 对象；应使用 `PlotStyle style = PLOT_STYLE_DARK;` 复制后再改字段。
 */
extern const PlotStyle PLOT_STYLE_DARK;

/**
 * @brief 在指定矩形中绘制纯背景、网格、可选边框和零值横轴。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区总宽度，包含可选边框；必须至少为 3，且区域不可越屏。
 * @param height 绘图区总高度，包含可选边框；必须至少为 3，且区域不可越屏。
 * @param minimum 纵轴底端代表的最小数值。
 * @param maximum 纵轴顶端代表的最大数值；必须严格大于 minimum。
 * @param style 绘图样式指针；不可为 NULL，调用期间内容必须有效。
 * @return 无（返回类型为 void）。任一参数无效时直接返回且不绘制。
 *
 * @note 仅当 drawZeroAxis 为 true 且数值范围包含 0 时才绘制零值横轴。
 *       本函数会覆盖整个绘图区，而不是叠加几条透明网格线。
 * @par 适用场景
 * 在尚无采样数据时先画空坐标区、制作固定背景，或单独显示测量网格。
 */
void Plot_DrawGrid(uint16_t x, uint16_t y, uint16_t width,
                   uint16_t height, int16_t minimum, int16_t maximum,
                   const PlotStyle *style);

/**
 * @brief 按给定纵轴量程绘制一组时域采样波形及完整绘图区。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区总宽度；至少为 3，且 x+width 不得超过屏幕宽度。
 * @param height 绘图区总高度；至少为 3，且 y+height 不得超过屏幕高度。
 * @param samples int16_t 采样数组首地址；不可为 NULL。数组由调用者管理。
 * @param sampleCount samples 中的有效样本数；必须至少为 2。
 * @param minimum 纵轴底端量程。小于此值的样本会被钳位到图底端。
 * @param maximum 纵轴顶端量程；必须严格大于 minimum。大于此值的样本会被
 *                钳位到图顶端。
 * @param style 绘图样式指针；不可为 NULL。
 * @return 返回类型为 bool。成功完成绘制返回 true；空指针、样本不足、区域
 *         尺寸/边界无效或 maximum<=minimum 时返回 false，且不绘制。
 *
 * @note 函数把整个 sampleCount 线性铺满 width：样本数与像素列数不相等时会
 *       进行线性插值/重采样。每次调用都会重画该区域的背景、网格和曲线。
 * @par 适用场景
 * 量程已知或需要固定刻度的示波器波形、ADC 曲线、传感器趋势和调制信号显示。
 */
bool Plot_DrawWaveform(uint16_t x, uint16_t y, uint16_t width,
                       uint16_t height, const int16_t *samples,
                       uint16_t sampleCount, int16_t minimum,
                       int16_t maximum, const PlotStyle *style);

/**
 * @brief 按每个横向数据桶的最小/最大值绘制峰值包络波形。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区总宽度；至少为 3，且区域必须完整位于屏幕内。
 * @param height 绘图区总高度；至少为 3，且区域必须完整位于屏幕内。
 * @param minimumValues 每个数据桶的最小值数组，不可为 NULL。
 * @param maximumValues 每个数据桶的最大值数组，不可为 NULL。若某位置的两个
 *                      数值顺序相反，函数会自动交换后绘制。
 * @param columnCount 两个数组的有效元素数，至少为 1。通常应等于 width，使
 *                    每个数据桶正好对应一个屏幕 x 列。
 * @param minimum 纵轴底端固定量程。
 * @param maximum 纵轴顶端固定量程，必须严格大于 minimum。
 * @param style 绘图样式指针，不可为 NULL；traceThickness 会向竖直包络两端扩展。
 * @return 返回类型为 bool。成功绘制返回 true；指针、区域、数量或量程无效时
 *         返回 false。
 *
 * @note 与 Plot_DrawWaveform() 的“连续折线”不同，本函数在同一个 x 列内绘制
 *       minimumValues[i] 到 maximumValues[i] 的竖直线段，适合大量采样压缩后
 *       同时保留正、负尖峰。每次调用仍会重画整个图表背景和网格。
 * @par 适用场景
 * 大型 ADC/DMA 采样块的示波器包络、窄脉冲捕获和峰峰值趋势显示。普通少量
 * 等间隔采样仍应使用 Plot_DrawWaveform()，以获得自然的点间连线。
 */
bool Plot_DrawWaveformEnvelope(uint16_t x, uint16_t y, uint16_t width,
                               uint16_t height,
                               const int16_t *minimumValues,
                               const int16_t *maximumValues,
                               uint16_t columnCount, int16_t minimum,
                               int16_t maximum, const PlotStyle *style);

/**
 * @brief 统计时域采样数组，并生成可直接用于绘图的纵轴上下限。
 *
 * @param samples int16_t 采样数组首地址；不可为 NULL。
 * @param sampleCount samples 中的有效样本数；必须至少为 1。
 * @param symmetric 是否强制量程关于 0 对称：true 输出 [-A,+A]；false 根据实际
 *                  最小/最大值并在上下各加入约 5% 的整数边距（至少 1）。
 * @param minimum 输出参数；成功时写入建议的纵轴最小值，不可为 NULL。
 * @param maximum 输出参数；成功时写入建议的纵轴最大值，不可为 NULL。
 * @return 返回类型为 bool。成功统计并写入范围返回 true；任一指针为 NULL 或
 *         sampleCount 为 0 时返回 false，此时不要使用输出值。
 *
 * @note 全零数据在 symmetric=true 时得到 [-1,+1]，保证上下限不相等。
 *       对称量程最大限制为 [-32767,+32767]；输入中的 -32768 会在绘图时钳位。
 * @par 适用场景
 * 在绘制未知幅度的 ADC/传感器数据前自动取量程；交流信号通常选择 true，
 * 带直流偏置且希望完整利用纵向空间时通常选择 false。
 */
bool Plot_GetWaveformRange(const int16_t *samples, uint16_t sampleCount,
                           bool symmetric, int16_t *minimum,
                           int16_t *maximum);

/**
 * @brief 自动计算纵轴量程并绘制时域波形。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区总宽度；至少为 3，且区域必须完整位于屏幕内。
 * @param height 绘图区总高度；至少为 3，且区域必须完整位于屏幕内。
 * @param samples int16_t 采样数组首地址；不可为 NULL。
 * @param sampleCount samples 中的有效样本数。范围计算允许 1 个样本，但实际
 *                    波形绘制要求至少 2 个，因此本接口应传入至少 2。
 * @param symmetric true 使用关于 0 对称量程，false 使用带边距的非对称量程。
 * @param style 绘图样式指针；不可为 NULL。
 * @return 返回类型为 bool。范围计算及绘制均成功返回 true；任何参数不满足
 *         要求时返回 false。
 *
 * @par 适用场景
 * 快速显示幅度未知的采样数组，不希望在业务代码中手动寻找最大值和最小值时。
 * 若多个刷新帧需要保持刻度稳定，应改用 Plot_DrawWaveform() 并固定量程。
 */
bool Plot_DrawWaveformAuto(uint16_t x, uint16_t y, uint16_t width,
                           uint16_t height, const int16_t *samples,
                           uint16_t sampleCount, bool symmetric,
                           const PlotStyle *style);

/**
 * @brief 按给定满量程绘制非负频谱幅值数组及完整绘图区。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区总宽度；至少为 3，且区域必须完整位于屏幕内。
 * @param height 绘图区总高度；至少为 3，且区域必须完整位于屏幕内。
 * @param magnitudes uint16_t 频谱幅值数组首地址；不可为 NULL。通常为 FFT
 *                   取模或归一化后的非负幅值。
 * @param binCount magnitudes 中的有效频点数量；必须至少为 1。
 * @param maximum 纵轴满量程幅值；必须大于 0。超过该值的幅值会被钳位到图顶。
 * @param style 绘图样式指针；不可为 NULL。
 * @return 返回类型为 bool。成功完成绘制返回 true；空指针、空数组、零满量程
 *         或绘图区无效时返回 false。
 *
 * @note 频点沿可用数据列线性映射为竖向谱柱，并保证首、末 bin 分别落在首、
 *       末数据列。drawBorder=true 时数据列为 localX=1..width-2；否则为
 *       0..width-1。binCount 多于数据列时仍会跳过部分中间 bin，需保留窄谱峰
 *       时请优先使用 signal_display.h 的高层最大值压缩接口。本函数不执行
 *       FFT、窗函数、dB 换算或频率刻度换算，这些工作应由业务层完成。
 * @par 适用场景
 * 满量程需要固定、便于不同帧直接比较的频谱仪、谐波幅值图或通道能量分布图。
 */
bool Plot_DrawSpectrum(uint16_t x, uint16_t y, uint16_t width,
                       uint16_t height, const uint16_t *magnitudes,
                       uint16_t binCount, uint16_t maximum,
                       const PlotStyle *style);

/**
 * @brief 根据频谱数组最大值自动选择满量程并绘制频谱。
 *
 * @param x 绘图区左上角横坐标。
 * @param y 绘图区左上角纵坐标。
 * @param width 绘图区总宽度；至少为 3，且区域必须完整位于屏幕内。
 * @param height 绘图区总高度；至少为 3，且区域必须完整位于屏幕内。
 * @param magnitudes uint16_t 频谱幅值数组首地址；不可为 NULL。
 * @param binCount magnitudes 中的有效频点数量；必须至少为 1。
 * @param style 绘图样式指针；不可为 NULL。
 * @return 返回类型为 bool。自动量程并成功绘制返回 true；参数或区域无效时
 *         返回 false。
 *
 * @note 自动满量程取数组最大值再增加 maximum/10 的整数余量，并限制在
 *       65535；全零数组使用满量程 1。最大值小于 10 时，整数除法可能不增加
 *       顶部余量。每帧数据幅度变化会导致刻度变化。
 * @par 适用场景
 * 快速查看未知幅度的 FFT 结果、调试是否存在谱峰，或首屏自动适配数据。
 * 若要让多帧频谱具有可比性，应改用 Plot_DrawSpectrum() 固定 maximum。
 */
bool Plot_DrawSpectrumAuto(uint16_t x, uint16_t y, uint16_t width,
                           uint16_t height, const uint16_t *magnitudes,
                           uint16_t binCount, const PlotStyle *style);

#endif
