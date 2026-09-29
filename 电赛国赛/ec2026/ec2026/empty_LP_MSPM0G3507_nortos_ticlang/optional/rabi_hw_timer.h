/* Rabi 备用模块：MSPM0 周期/单次硬件定时器接口。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_timera.h>
#include <ti/driverlib/dl_timerg.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 硬件周期/单次定时器
 * ===================
 *
 * rabi_tick 适合毫秒级 UI、按键扫描和普通状态机；本模块使用一个独立 TIMA/TIMG，
 * 更适合固定控制周期、精确超时、信号建立等待和比赛现场的测试脉冲。它只在中断中
 * 增加 pending_expirations，不直接调用用户回调。主循环取到次数后再做实际工作。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 Timer，Timer Mode 选择 Periodic 或 One Shot；
 * 2. 使用 Down Counting；本轻量层不接管 Up/Up-Down 模式；
 * 3. Timer Start 关闭，由 rabi_hw_timer_start() 启动；
 * 4. 打开 ZERO event interrupt；不需要打开 CC0 等其他 Timer 中断；
 * 5. 根据量程选择时钟和 Prescaler。生成的 ti_msp_dl_config.c 会写出：
 *
 *        timerClkFreq = 1000000 Hz
 *
 *    把这个“分频后的实际计数时钟”填入 timer_clock_hz，而不是直接填 CPUCLK；
 * 6. 16-bit Timer 的 max_period_counts 通常填 65536，32-bit 实例按数据手册填写。
 *    SysConfig 中先随便给一个合法 Period 即可，本模块初始化时会重写 LOAD。
 *
 * 周期示例：1 ms 控制节拍
 * -----------------------
 *
 *     static rabi_hw_timer_t s_control_timer;
 *     static const rabi_hw_timer_cfg_t s_control_timer_cfg = {
 *         .instance = TIMER_CONTROL_INST,
 *         .timer_clock_hz = 1000000U,
 *         .max_period_counts = 65536U,
 *         .period_us = 1000U,
 *         .mode = RABI_HW_TIMER_MODE_PERIODIC,
 *         .start_on_init = false,
 *     };
 *
 *     // SYSCFG_DL_init() 之后：
 *     rabi_hw_timer_init(&s_control_timer, &s_control_timer_cfg);
 *     NVIC_EnableIRQ(TIMER_CONTROL_INST_INT_IRQN);
 *     rabi_hw_timer_start(&s_control_timer);
 *
 *     void TIMER_CONTROL_INST_IRQHandler(void)
 *     {
 *         (void)rabi_hw_timer_irq_handler_from_isr(&s_control_timer);
 *     }
 *
 *     // 主循环：如果暂时被 OLED 刷新挡住，expirations 可能大于 1。
 *     uint32_t expirations = rabi_hw_timer_take_expirations(&s_control_timer);
 *     while (expirations-- != 0U) {
 *         control_step();
 *     }
 *
 * 若控制算法不允许“补跑很多次”，可在主循环把非零次数合并成一次，同时记录
 * overrun；真正对相位和采样抖动敏感的 ADC 应用，应让 Timer 通过 Event Fabric
 * 直接触发 ADC，再由 DMA 搬运，不应依赖 CPU 进入 ISR 后才手工启动 ADC。
 *
 * One Shot 示例：非阻塞超时
 * -------------------------
 * SysConfig 选择 One Shot，cfg.mode 也选择 ONE_SHOT。发送命令后调用 start()，中断
 * 到来后主循环看到 expiration 就进入超时分支；收到正常响应时调用 stop()。再次
 * start() 会从完整新周期开始，适合继电器等待、模拟链路稳定时间和通信超时。
 *
 * 使用边界
 * --------
 * - IRQ handler 名称和 IRQn 宏由 SysConfig 生成，本模块不能替你定义中断入口；
 * - irq_handler_from_isr() 会读取 IIDX，应只为该 Timer 启用 ZERO 中断；
 * - pending 计数饱和在 UINT32_MAX，不会回绕成 0；
 * - 不要在 ISR 中刷新 OLED、调用阻塞 I2C/SPI、printf 或 delay；
 * - 本模块不实现忙等 delay。比赛代码优先用状态机和 One Shot 等待外设建立；
 * - 需要 PWM、输入捕获或 ADC 硬件触发时分别使用对应模块/Timer 配置。
 */

typedef enum
{
    RABI_HW_TIMER_MODE_PERIODIC = 0,
    RABI_HW_TIMER_MODE_ONE_SHOT,
} rabi_hw_timer_mode_t;

typedef struct
{
    GPTIMER_Regs *instance;
    uint32_t timer_clock_hz;
    uint32_t max_period_counts;
    uint32_t period_us;
    rabi_hw_timer_mode_t mode;
    bool start_on_init;
} rabi_hw_timer_cfg_t;

typedef struct
{
    rabi_hw_timer_cfg_t cfg;
    uint32_t period_counts;
    volatile uint32_t pending_expirations;
    bool initialized;
} rabi_hw_timer_t;

rabi_err_t rabi_hw_timer_init(
    rabi_hw_timer_t *timer, const rabi_hw_timer_cfg_t *cfg);

/* start() 每次都从完整周期重新开始，并丢弃旧的、尚未取走的 expiration。 */
rabi_err_t rabi_hw_timer_start(rabi_hw_timer_t *timer);

rabi_err_t rabi_hw_timer_stop(rabi_hw_timer_t *timer);

/* 改周期会短暂停表；如果原来正在运行，更新后会从完整新周期重新启动。 */
rabi_err_t rabi_hw_timer_set_period_us(
    rabi_hw_timer_t *timer, uint32_t period_us);

/*
 * 只在该 Timer 的 SysConfig 生成 IRQ handler 中调用。
 * 消费到 ZERO 中断时返回 true，其他 IIDX/参数错误返回 false。
 */
bool rabi_hw_timer_irq_handler_from_isr(rabi_hw_timer_t *timer);

/* 原子地取走并清零累计到期次数。 */
uint32_t rabi_hw_timer_take_expirations(rabi_hw_timer_t *timer);

uint32_t rabi_hw_timer_get_period_counts(const rabi_hw_timer_t *timer);

bool rabi_hw_timer_is_running(const rabi_hw_timer_t *timer);

#if defined(__cplusplus)
}
#endif
