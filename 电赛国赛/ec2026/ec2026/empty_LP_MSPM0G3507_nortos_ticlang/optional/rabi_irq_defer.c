/* Rabi 备用模块：中断延后标志实现。 */
#include "rabi_irq_defer.h"
#include "ti_msp_dl_config.h"

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

rabi_err_t rabi_irq_defer_init(rabi_irq_defer_t *defer)
{
    if (defer == NULL) return RABI_ERR_INVALID_ARG;

    uint32_t primask = enter_critical();
    defer->pending = 0;
    exit_critical(primask);
    return RABI_ERR_OK;
}

void rabi_irq_defer_post_from_isr(
    rabi_irq_defer_t *defer, uint32_t events)
{
    if (defer == NULL || events == 0U) return;

    /*
     * 主循环的 take() 也会改同一个字。短临界区同时防止主循环和嵌套的高优先级
     * ISR 造成 read-modify-write 丢 bit，并保持调用前的 PRIMASK 状态。
     */
    uint32_t primask = enter_critical();
    defer->pending |= events;
    exit_critical(primask);
}

uint32_t rabi_irq_defer_take(rabi_irq_defer_t *defer)
{
    if (defer == NULL) return 0;

    uint32_t primask = enter_critical();
    uint32_t pending = defer->pending;
    defer->pending = 0;
    exit_critical(primask);
    return pending;
}

uint32_t rabi_irq_defer_peek(const rabi_irq_defer_t *defer)
{
    if (defer == NULL) return 0;

    uint32_t primask = enter_critical();
    uint32_t pending = defer->pending;
    exit_critical(primask);
    return pending;
}
