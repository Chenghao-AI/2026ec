/* Rabi 核心模块：OLED 驱动接口。 */
#pragma once

#include "rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

void rabi_oled_init(void);

void rabi_oled_clear(void);

rabi_err_t rabi_oled_print(uint8_t row, const char *text);

rabi_err_t rabi_oled_set_focus(uint8_t row, uint8_t index);

void rabi_oled_clear_focus(void);

#if defined(__cplusplus)
}
#endif
