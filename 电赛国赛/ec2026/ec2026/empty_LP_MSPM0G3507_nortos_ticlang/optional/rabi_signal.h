/* Rabi 备用模块：ADC 样本块统计与采样波形测频。 */
#pragma once

#include <stddef.h>
#include <stdint.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * ADC 样本块分析
 * ==============
 *
 * 面向 rabi_adc_dma 采到的一段 uint16_t 原始数据，提供不依赖浮点/数学库的常用
 * 指标：均值、RMS、去直流 RMS、最小值、最大值和峰峰值，并可从带直流偏置的周期
 * 波形估计频率。
 *
 * RMS 的区别
 * ----------
 *
 *     rms_raw    = sqrt(mean(x^2))
 *     ac_rms_raw = sqrt(mean((x - mean)^2))
 *
 * rms_raw 包含直流。例如 1.65 V 偏置上的小交流，其总 RMS 主要由 1.65 V 决定；
 * 要衡量交流有效值应使用 ac_rms_raw。若模拟前端存在固定增益/偏置，应先明确题目
 * 要的是 ADC 引脚值、传感器原值还是经过标定后的物理量。
 *
 * 最小示例
 * --------
 *
 *     static uint16_t s_samples[1024] __attribute__((aligned(4)));
 *     rabi_signal_stats_u16_t stats;
 *
 *     rabi_adc_dma_capture(&s_capture, s_samples, 1024U);
 *     rabi_signal_stats_u16(s_samples, 1024U, &stats);
 *
 *     // 12-bit ADC、2500 mV 参考的近似换算：
 *     uint32_t ac_rms_mv =
 *         (uint32_t)stats.ac_rms_raw * 2500U / 4095U;
 *
 * 多通道交错缓冲区
 * ----------------
 * ADC Sequence + DMA 可能得到：
 *
 *     CH0, CH1, CH2, CH0, CH1, CH2, ...
 *
 * 不需要复制拆包。分析 CH1 时从 &samples[1] 开始，selected_count 填帧数，stride
 * 填通道数 3：
 *
 *     rabi_signal_stats_u16_strided(
 *         &samples[1], frame_count, 3U, &stats_ch1);
 *
 * 采样波形测频
 * ------------
 * measure_frequency() 先要求信号低于 center-hysteresis，再确认其穿过 center 并达到
 * center+hysteresis，能抑制中心附近噪声造成的重复计数。每次上升过零用相邻样本
 * 线性插值，最后以第一和最后过零之间的多个周期取平均。
 *
 *     rabi_signal_frequency_u16_t frequency;
 *     rabi_signal_measure_frequency_u16(
 *         s_samples,
 *         1024U,
 *         1U,
 *         20000U,        // ADC 的真实固定采样率
 *         stats.mean_raw,
 *         20U,           // 原码迟滞，按噪声幅度调整
 *         &frequency);
 *
 * frequency.frequency_millihz=123456 表示 123.456 Hz。至少要包含两个有效上升过零；
 * 缓冲区覆盖周期越多，显示通常越稳，但更新越慢。信号严重失真、有多个峰或噪声
 * 很大时，最好先模拟整形后用 rabi_pulse_capture，而不是不断扩大软件迟滞。
 *
 * 采样与混叠
 * ----------
 * DMA 只保证搬运，不保证采样间隔；测频/RMS 时 ADC 应由 Timer Event 固定触发。
 * 采样率必须高于信号最高频率的两倍，但竞赛测量通常应预留更多点数并加模拟抗混叠
 * 滤波。已经混叠进来的错误频率无法靠滑动平均或本模块恢复。
 *
 * 峰峰值对单个毛刺非常敏感；怀疑尖峰时，可同时看 min/max、ac_rms，并先做 3 点
 * 中值滤波。所有块分析都应在主循环进行，不要在 ADC/DMA ISR 里跑两遍大缓冲区。
 */

typedef struct
{
    uint16_t minimum_raw;
    uint16_t maximum_raw;
    uint16_t mean_raw;
    uint16_t rms_raw;
    uint16_t ac_rms_raw;
    uint16_t peak_to_peak_raw;
} rabi_signal_stats_u16_t;

rabi_err_t rabi_signal_stats_u16(
    const uint16_t *samples,
    size_t sample_count,
    rabi_signal_stats_u16_t *stats);

/*
 * samples 指向第一个被选样本；之后依次读取 samples[0], samples[stride]...
 * selected_count 是被选样本个数，不是原始缓冲区总长度。
 */
rabi_err_t rabi_signal_stats_u16_strided(
    const uint16_t *samples,
    size_t selected_count,
    size_t stride,
    rabi_signal_stats_u16_t *stats);

typedef struct
{
    uint32_t frequency_millihz;

    /* Q16.16 样本数。例如 3.5 samples 表示 3U*65536U + 32768U。 */
    uint64_t period_samples_q16;

    size_t rising_crossings;
} rabi_signal_frequency_u16_t;

/*
 * 对等间隔 uint16_t 样本做带迟滞的上升过零测频。center±hysteresis 必须仍在
 * uint16_t 范围内；至少两个确认过零才返回 OK，否则返回 RABI_ERR_NOT_FOUND。
 */
rabi_err_t rabi_signal_measure_frequency_u16(
    const uint16_t *samples,
    size_t selected_count,
    size_t stride,
    uint32_t sample_rate_hz,
    uint16_t center,
    uint16_t hysteresis,
    rabi_signal_frequency_u16_t *frequency);

#if defined(__cplusplus)
}
#endif
