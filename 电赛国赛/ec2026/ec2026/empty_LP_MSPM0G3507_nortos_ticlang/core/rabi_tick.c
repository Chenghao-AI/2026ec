/* Rabi 核心模块：软件定时器实现。 */
#include <stddef.h>
#include "rabi_tick.h"
#include "ti_msp_dl_config.h"

#define MAX_TIMER 4

typedef struct
{
    rabi_tick_cb_t cb;
    uint16_t period;
    uint16_t counter;
} timer_t;

static volatile timer_t s_timers[MAX_TIMER];

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

void rabi_tick_init(void)
{
    for (uint8_t i = 0; i < MAX_TIMER; i++)
    {
        s_timers[i].cb = NULL;
        s_timers[i].period = 0;
        s_timers[i].counter = 0;
    }

    DL_SYSTICK_init(CPUCLK_FREQ / 1000U);
    DL_SYSTICK_enableInterrupt();
    DL_SYSTICK_enable();
}

rabi_err_t rabi_tick_register(rabi_tick_cb_t cb, uint16_t period_ms)
{
    if (cb == NULL || period_ms == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint32_t primask = enter_critical();

    for (uint8_t i = 0; i < MAX_TIMER; i++)
    {
        if (s_timers[i].cb != cb) continue;

        s_timers[i].counter = 0;
        s_timers[i].period = period_ms;
        exit_critical(primask);
        return RABI_ERR_OK;
    }

    for (uint8_t i = 0; i < MAX_TIMER; i++)
    {
        if (s_timers[i].cb != NULL) continue;

        s_timers[i].counter = 0;
        s_timers[i].period = period_ms;
        s_timers[i].cb = cb;
        exit_critical(primask);
        return RABI_ERR_OK;
    }

    exit_critical(primask);
    return RABI_ERR_NO_RESOURCES;
}

rabi_err_t rabi_tick_unregister(rabi_tick_cb_t cb)
{
    if (cb == NULL)
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint32_t primask = enter_critical();

    for (uint8_t i = 0; i < MAX_TIMER; i++)
    {
        if (s_timers[i].cb != cb) continue;

        s_timers[i].cb = NULL;
        s_timers[i].period = 0;
        s_timers[i].counter = 0;
        exit_critical(primask);
        return RABI_ERR_OK;
    }

    exit_critical(primask);
    return RABI_ERR_NOT_FOUND;
}

void SysTick_Handler(void)
{
    for (uint8_t i = 0; i < MAX_TIMER; i++)
    {
        rabi_tick_cb_t cb = s_timers[i].cb;
        if (cb == NULL) continue;

        s_timers[i].counter++;
        if (s_timers[i].counter >= s_timers[i].period)
        {
            s_timers[i].counter = 0;
            cb();
        }
    }
}
