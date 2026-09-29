/* TPA2000D1 自动功率控制综合示例：测量和 PI 控制实现。 */
#include <stddef.h>
#include "demo_agc.h"
#include "../../optional/rabi_signal.h"

static bool config_is_valid(const demo_agc_cfg_t *cfg);
static uint32_t calculate_load_rms_mv(
    const demo_agc_cfg_t *cfg, uint16_t adc_ac_rms_raw);
static uint32_t calculate_power_mw(
    uint32_t load_rms_mv, uint32_t load_resistance_milliohm);
static uint16_t round_control_mv(float value);

rabi_err_t demo_agc_init(
    demo_agc_t *agc, const demo_agc_cfg_t *cfg)
{
    if (agc == NULL || !config_is_valid(cfg))
    {
        return RABI_ERR_INVALID_ARG;
    }

    *agc = (demo_agc_t){
        .cfg = *cfg,
        .target_power_mw = cfg->power_max_mw,
        .control_mv = 0U,
        .filtered_power_mw = 0U,
        .elapsed_ms = 0U,
        .settled_blocks = 0U,
        .enabled = false,
        .initialized = true,
    };

    rabi_pid_cfg_t pid_cfg = {
        .kp = cfg->kp,
        .ki = cfg->ki,
        .kd = cfg->kd,
        .sample_time_s = (float)cfg->control_period_ms / 1000.0f,
        .output_min = (float)cfg->control_min_mv,
        .output_max = (float)cfg->control_max_mv,
        .integral_min = (float)cfg->control_min_mv,
        .integral_max = (float)cfg->control_max_mv,
        .derivative_filter = 0.20f,
    };

    rabi_err_t err = rabi_pid_init(&agc->pid, &pid_cfg);
    if (err != RABI_ERR_OK) return err;

    err = rabi_ema_f32_init(&agc->power_ema, cfg->power_ema_alpha);
    if (err != RABI_ERR_OK) return err;

    err = rabi_slew_limiter_f32_init(&agc->control_slew,
        cfg->control_rise_mv_per_step,
        cfg->control_fall_mv_per_step);
    if (err != RABI_ERR_OK) return err;

    return rabi_slew_limiter_f32_reset(&agc->control_slew, 0.0f);
}

