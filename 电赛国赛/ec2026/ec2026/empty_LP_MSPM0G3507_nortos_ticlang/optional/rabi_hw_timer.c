/* Rabi 备用模块：MSPM0 周期/单次硬件定时器实现。 */
#include "rabi_hw_timer.h"

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

static rabi_err_t calculate_period_counts(
    const rabi_hw_timer_t *timer,
    uint32_t period_us,
    uint32_t *period_counts)
{
    if (period_us == 0U || period_counts == NULL)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /* round(timer_clock_hz * period_us / 1,000,000)，64 bit 防止乘法溢出。 */
    uint64_t scaled = (uint64_t)timer->cfg.timer_clock_hz * period_us;
    uint64_t rounded = (scaled + 500000U) / 1000000U;
    if (rounded == 0U || rounded > timer->cfg.max_period_counts ||
        rounded > UINT32_MAX)
    {
        return RABI_ERR_INVALID_ARG;
    }

    *period_counts = (uint32_t)rounded;
    return RABI_ERR_OK;
}

rabi_err_t rabi_hw_timer_init(
    rabi_hw_timer_t *timer, const rabi_hw_timer_cfg_t *cfg)
{
    if (timer == NULL || cfg == NULL || cfg->instance == NULL ||
        cfg->timer_clock_hz == 0U || cfg->max_period_counts == 0U ||
        cfg->period_us == 0U ||
        (cfg->mode != RABI_HW_TIMER_MODE_PERIODIC &&
         cfg->mode != RABI_HW_TIMER_MODE_ONE_SHOT))
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

    DL_TIMER_REPEAT_MODE repeat =
        DL_Timer_getCounterRepeatMode(cfg->instance);
    if ((cfg->mode == RABI_HW_TIMER_MODE_ONE_SHOT &&
         repeat != DL_TIMER_REPEAT_MODE_DISABLED) ||
        (cfg->mode == RABI_HW_TIMER_MODE_PERIODIC &&
         repeat == DL_TIMER_REPEAT_MODE_DISABLED))
    {
        /* cfg.mode 必须和 SysConfig 的 One Shot / Periodic 一致。 */
        return RABI_ERR_INVALID_STATE;
    }

    *timer = (rabi_hw_timer_t){
        .cfg = *cfg,
        .period_counts = 0U,
        .pending_expirations = 0U,
        .initialized = true,
    };

    DL_Timer_stopCounter(timer->cfg.instance);
    rabi_err_t err = rabi_hw_timer_set_period_us(timer, cfg->period_us);
    if (err != RABI_ERR_OK)
    {
        timer->initialized = false;
        return err;
    }

    if (cfg->start_on_init)
    {
        return rabi_hw_timer_start(timer);
    }
    return RABI_ERR_OK;
}

rabi_err_t rabi_hw_timer_start(rabi_hw_timer_t *timer)
{
    if (timer == NULL || !timer->initialized || timer->period_counts == 0U)
    {
        return RABI_ERR_INVALID_STATE;
    }

    DL_Timer_stopCounter(timer->cfg.instance);
    DL_Timer_clearInterruptStatus(
        timer->cfg.instance, DL_TIMER_INTERRUPT_ZERO_EVENT);

    uint32_t primask = enter_critical();
    timer->pending_expirations = 0U;
    exit_critical(primask);

    DL_Timer_setTimerCount(
        timer->cfg.instance, timer->period_counts - 1U);
    DL_Timer_startCounter(timer->cfg.instance);
    return RABI_ERR_OK;
}

rabi_err_t rabi_hw_timer_stop(rabi_hw_timer_t *timer)
{
    if (timer == NULL || !timer->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    DL_Timer_stopCounter(timer->cfg.instance);
    DL_Timer_clearInterruptStatus(
        timer->cfg.instance, DL_TIMER_INTERRUPT_ZERO_EVENT);
    return RABI_ERR_OK;
}

rabi_err_t rabi_hw_timer_set_period_us(
    rabi_hw_timer_t *timer, uint32_t period_us)
{
    if (timer == NULL || !timer->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    uint32_t period_counts;
    rabi_err_t err = calculate_period_counts(
        timer, period_us, &period_counts);
    if (err != RABI_ERR_OK) return err;

    bool restart = DL_Timer_isRunning(timer->cfg.instance);
    DL_Timer_stopCounter(timer->cfg.instance);
    DL_Timer_setLoadValue(timer->cfg.instance, period_counts - 1U);
    DL_Timer_setTimerCount(timer->cfg.instance, period_counts - 1U);
    DL_Timer_clearInterruptStatus(
        timer->cfg.instance, DL_TIMER_INTERRUPT_ZERO_EVENT);

    timer->cfg.period_us = period_us;
    timer->period_counts = period_counts;

    if (restart) DL_Timer_startCounter(timer->cfg.instance);
    return RABI_ERR_OK;
}

bool rabi_hw_timer_irq_handler_from_isr(rabi_hw_timer_t *timer)
{
    if (timer == NULL || !timer->initialized) return false;

    if (DL_Timer_getPendingInterrupt(timer->cfg.instance) !=
        DL_TIMER_IIDX_ZERO)
    {
        return false;
    }

    if (timer->pending_expirations != UINT32_MAX)
    {
        timer->pending_expirations++;
    }
    return true;
}

uint32_t rabi_hw_timer_take_expirations(rabi_hw_timer_t *timer)
{
    if (timer == NULL || !timer->initialized) return 0U;

    uint32_t primask = enter_critical();
    uint32_t pending = timer->pending_expirations;
    timer->pending_expirations = 0U;
    exit_critical(primask);
    return pending;
}

uint32_t rabi_hw_timer_get_period_counts(const rabi_hw_timer_t *timer)
{
    return timer != NULL && timer->initialized ? timer->period_counts : 0U;
}

bool rabi_hw_timer_is_running(const rabi_hw_timer_t *timer)
{
    return timer != NULL && timer->initialized &&
        DL_Timer_isRunning(timer->cfg.instance);
}
