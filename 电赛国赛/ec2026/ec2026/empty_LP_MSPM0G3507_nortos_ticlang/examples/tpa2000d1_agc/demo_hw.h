/* TPA2000D1 综合示例：MSPM0 外设适配层。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../../core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/* rabi_system_init()/SYSCFG_DL_init() 之后调用；默认保持功放关断、DAC=0。 */
rabi_err_t demo_hw_init(void);

/* 同步取得一个固定采样率的 ADC/DMA 块。 */
rabi_err_t demo_hw_capture(uint16_t *samples, size_t sample_count);

/* 输出正控制电压；外部反相器把它转换成 VCA810 所需的负 VC。 */
rabi_err_t demo_hw_set_control_mv(uint16_t control_mv);

/* false 必须把 TPA2000D1 SHUTDOWN 拉低；不能只依赖 VCA 衰减。 */
void demo_hw_set_amplifier_enabled(bool enabled);

bool demo_hw_is_ready(void);

#if defined(__cplusplus)
}
#endif

