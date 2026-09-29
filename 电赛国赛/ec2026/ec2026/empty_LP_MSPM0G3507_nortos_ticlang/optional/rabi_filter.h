/* Rabi 备用模块：常用轻量数字滤波和迟滞工具。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 常用轻量滤波器
 * ==============
 *
 * 这些模块用于比赛现场快速稳定 ADC 显示值、阈值判断和控制给定，不申请堆内存，
 * 也不依赖 SysConfig。它们不能修复模拟前端饱和、采样混叠、错误接地或电源噪声：
 * ADC 前仍应按目标带宽设计 RC/有源低通，并用固定采样周期采集。
 *
 * 如何选择
 * --------
 *
 * - Moving Average：抑制随机噪声、计算便宜，但窗口越长延迟越大；
 * - EMA：只保存一个状态，响应平滑，alpha 越小越慢；
 * - Median：擅长去除偶发尖峰/毛刺，不适合替代普通低通；
 * - Slew Limiter：限制控制输出每一步变化，避免 DAC/PWM 给定突然跳变；
 * - Hysteresis：给比较阈值加回差，防止信号在边界附近反复开关。
 *
 * 滑动平均示例
 * ------------
 *
 *     static uint16_t s_average_storage[16];
 *     static rabi_moving_average_u16_t s_average;
 *
 *     rabi_moving_average_u16_init(
 *         &s_average, s_average_storage, 16U);
 *
 *     uint16_t filtered;
 *     rabi_moving_average_u16_push(&s_average, adc_raw, &filtered);
 *
 * storage 必须在滤波器使用期间一直有效。启动阶段只平均已经收到的样本，不会把
 * 尚未填满的窗口当成 0，因此不会人为产生一个从 0 缓慢爬升的输出。
 *
 * EMA 示例
 * --------
 *
 *     rabi_ema_f32_t ema;
 *     rabi_ema_f32_init(&ema, 0.1f);
 *     rabi_ema_f32_push(&ema, measurement, &filtered_value);
 *
 * 固定采样周期 dt 和目标时间常数 tau 已知时，可离线按
 * alpha ~= 1 - exp(-dt/tau) 计算。alpha=1 表示完全不平滑；alpha 很小会产生明显
 * 延迟。MSPM0G3507 无硬件 FPU，高速 ADC 流应优先使用整数滑动平均/中值，EMA
 * 更适合 UI 数值或中低速控制量。
 *
 * 中值滤波示例
 * ------------
 *
 *     rabi_median_u16_t median;
 *     rabi_median_u16_init(&median, 5U); // 仅允许 3/5/7/9 等奇数窗口
 *     rabi_median_u16_push(&median, adc_raw, &filtered);
 *
 * 本实现最多 9 点，每次用小数组插入排序，代码简单且不占用外部 scratch。连续
 * 高速大窗口滤波应另用更合适的算法，而不是扩大这里的固定数组。
 *
 * 控制输出限速与迟滞
 * ------------------
 *
 *     rabi_slew_limiter_f32_t limiter;
 *     rabi_slew_limiter_f32_init(&limiter, 5.0f, 10.0f);
 *     rabi_slew_limiter_f32_reset(&limiter, 0.0f);
 *     rabi_slew_limiter_f32_update(&limiter, pid_output, &safe_output);
 *
 * rise/fall 是“每次调用最多变化多少”，不是每秒。只有调用周期固定时才有明确
 * 物理意义。例如 1 ms 调一次、rise=5，等效最大上升速度为每秒 5000 个输出单位。
 *
 *     rabi_hysteresis_f32_t threshold;
 *     rabi_hysteresis_f32_init(&threshold, 1.9f, 2.1f, false);
 *     rabi_hysteresis_f32_update(&threshold, voltage, &state);
 *
 * state=false 时必须达到 high 才置 true；state=true 时必须低于 low 才清 false。
 * 这适合欠压/过压提示和比较器式逻辑，不等同于机械按键消抖。
 *
 * 执行上下文
 * ----------
 * 函数不加锁。一个滤波器对象只能由一个执行上下文更新；推荐 ADC/DMA 完成后在
 * 主循环处理，不要在 ISR 中跑中值排序、浮点 EMA 或显示更新。
 */

typedef struct
{
    uint16_t *storage;
    size_t window_size;
    size_t count;
    size_t index;
    uint32_t sum;
    bool initialized;
} rabi_moving_average_u16_t;

rabi_err_t rabi_moving_average_u16_init(
    rabi_moving_average_u16_t *filter,
    uint16_t *storage,
    size_t window_size);

rabi_err_t rabi_moving_average_u16_reset(
    rabi_moving_average_u16_t *filter);

rabi_err_t rabi_moving_average_u16_push(
    rabi_moving_average_u16_t *filter,
    uint16_t sample,
    uint16_t *output);

typedef struct
{
    float alpha;
    float value;
    bool has_value;
    bool initialized;
} rabi_ema_f32_t;

rabi_err_t rabi_ema_f32_init(
    rabi_ema_f32_t *filter, float alpha);

rabi_err_t rabi_ema_f32_reset(
    rabi_ema_f32_t *filter, float value);

rabi_err_t rabi_ema_f32_push(
    rabi_ema_f32_t *filter, float sample, float *output);

#define RABI_MEDIAN_U16_MAX_WINDOW 9U

typedef struct
{
    uint16_t samples[RABI_MEDIAN_U16_MAX_WINDOW];
    uint8_t window_size;
    uint8_t count;
    uint8_t index;
    bool initialized;
} rabi_median_u16_t;

/* window_size 必须是 3~9 的奇数。 */
rabi_err_t rabi_median_u16_init(
    rabi_median_u16_t *filter, uint8_t window_size);

rabi_err_t rabi_median_u16_reset(rabi_median_u16_t *filter);

rabi_err_t rabi_median_u16_push(
    rabi_median_u16_t *filter,
    uint16_t sample,
    uint16_t *output);

typedef struct
{
    float rise_per_step;
    float fall_per_step;
    float value;
    bool has_value;
    bool initialized;
} rabi_slew_limiter_f32_t;

rabi_err_t rabi_slew_limiter_f32_init(
    rabi_slew_limiter_f32_t *limiter,
    float rise_per_step,
    float fall_per_step);

rabi_err_t rabi_slew_limiter_f32_reset(
    rabi_slew_limiter_f32_t *limiter, float value);

rabi_err_t rabi_slew_limiter_f32_update(
    rabi_slew_limiter_f32_t *limiter,
    float target,
    float *output);

typedef struct
{
    float low_threshold;
    float high_threshold;
    bool state;
    bool initialized;
} rabi_hysteresis_f32_t;

rabi_err_t rabi_hysteresis_f32_init(
    rabi_hysteresis_f32_t *hysteresis,
    float low_threshold,
    float high_threshold,
    bool initial_state);

rabi_err_t rabi_hysteresis_f32_reset(
    rabi_hysteresis_f32_t *hysteresis, bool state);

rabi_err_t rabi_hysteresis_f32_update(
    rabi_hysteresis_f32_t *hysteresis,
    float input,
    bool *state);

#if defined(__cplusplus)
}
#endif
