/* Rabi 备用模块：MSPM0 脉冲频率/占空比输入捕获接口。 */
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
 * 脉冲频率和高电平宽度测量
 * ========================
 *
 * 这是模拟类竞赛中很实用的一块预制菜：测信号源/PWM 输出频率和占空比、外部模块
 * 时钟、比较器整形后的过零脉冲、转速/频率传感器等。Timer Capture 在硬件边沿处
 * 锁存计数值，精度和抗抖动能力都优于 GPIO ISR 中读取软件毫秒时间戳。
 *
 * 本实现与 TI SDK 的“Capture Duty and Period”组合模式一致：
 *
 * - 向下计数；
 * - CC1 保存相邻周期边界，CC0 保存高电平结束边沿；
 * - CC1_DN 表示得到一个新周期，ZERO 表示在量程内没有等到下一周期；
 * - ISR 只复制捕获值，主循环再计算频率和占空比；
 * - 包含 MSPM0 TIMER_ERR_01 所需的手动计数器 reload。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 Timer Capture，选择 Combined Capture；
 * 2. Capture Mode 选择 Pulse Width and Period，Down Counting；
 * 3. 选择一个 Capture 输入引脚，普通高有效输入不要反相；
 * 4. Timer Start 关闭；开启 CC1 Down 和 ZERO interrupt；
 * 5. 记下生成文件中的 timerClkFreq，填入 timer_clock_hz；
 * 6. LOAD 决定最低可测频率/无信号超时：
 *
 *        timeout_seconds ~= (LOAD + 1) / timer_clock_hz
 *
 *    例如 1 MHz、LOAD=65535，约 65.5 ms 没有下一边沿就报告 signal_lost，因而
 *    最低只能可靠测十几 Hz。若要测 1 Hz，应进一步分频或使用 32-bit Timer；
 * 7. 用方波/PWM 直接连接 Capture 输入，并确保幅值在 MCU 数字输入允许范围内。
 *    正弦波必须先经比较器/施密特整形成数字信号，不能把负电压直接接入 GPIO。
 *
 * 最小接入示例
 * ------------
 *
 *     static rabi_pulse_capture_t s_capture;
 *     static const rabi_pulse_capture_cfg_t s_capture_cfg = {
 *         .instance = CAPTURE_SIGNAL_INST,
 *         .timer_clock_hz = 1000000U,
 *         .start_on_init = false,
 *     };
 *
 *     // SYSCFG_DL_init() 之后
 *     rabi_pulse_capture_init(&s_capture, &s_capture_cfg);
 *     NVIC_EnableIRQ(CAPTURE_SIGNAL_INST_INT_IRQN);
 *     rabi_pulse_capture_start(&s_capture);
 *
 *     void CAPTURE_SIGNAL_INST_IRQHandler(void)
 *     {
 *         (void)rabi_pulse_capture_irq_handler_from_isr(&s_capture);
 *     }
 *
 *     rabi_pulse_measurement_t m;
 *     if (rabi_pulse_capture_take(&s_capture, &m)) {
 *         // frequency_millihz / 1000 是 Hz；duty_permille / 10 是百分数。
 *         // 在这里更新 OLED 或交给业务层，绝不能在上面的 ISR 中刷新屏幕。
 *     }
 *     if (rabi_pulse_capture_take_signal_lost(&s_capture)) {
 *         // 可显示 “NO SIG” 或触发输入断线保护。
 *     }
 *
 * 精度与量程
 * ----------
 * timer_clock_hz 越高，时间分辨率越好，但同一位宽下可测的最低频率越高。若输入
 * 边沿很慢或有噪声，先用比较器和少量迟滞获得干净数字边沿；软件平均可以让显示
 * 更稳，却不能修复模拟前端反复过零造成的伪边沿。
 *
 * take() 返回主循环来得及读到的“最新完整周期”。主循环很慢时中间周期会被覆盖，
 * 这对仪表显示通常正合适；若题目要求记录每个周期或做抖动统计，应改成 capture
 * DMA/环形缓冲，而不是把 ISR 写得越来越重。
 */

typedef struct
{
    uint32_t period_ticks;
    uint32_t high_ticks;

    /* 使用 mHz 保留低频小数：1000000 表示 1000.000 Hz。 */
    uint32_t frequency_millihz;

    /* 0~1000：500 表示 50.0%。 */
    uint16_t duty_permille;
} rabi_pulse_measurement_t;

typedef struct
{
    GPTIMER_Regs *instance;
    uint32_t timer_clock_hz;
    bool start_on_init;
} rabi_pulse_capture_cfg_t;

typedef struct
{
    rabi_pulse_capture_cfg_t cfg;
    uint32_t load_value;
    volatile uint32_t period_capture;
    volatile uint32_t high_capture;
    volatile bool synced;
    volatile bool measurement_ready;
    volatile bool signal_lost;
    bool initialized;
} rabi_pulse_capture_t;

rabi_err_t rabi_pulse_capture_init(
    rabi_pulse_capture_t *capture,
    const rabi_pulse_capture_cfg_t *cfg);

rabi_err_t rabi_pulse_capture_start(rabi_pulse_capture_t *capture);

rabi_err_t rabi_pulse_capture_stop(rabi_pulse_capture_t *capture);

/* 只在该 Capture 实例的 SysConfig 生成 IRQ handler 中调用。 */
bool rabi_pulse_capture_irq_handler_from_isr(
    rabi_pulse_capture_t *capture);

/* 取走最新完整测量；没有新周期或捕获值无效时返回 false。 */
bool rabi_pulse_capture_take(
    rabi_pulse_capture_t *capture,
    rabi_pulse_measurement_t *measurement);

/* 取走并清除“计数器到零、输入信号超时”标志。 */
bool rabi_pulse_capture_take_signal_lost(
    rabi_pulse_capture_t *capture);

#if defined(__cplusplus)
}
#endif
