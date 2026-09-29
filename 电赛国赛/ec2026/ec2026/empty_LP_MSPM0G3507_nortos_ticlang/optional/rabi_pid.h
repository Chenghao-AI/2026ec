/* Rabi 备用模块：固定采样周期的轻量 PID 控制器。 */
#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 轻量位置式 PID
 * ==============
 *
 * 适合比赛现场快速搭建温度、转速、幅值、稳压/稳流或执行器闭环。模块不依赖某个
 * ADC、PWM 或电机驱动：调用者提供 setpoint 和 measurement，本模块返回受限 output。
 *
 * 实现包含几项现场很实用、却容易临时漏掉的保护：
 *
 * - 固定 sample_time_s，KI/KD 的含义不随主循环快慢改变；
 * - output_min/output_max 输出限幅；
 * - integral_min/integral_max 积分限幅；
 * - 饱和方向上的条件积分，减轻 windup；
 * - 对 measurement 做微分，设定值突变时不会产生 derivative kick；
 * - derivative_filter 进行一阶低通，减轻 ADC 噪声被 KD 放大。
 *
 * 参数单位
 * --------
 * 本实现采用连续时间常见写法：
 *
 *     output = KP * error
 *            + integral(KI * error * dt)
 *            - KD * derivative(measurement)
 *
 * 因而 KI 的单位包含“每秒”，KD 包含“秒”，sample_time_s 必须用秒。例如 1 ms
 * 周期要填 0.001f，不是 1.0f。若把网上某个“每次循环直接累加”的离散 PID 参数
 * 原样抄进来，KI/KD 数值通常不会等价；先从 KP 开始，再逐步加 KI、KD。
 *
 * 最小接入示例
 * ------------
 *
 *     static rabi_pid_t s_pid;
 *     static const rabi_pid_cfg_t s_pid_cfg = {
 *         .kp = 1.0f,
 *         .ki = 0.2f,
 *         .kd = 0.01f,
 *         .sample_time_s = 0.001f,       // 1 ms
 *         .output_min = 0.0f,
 *         .output_max = 1000.0f,         // 可直接对应 PWM 千分比
 *         .integral_min = 0.0f,
 *         .integral_max = 1000.0f,
 *         .derivative_filter = 0.2f,     // 1=不滤波，越小越平滑
 *     };
 *
 *     rabi_pid_init(&s_pid, &s_pid_cfg);
 *     rabi_pid_reset(&s_pid, initial_measurement, 0.0f);
 *
 *     // 每个确定的 1 ms 控制节拍，在主循环中执行一次：
 *     float output;
 *     if (rabi_pid_update(&s_pid, setpoint, measurement, &output) ==
 *         RABI_ERR_OK) {
 *         rabi_pwm_set_duty_permille(&s_pwm, (uint16_t)output);
 *     }
 *
 * 与 rabi_hw_timer 配合
 * ---------------------
 * Timer ISR 只累计 expiration，主循环读取 ADC 后调用一次 PID。若一次取到多个
 * expiration，不要拿同一个 measurement 连续补算多次 PID；通常应记录一次 overrun，
 * 用最新测量只算一次。若必须严格等间隔采样，Timer 应通过硬件事件触发 ADC/DMA，
 * 控制计算处理每个真实样本。
 *
 * UI 中修改 KP/KI/KD
 * -------------------
 * 当前菜单的 numeric_value 正好是 float。任意一项确认后，读取三个菜单值，再一次性
 * 调用 rabi_pid_set_gains()：
 *
 *     rabi_ui_get_value(UI_ITEM_KP, &kp);
 *     rabi_ui_get_value(UI_ITEM_KI, &ki);
 *     rabi_ui_get_value(UI_ITEM_KD, &kd);
 *     rabi_pid_set_gains(&s_pid,
 *         kp.numeric_value, ki.numeric_value, kd.numeric_value);
 *
 * 一次性提交可避免某个参数更新时，控制器暂时使用一组半新半旧的参数。若正在闭环，
 * 大幅改参仍可能让输出跳变；现场调试可先停输出/置安全值，改完后 reset 再启用。
 *
 * 调参建议
 * --------
 * 1. 先令 KI=KD=0，从很小 KP 开始，确认反馈极性正确；输出越大 measurement 却
 *    离 setpoint 越远，说明方向/接线错误，不要靠继续加大参数解决；
 * 2. 增加 KP 到响应足够快但尚未明显持续振荡；
 * 3. 缓慢增加 KI 消除静差，饱和后恢复很慢通常是积分过大或限幅不合理；
 * 4. 只有确实需要抑制快速变化时再加 KD。ADC 噪声大时先处理模拟滤波、采样同步
 *    和 derivative_filter，KD 不是越大越稳；
 * 5. 电源/功率题务必另做过压、过流和占空比硬限制。PID 不是安全保护器。
 *
 * 性能边界
 * --------
 * MSPM0G3507 的 Cortex-M0+ 使用软件浮点。本实现更重视可读性和现场快速换单位，适合
 * 常见中低速环；很高采样率、多环并行或严格周期预算时，应测量执行时间，再考虑
 * 定点实现。不要从 ISR 直接调用 update()。
 */

typedef struct
{
    float kp;
    float ki;
    float kd;
    float sample_time_s;
    float output_min;
    float output_max;
    float integral_min;
    float integral_max;

    /* 0 < derivative_filter <= 1；1 表示不过滤，0.1 表示较强平滑。 */
    float derivative_filter;
} rabi_pid_cfg_t;

typedef struct
{
    rabi_pid_cfg_t cfg;
    float integral;
    float previous_measurement;
    float derivative_state;
    float proportional_term;
    float derivative_term;
    float output;
    bool has_previous_measurement;
    bool initialized;
} rabi_pid_t;

rabi_err_t rabi_pid_init(
    rabi_pid_t *pid, const rabi_pid_cfg_t *cfg);

/*
 * 清除微分历史，并把积分项设为 output_bias（经过积分限幅）。measurement 应为当前
 * 实际反馈值，这样下一次 update 不会因旧测量产生微分尖峰。
 */
rabi_err_t rabi_pid_reset(
    rabi_pid_t *pid, float measurement, float output_bias);

/* 运行中改增益不会清积分；需要完全重新开始时随后调用 reset()。 */
rabi_err_t rabi_pid_set_gains(
    rabi_pid_t *pid, float kp, float ki, float kd);

/* 运行中改采样周期；不自动换算已有参数，因为 KI/KD 已按秒定义。 */
rabi_err_t rabi_pid_set_sample_time(
    rabi_pid_t *pid, float sample_time_s);

rabi_err_t rabi_pid_update(
    rabi_pid_t *pid,
    float setpoint,
    float measurement,
    float *output);

float rabi_pid_get_integral(const rabi_pid_t *pid);

float rabi_pid_get_output(const rabi_pid_t *pid);

#if defined(__cplusplus)
}
#endif
