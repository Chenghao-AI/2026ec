/* Rabi 备用模块：把中断中的工作延后到主循环处理。 */
#pragma once

#include <stddef.h>
#include <stdint.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 中断延后处理：ISR 只记账，主循环做重活
 * =========================================
 *
 * 比赛现场很常见的“偶发死机”并不一定是硬件问题，而是 ISR 中做了阻塞操作：
 * OLED 刷屏、I2C/SPI 轮询、printf、delay、浮点计算，甚至等待另一个中断完成。
 * 这些操作会拉长全局中断延迟，还可能与主循环正在使用的同一外设互相卡住。
 *
 * 本模块是一个最小的 32-bit 延后标志箱：
 *
 *     ISR:      rabi_irq_defer_post_from_isr(&s_irq, EVENT_ADC_READY);
 *     main:     events = rabi_irq_defer_take(&s_irq);
 *               if (events & EVENT_ADC_READY) { ...读取/显示/计算... }
 *
 * 相同事件在主循环处理前发生多次时只保留一个 bit，称为“合并”。这适合按键边沿、
 * 故障通知、ADC DRDY、比较器翻转和“界面需要刷新”等状态型事件。必须知道精确发生
 * 次数时，不要用 bit；可参考 rabi_hw_timer 的饱和 pending_expirations 计数。
 *
 * GPIO 中断接入示例
 * -----------------
 * SysConfig 中把引脚设成 Digital Input，按外部电路选择 Pull-up/Pull-down 和
 * Rising/Falling/Both Edge，再启用 GPIO interrupt。G3507 的 GPIO 中断入口可能是
 * GROUP1_IRQHandler；最终名称以生成的 ti_msp_dl_config.h 和 TI 示例为准。
 *
 *     enum {
 *         IRQ_EVENT_ZERO_CROSS = 1U << 0,
 *         IRQ_EVENT_ADC_DRDY   = 1U << 1,
 *     };
 *
 *     static rabi_irq_defer_t s_irq;
 *
 *     // 初始化阶段：SYSCFG_DL_init() 之后
 *     rabi_irq_defer_init(&s_irq);
 *     DL_GPIO_clearInterruptStatus(SIGNAL_PORT, SIGNAL_PIN);
 *     NVIC_EnableIRQ(SIGNAL_INT_IRQN); // 使用 SysConfig 生成的 IRQn 宏
 *
 *     void GROUP1_IRQHandler(void)
 *     {
 *         uint32_t status = DL_GPIO_getEnabledInterruptStatus(
 *             SIGNAL_PORT, SIGNAL_PIN);
 *         if ((status & SIGNAL_PIN) != 0U) {
 *             // 先清外设标志，再通知主循环；共享 IRQ 时要逐组检查所有来源。
 *             DL_GPIO_clearInterruptStatus(SIGNAL_PORT, SIGNAL_PIN);
 *             rabi_irq_defer_post_from_isr(
 *                 &s_irq, IRQ_EVENT_ZERO_CROSS);
 *         }
 *     }
 *
 *     int main(void)
 *     {
 *         ...
 *         for (;;) {
 *             uint32_t events = rabi_irq_defer_take(&s_irq);
 *             if ((events & IRQ_EVENT_ZERO_CROSS) != 0U) {
 *                 // 在这里做计算、更新状态或投递 rabi_event。
 *             }
 *             rabi_event_loop();
 *         }
 *     }
 *
 * 面对陌生芯片的中断脚
 * ----------------------
 * 先在数据手册确认该脚是脉冲还是保持电平、有效极性、是否开漏、清除条件和最短脉宽：
 *
 * - 开漏输出通常需要上拉；不要误开内部下拉；
 * - 若信号会一直保持有效，必须先读器件状态寄存器清源，否则 IRQ 会不断重入；
 * - 极窄 DRDY/FAULT 脉冲要确认 GPIO 输入和中断能捕获，必要时使用 Timer Capture；
 * - 机械触点仍需消抖；本模块只解决执行上下文，不代替消抖；
 * - ISR 和主循环共享的多字节结构应通过临界区复制，不能只随手加 volatile。
 *
 * 与 rabi_event 的选择
 * --------------------
 * rabi_event_post() 当前实现可从 ISR 调用，但队列满时会返回
 * RABI_ERR_NO_RESOURCES，且 param 只保存指针。简单硬件通知优先使用本模块；需要
 * base/id 分发时可在 ISR 投递 rabi_event，但 param 应为 NULL、静态对象或其他在
 * 消费前始终有效的内存，绝不能传 ISR 栈上局部变量地址。
 */

typedef struct
{
    volatile uint32_t pending;
} rabi_irq_defer_t;

rabi_err_t rabi_irq_defer_init(rabi_irq_defer_t *defer);

/*
 * 可从 ISR 调用。events 可以一次 OR 多个 bit，但 0 没有意义。
 * 标志已存在时不会重复排队，因此不会产生队列溢出。
 */
void rabi_irq_defer_post_from_isr(
    rabi_irq_defer_t *defer, uint32_t events);

/* 原子地取走当前全部标志并清零；没有事件时返回 0。 */
uint32_t rabi_irq_defer_take(rabi_irq_defer_t *defer);

/* 只查看、不清除；主要用于调试，不应据此实现“查看后再清除”。 */
uint32_t rabi_irq_defer_peek(const rabi_irq_defer_t *defer);

#if defined(__cplusplus)
}
#endif
