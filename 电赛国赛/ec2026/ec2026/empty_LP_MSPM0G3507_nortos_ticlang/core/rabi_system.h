/* Rabi 核心模块：系统初始化与主循环辅助接口。 */
#pragma once

#if defined(__cplusplus)
extern "C"
{
#endif

void rabi_system_init(void);

void rabi_system_loop(void);

#if defined(__cplusplus)
}
#endif
