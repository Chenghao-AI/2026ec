/* Rabi 核心模块：系统初始化与主循环辅助实现。 */
#include "rabi_system.h"
#include "rabi_event.h"
#include "rabi_tick.h"
#include "ti_msp_dl_config.h"

void rabi_system_init(void)
{
    SYSCFG_DL_init();
    rabi_event_init();
    rabi_tick_init();
}

void rabi_system_loop(void)
{
    rabi_event_loop();
}
