/* Rabi 核心模块：软件定时器接口。 */
#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

typedef void (*rabi_tick_cb_t)(void);

/*
 * rabi_tick 使用 1 ms SysTick。注册的回调直接在 SysTick_Handler 中执行，因此回调
 * 属于 ISR 上下文：必须短小、不可阻塞，只适合更新计数、置标志或投递事件。不要在
 * 回调里刷新 OLED、轮询 I2C/SPI、printf、delay 或做耗时浮点计算。
 *
 * 需要比毫秒更精确的控制周期、One Shot 超时或输入捕获时，使用 optional 中的
 * rabi_hw_timer / rabi_pulse_capture；它们把实际处理延后到主循环。
 */

void rabi_tick_init(void);

rabi_err_t rabi_tick_register(rabi_tick_cb_t cb, uint16_t period_ms);

rabi_err_t rabi_tick_unregister(rabi_tick_cb_t cb);

#if defined(__cplusplus)
}
#endif
