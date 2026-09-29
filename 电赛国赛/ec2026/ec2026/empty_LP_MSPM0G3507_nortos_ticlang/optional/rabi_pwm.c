/* Rabi 备用模块：MSPM0 硬件定时器 PWM 控制实现。 */
#include "rabi_pwm.h"

#define RABI_PWM_MAX_DUTY_PERMILLE 1000U

static rabi_err_t calculate_period_counts(
    const rabi_pwm_t *pwm,
    uint32_t frequency_hz,
    uint32_t *period_counts);
static void apply_waveform(rabi_pwm_t *pwm);
static void force_output_low(rabi_pwm_t *pwm);

rabi_err_t rabi_pwm_init(
    rabi_pwm_t *pwm, const rabi_pwm_cfg_t *cfg)
{
    if (pwm == NULL || cfg == NULL || cfg->instance == NULL ||
        cfg->timer_clock_hz == 0 || cfg->max_period_counts < 2U ||
        cfg->frequency_hz == 0 ||
        cfg->duty_permille > RABI_PWM_MAX_DUTY_PERMILLE ||
        (uint32_t)cfg->cc_index > (uint32_t)DL_TIMER_CC_5_INDEX)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /*
     * 电源、计数时钟、IOMUX 和 PWM 动作表应由 SYSCFG_DL_init() 完成。
     * 本层只改 LOAD、CTR、CC 和软件强制输出，不重新发明整套 Timer 配置。
     */
    if (!DL_Timer_isPowerEnabled(cfg->instance) ||
        !DL_Timer_isClockEnabled(cfg->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (DL_Timer_getCounterMode(cfg->instance) != DL_TIMER_COUNT_MODE_DOWN)
    {
        return RABI_ERR_NOT_SUPPORTED;
    }

    *pwm = (rabi_pwm_t){
        .cfg = *cfg,
        .period_counts = 0,
        .frequency_hz = 0,
        .duty_permille = cfg->duty_permille,
        .enabled = false,
        .initialized = true,
    };

    /* 初始化阶段先保持低电平，完成周期和比较值更新后再按配置决定是否启动。 */
    DL_Timer_stopCounter(pwm->cfg.instance);
    force_output_low(pwm);

    rabi_err_t err = rabi_pwm_set_frequency(pwm, cfg->frequency_hz);
    if (err != RABI_ERR_OK)
    {
        pwm->initialized = false;
        return err;
    }

    return rabi_pwm_set_enabled(pwm, cfg->start_on_init);
}

rabi_err_t rabi_pwm_set_enabled(rabi_pwm_t *pwm, bool enabled)
{
    if (pwm == NULL || !pwm->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (enabled)
    {
        /* 重新应用可撤销“关闭时强制低电平”，并恢复 0/100% 的正确强制状态。 */
        apply_waveform(pwm);
        DL_Timer_setTimerCount(pwm->cfg.instance, pwm->period_counts - 1U);
        DL_Timer_startCounter(pwm->cfg.instance);
    }
    else
    {
        DL_Timer_stopCounter(pwm->cfg.instance);
        force_output_low(pwm);
    }

    pwm->enabled = enabled;
    return RABI_ERR_OK;
}

rabi_err_t rabi_pwm_set_frequency(
    rabi_pwm_t *pwm, uint32_t frequency_hz)
{
    if (pwm == NULL || !pwm->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    uint32_t period_counts;
    rabi_err_t err = calculate_period_counts(
        pwm, frequency_hz, &period_counts);
    if (err != RABI_ERR_OK) return err;

    /*
     * 直接在计数过程中写 CTR 会产生不可预测行为。这里先停表，再把 LOAD 和当前
     * CTR 都改成新周期的起点；如果原来已启用，最后从完整新周期重新启动。
     */
    bool restart = pwm->enabled;
    DL_Timer_stopCounter(pwm->cfg.instance);
    DL_Timer_setLoadValue(pwm->cfg.instance, period_counts - 1U);
    DL_Timer_setTimerCount(pwm->cfg.instance, period_counts - 1U);

    pwm->period_counts = period_counts;
    pwm->frequency_hz = frequency_hz;
    apply_waveform(pwm);

    if (restart)
    {
        DL_Timer_startCounter(pwm->cfg.instance);
    }
    else
    {
        /* apply_waveform() 可能为中间占空比撤销强制输出；关闭状态必须仍保持低。 */
        force_output_low(pwm);
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_pwm_set_duty_permille(
    rabi_pwm_t *pwm, uint16_t duty_permille)
{
    if (pwm == NULL || !pwm->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (duty_permille > RABI_PWM_MAX_DUTY_PERMILLE)
    {
        return RABI_ERR_INVALID_ARG;
    }

    pwm->duty_permille = duty_permille;
    apply_waveform(pwm);
    if (!pwm->enabled) force_output_low(pwm);
    return RABI_ERR_OK;
}

rabi_err_t rabi_pwm_set_duty_percent(
    rabi_pwm_t *pwm, uint8_t duty_percent)
{
    if (duty_percent > 100U) return RABI_ERR_INVALID_ARG;
    return rabi_pwm_set_duty_permille(
        pwm, (uint16_t)duty_percent * 10U);
}

uint32_t rabi_pwm_get_frequency(const rabi_pwm_t *pwm)
{
    return pwm != NULL && pwm->initialized ? pwm->frequency_hz : 0;
}

uint16_t rabi_pwm_get_duty_permille(const rabi_pwm_t *pwm)
{
    return pwm != NULL && pwm->initialized ? pwm->duty_permille : 0;
}

bool rabi_pwm_is_enabled(const rabi_pwm_t *pwm)
{
    return pwm != NULL && pwm->initialized && pwm->enabled;
}

static rabi_err_t calculate_period_counts(
    const rabi_pwm_t *pwm,
    uint32_t frequency_hz,
    uint32_t *period_counts)
{
    if (frequency_hz == 0 || period_counts == NULL)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /* 四舍五入：period = round(timer_clock / requested_frequency)。 */
    uint64_t rounded = ((uint64_t)pwm->cfg.timer_clock_hz +
        frequency_hz / 2U) / frequency_hz;
    if (rounded < 2U || rounded > pwm->cfg.max_period_counts ||
        rounded > UINT32_MAX)
    {
        return RABI_ERR_INVALID_ARG;
    }

    *period_counts = (uint32_t)rounded;
    return RABI_ERR_OK;
}

static void apply_waveform(rabi_pwm_t *pwm)
{
    uint32_t period = pwm->period_counts;
    uint16_t duty = pwm->duty_permille;

    /*
     * Edge-Aligned DOWN 模式由 SysConfig 设置为 LOAD 时拉高、向下比较时拉低，
     * 因此 compare = period - high_counts。使用 64 bit 避免 period*duty 溢出。
     */
    uint64_t scaled = (uint64_t)period * duty +
        RABI_PWM_MAX_DUTY_PERMILLE / 2U;
    uint32_t high_counts = (uint32_t)(
        scaled / RABI_PWM_MAX_DUTY_PERMILLE);

    if (duty == 0)
    {
        DL_Timer_setCaptureCompareValue(
            pwm->cfg.instance, period - 1U, pwm->cfg.cc_index);
        force_output_low(pwm);
        return;
    }
    if (duty == RABI_PWM_MAX_DUTY_PERMILLE)
    {
        DL_Timer_setCaptureCompareValue(
            pwm->cfg.instance, 0, pwm->cfg.cc_index);
        DL_Timer_overrideCCPOut(pwm->cfg.instance,
            DL_TIMER_FORCE_OUT_HIGH,
            DL_TIMER_FORCE_CMPL_OUT_DISABLED,
            pwm->cfg.cc_index);
        return;
    }

    /* 很短周期下四舍五入可能得到 0 或 period；夹紧到硬件可表示的 1 个计数。 */
    if (high_counts == 0) high_counts = 1U;
    if (high_counts >= period) high_counts = period - 1U;

    DL_Timer_setCaptureCompareValue(pwm->cfg.instance,
        period - high_counts, pwm->cfg.cc_index);
    DL_Timer_overrideCCPOut(pwm->cfg.instance,
        DL_TIMER_FORCE_OUT_DISABLED,
        DL_TIMER_FORCE_CMPL_OUT_DISABLED,
        pwm->cfg.cc_index);
}

static void force_output_low(rabi_pwm_t *pwm)
{
    DL_Timer_overrideCCPOut(pwm->cfg.instance,
        DL_TIMER_FORCE_OUT_LOW,
        DL_TIMER_FORCE_CMPL_OUT_DISABLED,
        pwm->cfg.cc_index);
}
