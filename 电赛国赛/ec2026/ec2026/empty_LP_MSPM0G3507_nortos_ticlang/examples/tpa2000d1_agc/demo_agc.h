/* TPA2000D1 自动功率控制综合示例：与硬件无关的测量和 PI 控制。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../../core/rabi_err.h"
#include "../../optional/rabi_filter.h"
#include "../../optional/rabi_pid.h"

#if defined(__cplusplus)
extern "C"
{
#endif

typedef struct
{
    uint32_t sample_rate_hz;
    uint32_t control_period_ms;
    uint32_t adc_reference_mv;
    uint16_t adc_full_scale_raw;
    uint32_t sense_gain_numerator;
    uint32_t sense_gain_denominator;
    uint32_t voltage_cal_numerator;
    uint32_t voltage_cal_denominator;
    uint32_t load_resistance_milliohm;
    uint16_t power_min_mw;
    uint16_t power_max_mw;
    uint16_t power_step_mw;
    uint16_t control_min_mv;
    uint16_t control_max_mv;
    uint16_t control_start_mv;
    float kp;
    float ki;
    float kd;
    float power_ema_alpha;
    float control_rise_mv_per_step;
    float control_fall_mv_per_step;
    uint8_t settle_confirm_blocks;
    uint16_t frequency_hysteresis_raw;
} demo_agc_cfg_t;

typedef struct
{
    uint16_t adc_mean_raw;
    uint16_t adc_ac_rms_raw;
    uint32_t load_rms_mv;
    uint32_t power_mw;
    uint32_t frequency_millihz;
    uint16_t control_mv;
    uint32_t elapsed_ms;
    bool settled;
    bool control_saturated;
} demo_agc_result_t;

typedef struct
{
    demo_agc_cfg_t cfg;
    rabi_pid_t pid;
    rabi_ema_f32_t power_ema;
    rabi_slew_limiter_f32_t control_slew;
    uint16_t target_power_mw;
    uint16_t control_mv;
    uint32_t filtered_power_mw;
    uint32_t elapsed_ms;
    uint8_t settled_blocks;
    bool enabled;
    bool initialized;
} demo_agc_t;

rabi_err_t demo_agc_init(
    demo_agc_t *agc, const demo_agc_cfg_t *cfg);

rabi_err_t demo_agc_set_enabled(demo_agc_t *agc, bool enabled);

/* target_mw 必须处于范围内，并且是 power_step_mw 的整数档位。 */
rabi_err_t demo_agc_set_target_mw(demo_agc_t *agc, uint16_t target_mw);

/*
 * 对一个 ADC 样本块计算“去直流 RMS -> 负载真实 RMS -> P=Vrms^2/R”，然后运行
 * 一次 PI/PID。方波和三角波不需要单独判断，因为真正的 RMS 定义与波形无关。
 */
rabi_err_t demo_agc_process(
    demo_agc_t *agc,
    const uint16_t *samples,
    size_t sample_count,
    demo_agc_result_t *result);

#if defined(__cplusplus)
}
#endif

