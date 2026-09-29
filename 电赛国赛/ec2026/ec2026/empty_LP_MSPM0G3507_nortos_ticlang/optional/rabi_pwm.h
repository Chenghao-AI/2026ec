/* Rabi 备用模块：MSPM0 硬件定时器 PWM 控制接口。 */
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
 * 轻量硬件 PWM 框架
 * =================
 *
 * 本模块管理一个“定时器实例 + 一个 Capture/Compare 通道”，提供初始化、启停、
 * 改频率和改占空比。占空比使用 0~1000 千分比，避免在基础驱动中引入浮点运算：
 *
 *     0    = 0.0%
 *     125  = 12.5%
 *     500  = 50.0%
 *     1000 = 100.0%
 *
 * 0% 和 100% 不能只靠普通比较值可靠表达，因此实现会用
 * DL_Timer_overrideCCPOut() 强制低/高；回到 1~999 时再恢复正常 PWM 动作。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 PWM，选择一个 TIMA/TIMG 实例和 CC 输出引脚；
 * 2. PWM Mode 必须选 Edge-Aligned 向下计数模式；本框架暂不支持中心对齐；
 * 3. 输出使用普通 Active High、不要勾选反相。若题目需要低有效，建议在具体
 *    rabi_xxx 驱动中定义“逻辑占空比”和安全关断电平，避免误开功率器件；
 * 4. Timer Start 建议关闭，由 rabi_pwm_init() 根据 start_on_init 决定；
 * 5. 不需要 PWM 中断；比较值更新可选择 Immediate，普通 UI 调参已经足够；
 * 6. 记下生成的 ti_msp_dl_config.c 中 timerClkFreq 注释。传给本模块的是经过
 *    clockDivider 和 prescale 后的实际计数时钟，不一定等于 CPUCLK_FREQ。
 *
 * 例如生成文件中写着：
 *
 *     timerClkFreq = 1000000 Hz
 *
 * 则配置应填写 .timer_clock_hz = 1000000U。若希望输出 20 kHz，周期计数为
 * 1000000 / 20000 = 50；频率越高，可用于表示占空比的离散台阶就越少。
 *
 * 最小接入示例
 * ------------
 *
 *     static rabi_pwm_t s_pwm;
 *
 *     static const rabi_pwm_cfg_t s_pwm_cfg = {
 *         .instance = PWM_MOTOR_INST,
 *         .cc_index = DL_TIMER_CC_0_INDEX,
 *         .timer_clock_hz = 1000000U,
 *         .max_period_counts = 65536U, // 16-bit Timer；32-bit 按实际能力填写
 *         .frequency_hz = 20000U,
 *         .duty_permille = 0,
 *         .start_on_init = true,
 *     };
 *
 *     rabi_system_init();
 *     rabi_pwm_init(&s_pwm, &s_pwm_cfg);
 *     rabi_pwm_set_duty_permille(&s_pwm, 250); // 25%
 *
 * 面对陌生 PWM 负载
 * ------------------
 * PWM 本身只有频率和占空比，但外部对象的语义不同：舵机常用固定周期内的脉宽，
 * LED 关心平均亮度，直流电机需要驱动器和安全关断，蜂鸣器关心频率，开关电源还
 * 可能要求互补输出和死区。建议具体驱动只调用本层，然后暴露更像业务的 API：
 *
 *     rabi_servo_set_angle();
 *     rabi_buzzer_set_frequency();
 *     rabi_motor_set_output();
 *
 * 功率 MOS、半桥/全桥不能把一个普通 PWM 引脚直接当完整驱动。需要互补 PWM、
 * Dead Band、刹车输入或故障关断时，应单独使用 TIMA 高级功能和门极驱动器；本
 * 轻量层故意不隐藏这些安全相关配置。
 *
 * 多通道注意事项
 * --------------
 * 同一个定时器实例的多个 CC 通道共享 LOAD，所以共享频率。对其中一个 rabi_pwm_t
 * 调用 set_frequency() 会同时改变该定时器上其他通道的周期，却不会自动重算其他
 * 对象的比较值。需要多路独立频率时使用不同定时器；需要同频多通道时，最好由
 * 一个上层模块统一修改所有通道。
 *
 * 使用边界
 * --------
 * - 所有接口同步执行，不依赖事件队列，也不要从 SysTick ISR 调用；
 * - 改频率时会短暂停止计数器、更新 LOAD/CTR/CC 后恢复，适合控制和 UI 调参；
 * - 高频、互补、死区、同步 ADC 触发、故障刹车等场景应直接使用 TimerA 配置；
 * - max_period_counts 必须按所选定时器位宽填写，防止 16-bit LOAD 静默截断；
 * - 本模块不加锁，同一定时器不要被多个执行上下文同时修改。
 */

typedef struct
{
    GPTIMER_Regs *instance;
    DL_TIMER_CC_INDEX cc_index;

    /* 经过 Timer clock divider 和 prescale 后的实际计数频率。 */
    uint32_t timer_clock_hz;

    /* 16-bit Timer 通常填 65536；按具体实例数据手册/SysConfig 能力填写。 */
    uint32_t max_period_counts;

    uint32_t frequency_hz;
    uint16_t duty_permille;
    bool start_on_init;
} rabi_pwm_cfg_t;

typedef struct
{
    rabi_pwm_cfg_t cfg;
    uint32_t period_counts;
    uint32_t frequency_hz;
    uint16_t duty_permille;
    bool enabled;
    bool initialized;
} rabi_pwm_t;

rabi_err_t rabi_pwm_init(
    rabi_pwm_t *pwm, const rabi_pwm_cfg_t *cfg);

rabi_err_t rabi_pwm_set_enabled(rabi_pwm_t *pwm, bool enabled);

rabi_err_t rabi_pwm_set_frequency(
    rabi_pwm_t *pwm, uint32_t frequency_hz);

rabi_err_t rabi_pwm_set_duty_permille(
    rabi_pwm_t *pwm, uint16_t duty_permille);

/* 便捷接口：0~100 整数百分比，内部转换成千分比。 */
rabi_err_t rabi_pwm_set_duty_percent(
    rabi_pwm_t *pwm, uint8_t duty_percent);

uint32_t rabi_pwm_get_frequency(const rabi_pwm_t *pwm);

uint16_t rabi_pwm_get_duty_permille(const rabi_pwm_t *pwm);

bool rabi_pwm_is_enabled(const rabi_pwm_t *pwm);

#if defined(__cplusplus)
}
#endif
