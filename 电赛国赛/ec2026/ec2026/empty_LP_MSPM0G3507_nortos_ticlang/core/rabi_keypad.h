/* Rabi 核心模块：4x4 矩阵键盘接口。 */
#pragma once

#include <stdint.h>
#include "rabi_event.h"

#if defined(__cplusplus)
extern "C"
{
#endif

RABI_EVENT_DECLARE_BASE(RABI_KEYPAD_EVENT);

typedef char rabi_keypad_key_t;

typedef enum
{
    RABI_KEYPAD_EVENT_PRESS,
    RABI_KEYPAD_EVENT_LONG_PRESS,
    RABI_KEYPAD_EVENT_RELEASE,
    RABI_KEYPAD_EVENT_CLICK,
    RABI_KEYPAD_EVENT_HOLD_REPEAT,
} rabi_keypad_event_t;

void rabi_keypad_init(void);

void rabi_keypad_deinit(void);

#if defined(__cplusplus)
}
#endif