rabi_err_t demo_agc_set_enabled(demo_agc_t *agc, bool enabled)
{
    if (agc == NULL || !agc->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    agc->enabled = enabled;
    agc->elapsed_ms = 0U;
    agc->settled_blocks = 0U;

    if (!enabled)
    {
        agc->control_mv = agc->cfg.control_min_mv;
        (void)rabi_slew_limiter_f32_reset(
            &agc->control_slew, (float)agc->control_mv);
        return rabi_pid_reset(
            &agc->pid, (float)agc->filtered_power_mw,
            (float)agc->cfg.control_start_mv);
    }

    /*
     * 打开功放前硬件层已经把 DAC 置为 0。控制器从 400 mV 的积分偏置起步，
     * 但 slew limiter 仍从 0 开始爬升，避免 DAC/音量突然跳变。
     */
    (void)rabi_slew_limiter_f32_reset(
        &agc->control_slew, (float)agc->cfg.control_min_mv);
    return rabi_pid_reset(
        &agc->pid, (float)agc->filtered_power_mw,
        (float)agc->cfg.control_start_mv);
}

rabi_err_t demo_agc_set_target_mw(demo_agc_t *agc, uint16_t target_mw)
{
    if (agc == NULL || !agc->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (target_mw < agc->cfg.power_min_mw ||
        target_mw > agc->cfg.power_max_mw ||
        ((uint32_t)target_mw - agc->cfg.power_min_mw) %
            agc->cfg.power_step_mw != 0U)
    {
        return RABI_ERR_INVALID_ARG;
    }

    agc->target_power_mw = target_mw;
    agc->elapsed_ms = 0U;
    agc->settled_blocks = 0U;
    return RABI_ERR_OK;
}

rabi_err_t demo_agc_process(
    demo_agc_t *agc,
    const uint16_t *samples,
    size_t sample_count,
    demo_agc_result_t *result)
{
    if (agc == NULL || !agc->initialized ||
        samples == NULL || sample_count == 0U || result == NULL)
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_signal_stats_u16_t stats;
    rabi_err_t err = rabi_signal_stats_u16(samples, sample_count, &stats);
    if (err != RABI_ERR_OK) return err;

    uint32_t load_rms_mv = calculate_load_rms_mv(
        &agc->cfg, stats.ac_rms_raw);
    uint32_t instantaneous_power_mw = calculate_power_mw(
        load_rms_mv, agc->cfg.load_resistance_milliohm);

    float filtered_power;
    err = rabi_ema_f32_push(&agc->power_ema,
        (float)instantaneous_power_mw, &filtered_power);
    if (err != RABI_ERR_OK) return err;
    if (filtered_power < 0.0f) filtered_power = 0.0f;
    agc->filtered_power_mw = (uint32_t)(filtered_power + 0.5f);

    rabi_signal_frequency_u16_t frequency = {0};
    if (rabi_signal_measure_frequency_u16(
            samples,
            sample_count,
            1U,
            agc->cfg.sample_rate_hz,
            stats.mean_raw,
            agc->cfg.frequency_hysteresis_raw,
            &frequency) != RABI_ERR_OK)
    {
        /* 直流、幅度过小或块内周期不足时，0 Hz 只表示“本块没有可靠测到”。 */
        frequency.frequency_millihz = 0U;
    }

    bool saturated = false;
    bool settled = false;
    if (agc->enabled)
    {
        float requested_control;
        err = rabi_pid_update(&agc->pid,
            (float)agc->target_power_mw,
            filtered_power,
            &requested_control);
        if (err != RABI_ERR_OK) return err;

        float limited_control;
        err = rabi_slew_limiter_f32_update(
            &agc->control_slew, requested_control, &limited_control);
        if (err != RABI_ERR_OK) return err;
        agc->control_mv = round_control_mv(limited_control);

        saturated = requested_control <=
                (float)agc->cfg.control_min_mv + 0.5f ||
            requested_control >=
                (float)agc->cfg.control_max_mv - 0.5f;

        uint32_t error_mw = agc->filtered_power_mw > agc->target_power_mw ?
            agc->filtered_power_mw - agc->target_power_mw :
            agc->target_power_mw - agc->filtered_power_mw;
        if ((uint64_t)error_mw * 10U <= agc->target_power_mw)
        {
            if (agc->settled_blocks < UINT8_MAX)
            {
                agc->settled_blocks++;
            }
        }
        else
        {
            agc->settled_blocks = 0U;
        }

        settled = agc->settled_blocks >= agc->cfg.settle_confirm_blocks;
        if (agc->elapsed_ms <= UINT32_MAX - agc->cfg.control_period_ms)
        {
            agc->elapsed_ms += agc->cfg.control_period_ms;
        }
    }
    else
    {
        agc->control_mv = agc->cfg.control_min_mv;
        agc->settled_blocks = 0U;
        agc->elapsed_ms = 0U;
    }

    *result = (demo_agc_result_t){
        .adc_mean_raw = stats.mean_raw,
        .adc_ac_rms_raw = stats.ac_rms_raw,
        .load_rms_mv = load_rms_mv,
        .power_mw = agc->filtered_power_mw,
        .frequency_millihz = frequency.frequency_millihz,
        .control_mv = agc->control_mv,
        .elapsed_ms = agc->elapsed_ms,
        .settled = settled,
        .control_saturated = saturated,
    };
    return RABI_ERR_OK;
}

static bool config_is_valid(const demo_agc_cfg_t *cfg)
{
    if (cfg == NULL || cfg->sample_rate_hz == 0U ||
        cfg->control_period_ms == 0U || cfg->adc_reference_mv == 0U ||
        cfg->adc_full_scale_raw == 0U ||
        cfg->sense_gain_numerator == 0U ||
        cfg->sense_gain_denominator == 0U ||
        cfg->voltage_cal_numerator == 0U ||
        cfg->voltage_cal_denominator == 0U ||
        cfg->load_resistance_milliohm == 0U ||
        cfg->power_min_mw == 0U ||
        cfg->power_min_mw > cfg->power_max_mw ||
        cfg->power_step_mw == 0U ||
        cfg->control_min_mv >= cfg->control_max_mv ||
        cfg->control_start_mv < cfg->control_min_mv ||
        cfg->control_start_mv > cfg->control_max_mv ||
        cfg->power_ema_alpha <= 0.0f || cfg->power_ema_alpha > 1.0f ||
        cfg->control_rise_mv_per_step <= 0.0f ||
        cfg->control_fall_mv_per_step <= 0.0f ||
        cfg->settle_confirm_blocks == 0U)
    {
        return false;
    }

    return cfg->kp == cfg->kp && cfg->ki == cfg->ki && cfg->kd == cfg->kd;
}

static uint32_t calculate_load_rms_mv(
    const demo_agc_cfg_t *cfg, uint16_t adc_ac_rms_raw)
{
    /* 先换算 ADC 引脚交流 RMS，分步运算可避免把标定系数一同相乘而溢出。 */
    uint64_t adc_mv_numerator =
        (uint64_t)adc_ac_rms_raw * cfg->adc_reference_mv;
    uint32_t adc_rms_mv = (uint32_t)((adc_mv_numerator +
        cfg->adc_full_scale_raw / 2U) / cfg->adc_full_scale_raw);

    uint64_t load_mv_numerator =
        (uint64_t)adc_rms_mv * cfg->sense_gain_denominator;
    uint32_t load_rms_mv = (uint32_t)((load_mv_numerator +
        cfg->sense_gain_numerator / 2U) / cfg->sense_gain_numerator);

    uint64_t calibrated =
        (uint64_t)load_rms_mv * cfg->voltage_cal_numerator;
    return (uint32_t)((calibrated +
        cfg->voltage_cal_denominator / 2U) /
        cfg->voltage_cal_denominator);
}

static uint32_t calculate_power_mw(
    uint32_t load_rms_mv, uint32_t load_resistance_milliohm)
{
    /* mV^2 / mOhm 的数值单位恰好是 mW。 */
    uint64_t squared_mv = (uint64_t)load_rms_mv * load_rms_mv;
    uint64_t power = (squared_mv + load_resistance_milliohm / 2U) /
        load_resistance_milliohm;
    return power > UINT32_MAX ? UINT32_MAX : (uint32_t)power;
}

static uint16_t round_control_mv(float value)
{
    if (value <= 0.0f) return 0U;
    if (value >= (float)UINT16_MAX) return UINT16_MAX;
    return (uint16_t)(value + 0.5f);
}

