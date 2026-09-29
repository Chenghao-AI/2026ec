/* Rabi 核心模块：事件队列接口。 */
#pragma once

#include <stdint.h>
#include "rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

#define RABI_EVENT_BASE_ANY (0xFFFFFF)
#define RABI_EVENT_ID_ANY (0xFF)

#define RABI_EVENT_DECLARE_BASE(base_name) \
    extern const uint32_t base_name;

#define RABI_EVENT_DEFINE_BASE(base_name)      \
    const uint8_t _rabi_event_##base_name = 0; \
    const uint32_t base_name = (uintptr_t)(&_rabi_event_##base_name);

typedef uint32_t rabi_event_base_t;
typedef uint32_t rabi_event_id_t;

typedef void (*rabi_event_cb_t)(rabi_event_base_t base, rabi_event_id_t id, void *param);

/*
 * rabi_event_post() 的实现使用临界区，可从 ISR 调用；队列满时会返回
 * RABI_ERR_NO_RESOURCES。队列只保存 param 指针，不复制它指向的数据，所以禁止从
 * ISR 投递栈上局部变量地址。param 应为 NULL、静态对象，或在事件消费前始终有效
 * 的缓冲区。监听回调由主循环调用 rabi_event_loop() 时执行，不在 ISR 中执行。
 */

void rabi_event_init(void);

void rabi_event_loop(void);

rabi_err_t rabi_event_listen(rabi_event_base_t base, rabi_event_id_t id, rabi_event_cb_t cb);

rabi_err_t rabi_event_post(rabi_event_base_t base, rabi_event_id_t id, void *param);

#if defined(__cplusplus)
}
#endif
