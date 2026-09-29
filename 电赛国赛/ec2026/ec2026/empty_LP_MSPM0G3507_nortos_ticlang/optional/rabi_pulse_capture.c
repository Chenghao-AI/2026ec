/* Rabi 备用模块：MSPM0 脉冲频率/占空比输入捕获实现。 */
#include "rabi_pulse_capture.h"

static uint32_t enter_critical(void)
{
    uint32_t primask = __get_PRIMASK();
    __disable_irq();
    return primask;
}

static void exit_critical(uint32_t primask)
{
    __set_PRIMASK(primask);
}

static const uint32_t CAPTURE_INTERRUPT_MASK =
    DL_TIMER_INTERRUPT_CC1_DN_EVENT | DL_TIMER_INTERRUPT_ZERO_EVENT;

rabi_err_t rabi_pulse_capture_init(
    rabi_pulse_capture_t *capture,
    const rabi_pulse_capture_cfg_t *cfg)
{
    if (capture == NULL || cfg == NULL || cfg->instance == NULL ||
        cfg->timer_clock_hz == 0U)
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (!DL_Timer_isPowerEnabled(cfg->instance) ||
        !DL_Timer_isClockEnabled(cfg->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (DL_Timer_getCounterMode(cfg->instance) != DL_TIMER_COUNT_MODE_DOWN)
    {
        return RABI_ERR_NOT_SUPPORTED;
    }

    uint32_t load_value = DL_Timer_getLoadValue(cfg->instance);
    if (load_value == 0U) return RABI_ERR_INVALID_STATE;

    *capture = (rabi_pulse_capture_t){
        .cfg = *cfg,
        .load_value = load_value,
        .period_capture = 0U,
        .high_capture = 0U,
        .synced = false,
        .measurement_ready = false,
        .signal_lost = false,
        .initialized = true,
    };

    DL_Timer_stopCounter(capture->cfg.instance);
    if (cfg->start_on_init)
    {
        return rabi_pulse_capture_start(capture);
    }
    return RABI_ERR_OK;
}

rabi_err_t rabi_pulse_capture_start(rabi_pulse_capture_t *capture)
{
    if (capture == NULL || !capture->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    DL_Timer_stopCounter(capture->cfg.instance);
    DL_Timer_clearInterruptStatus(
        capture->cfg.instance, CAPTURE_INTERRUPT_MASK);

    uint32_t primask = enter_critical();
    capture->period_capture = 0U;
    capture->high_capture = 0U;
    capture->synced = false;
    capture->measurement_ready = false;
    capture->signal_lost = false;
    exit_critical(primask);

    DL_Timer_setTimerCount(capture->cfg.instance, capture->load_value);
    DL_Timer_startCounter(capture->cfg.instance);
    return RABI_ERR_OK;
}

rabi_err_t rabi_pulse_capture_stop(rabi_pulse_capture_t *capture)
{
    if (capture == NULL || !capture->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    DL_Timer_stopCounter(capture->cfg.instance);
    DL_Timer_clearInterruptStatus(
        capture->cfg.instance, CAPTURE_INTERRUPT_MASK);

    uint32_t primask = enter_critical();
    capture->synced = false;
    exit_critical(primask);
    return RABI_ERR_OK;
}

bool rabi_pulse_capture_irq_handler_from_isr(
    rabi_pulse_capture_t *capture)
{
    if (capture == NULL || !capture->initialized) return false;

    DL_TIMER_IIDX pending =
        DL_Timer_getPendingInterrupt(capture->cfg.instance);
    switch (pending)
    {
        case DL_TIMER_IIDX_CC1_DN:
        {
            uint32_t period_capture = DL_Timer_getCaptureCompareValue(
                capture->cfg.instance, DL_TIMER_CC_1_INDEX);
            uint32_t high_capture = DL_Timer_getCaptureCompareValue(
                capture->cfg.instance, DL_TIMER_CC_0_INDEX);

            if (capture->synced)
            {
                /* 先写数据、最后置 ready，主循环通过临界区得到一致快照。 */
                capture->period_capture = period_capture;
                capture->high_capture = high_capture;
                capture->measurement_ready = true;
            }
            else
            {
                /* 第一个周期边界只用于对齐，还不能组成一个完整周期。 */
                capture->synced = true;
            }
            /*
             * MSPM0 TIMER_ERR_01：组合捕获需要在周期边界手动 reload。这不是普通
             * 软件“修正”，而是 TI 官方 capture 示例采用的器件勘误规避方式。
             */
            DL_Timer_setTimerCount(
                capture->cfg.instance, capture->load_value);
            return true;
        }

        case DL_TIMER_IIDX_ZERO:
            capture->synced = false;
            capture->measurement_ready = false;
            capture->signal_lost = true;
            return true;

        default:
            return false;
    }
}

bool rabi_pulse_capture_take(
    rabi_pulse_capture_t *capture,
    rabi_pulse_measurement_t *measurement)
{
    if (capture == NULL || measurement == NULL || !capture->initialized)
    {
        return false;
    }

    uint32_t primask = enter_critical();
    if (!capture->measurement_ready)
    {
        exit_critical(primask);
        return false;
    }
    uint32_t period_capture = capture->period_capture;
    uint32_t high_capture = capture->high_capture;
    capture->measurement_ready = false;
    exit_critical(primask);

    if (period_capture >= capture->load_value ||
        high_capture > capture->load_value)
    {
        return false;
    }

    uint32_t period_ticks = capture->load_value - period_capture;
    uint32_t high_ticks = capture->load_value - high_capture;
    if (period_ticks == 0U || high_ticks > period_ticks)
    {
        return false;
    }

    uint64_t frequency_millihz =
        ((uint64_t)capture->cfg.timer_clock_hz * 1000U +
         period_ticks / 2U) / period_ticks;
    if (frequency_millihz > UINT32_MAX)
    {
        frequency_millihz = UINT32_MAX;
    }

    uint32_t duty_permille =
        (uint32_t)(((uint64_t)high_ticks * 1000U +
                    period_ticks / 2U) / period_ticks);

    *measurement = (rabi_pulse_measurement_t){
        .period_ticks = period_ticks,
        .high_ticks = high_ticks,
        .frequency_millihz = (uint32_t)frequency_millihz,
        .duty_permille = (uint16_t)duty_permille,
    };
    return true;
}

bool rabi_pulse_capture_take_signal_lost(
    rabi_pulse_capture_t *capture)
{
    if (capture == NULL || !capture->initialized) return false;

    uint32_t primask = enter_critical();
    bool signal_lost = capture->signal_lost;
    capture->signal_lost = false;
    exit_critical(primask);
    return signal_lost;
}
