/* TPA2000D1 自动功率控制综合示例：统一的软件参数。 */
#pragma once

#include <stdint.h>

/*
 * ADC 由 100 kHz Timer Event 等间隔触发；2048 点约覆盖 20.48 ms。
 * 缓冲区长度必须为偶数且 4-byte 对齐，原因见 optional/rabi_adc_dma.h。
 */
#define DEMO_SAMPLE_RATE_HZ                 100000U
#define DEMO_SAMPLE_COUNT                   2048U
#define DEMO_CONTROL_PERIOD_MS              100U

/* ADC 使用 VDDA/VSSA 作为 12-bit 参考。比赛前测量 VDDA 后替换 3300。 */
#define DEMO_ADC_REFERENCE_MV               3300U
#define DEMO_ADC_FULL_SCALE_RAW             4095U

/*
 * BTL 差分取样前端：Vadc_ac = (27 k / 100 k) * (OUTP - OUTN)。
 * 四个比例电阻必须同批次、0.1% 或更好，优先使用匹配网络。
 */
#define DEMO_SENSE_GAIN_NUMERATOR           27U
#define DEMO_SENSE_GAIN_DENOMINATOR         100U

/*
 * 电压链路二次标定系数，默认 1.0000。若示波器测得 2.000 Vrms，而程序显示
 * 1.970 Vrms，可设为 20000 / 19700。分子、分母都不要填 0。
 */
#define DEMO_VOLTAGE_CAL_NUMERATOR          10000U
#define DEMO_VOLTAGE_CAL_DENOMINATOR        10000U

/* 拆下并用四线法/可靠万用表测量负载后，按毫欧填写，例如 3.982 ohm = 3982。 */
#define DEMO_LOAD_RESISTANCE_MILLIOHM       4000U

/* 功率设定范围与步长，单位 mW。 */
#define DEMO_POWER_MIN_MW                   200U
#define DEMO_POWER_MAX_MW                   2000U
#define DEMO_POWER_STEP_MW                  200U

/*
 * DAC 输出 0~1.6 V，经 OPA2172 单位增益反相后成为 VCA810 的 0~-1.6 V VC。
 * 外部输入先固定衰减约 6 dB，VCA810 再提供 -40~+24 dB；加上 TPA 的
 * 23.5 dB，系统最大标称电压增益约 41.5 dB。
 */
#define DEMO_CONTROL_MIN_MV                 0U
#define DEMO_CONTROL_MAX_MV                 1600U
#define DEMO_CONTROL_START_MV               400U

/* 初始 PI 参数单位：KP[mV/mW]，KI[mV/(mW*s)]，KD[mV*s/mW]。 */
#define DEMO_PID_KP                         0.20f
#define DEMO_PID_KI                         0.50f
#define DEMO_PID_KD                         0.00f

/* 每 100 ms 最多改变 75 mV，既限制突变，又允许约 2.2 s 走完全量程。 */
#define DEMO_CONTROL_RISE_MV_PER_STEP       75.0f
#define DEMO_CONTROL_FALL_MV_PER_STEP       100.0f

/* 功率显示/反馈的 EMA；0.35 比较灵敏，现场噪声大时再减小。 */
#define DEMO_POWER_EMA_ALPHA                0.35f

/* 连续 5 个控制块落在 +/-10% 内才显示 OK。 */
#define DEMO_SETTLE_CONFIRM_BLOCKS          5U

/* 测频上升过零的原码迟滞。频率只作联调诊断，不参与功率控制。 */
#define DEMO_FREQUENCY_HYSTERESIS_RAW       12U

