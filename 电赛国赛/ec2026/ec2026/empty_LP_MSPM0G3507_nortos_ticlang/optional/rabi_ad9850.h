/* Rabi 备用模块：AD9850 正弦波输出示例接口。 */
#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "core/rabi_err.h"
#include "rabi_gpio_serial.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * AD9850 简化驱动：只生成固定频率、固定幅值的正弦波
 * =====================================================
 *
 * 本驱动只使用 AD9850 的 40-bit 串行装载模式：
 *
 * - 前 32 bit 是频率调谐字，LSB first；
 * - 后 8 bit 中只使用 Power-Down 位，相位固定为 0；
 * - 40 bit 发送完成后，FQ_UD 上升沿更新输出。
 *
 * 不包含扫频、调相、调幅或任何调制功能。
 *
 * AD9850 本身没有“数字幅值寄存器”。幅值通常由 RSET、输出负载、外部数字
 * 电位器、PGA/VCA 或 DAC 控制。本驱动因此提供一个可选 amplitude_cb：
 *
 * - 没有外部幅值控制硬件时，将 amplitude_cb 设为 NULL，只调用 set_frequency；
 * - 有外部电位器/PGA 时，在 amplitude_cb 内调用对应驱动；
 * - amplitude_permille 的 0~1000 映射由回调自己决定，可以做非线性校准。
 *
 * SysConfig 接入
 * -------------
 * 新建一个 GPIO Pin Group，例如 GPIO_AD9850，并创建四个 Digital Output：
 *
 *     DATA    -> AD9850 模块 DATA（芯片 D7/Serial Load）
 *     W_CLK   -> AD9850 W_CLK
 *     FQ_UD   -> AD9850 FQ_UD
 *     RESET   -> AD9850 RESET
 *
 * 四个输出初始值都设为 Low。AD9850 模块和 LaunchPad 必须共地。常见模块已经
 * 把芯片 D2/D1/D0 固定为 0/1/1，以便进入串行模式；如果使用裸芯片，需要按
 * 数据手册 Figure 11 连接这些引脚。
 *
 * 裸 AD9850 的 IOUT/IOUTB 是电流输出，还需要 RSET、负载和重建低通滤波器。
 * 常见成品模块通常已经包含这些电路。越接近参考时钟一半，镜像和失真越明显，
 * 所以驱动允许到 f_ref/2 不代表硬件在整个范围内都能输出高质量正弦波。
 *
 * 最小使用示例
 * ------------
 *
 *     static rabi_ad9850_t s_dds;
 *
 *     static const rabi_ad9850_cfg_t s_dds_cfg = {
 *         .serial = {
 *             .data = {GPIO_AD9850_PORT, GPIO_AD9850_DATA_PIN},
 *             .clock = {GPIO_AD9850_PORT, GPIO_AD9850_W_CLK_PIN},
 *             .clock_idle_high = false,
 *             .half_period_cycles = CPUCLK_FREQ / 1000000U,
 *         },
 *         .fq_ud = {GPIO_AD9850_PORT, GPIO_AD9850_FQ_UD_PIN},
 *         .reset = {GPIO_AD9850_PORT, GPIO_AD9850_RESET_PIN},
 *         .reference_clock_hz = 125000000U,
 *         .amplitude_cb = NULL,
 *         .amplitude_context = NULL,
 *     };
 *
 *     rabi_ad9850_init(&s_dds, &s_dds_cfg);
 *     rabi_ad9850_set_frequency(&s_dds, 1000000U);  // 1 MHz
 *     rabi_ad9850_set_output_enabled(&s_dds, true);
 *
 * reference_clock_hz 必须填写模块真实参考时钟。不要因为常见模块写着 125 MHz
 * 就盲目固定；需要更高频率精度时，应测量实际时钟并把校准值填入配置。
 *
 * 与现有 rabi 框架接入
 * --------------------
 *
 * - 必须先调用 rabi_system_init()，让 SYSCFG_DL_init() 完成 GPIO 配置，再调用
 *   rabi_ad9850_init()；
 * - 可以直接在 UI 条目的 change callback 中调用 set_frequency()；
 * - 本驱动是阻塞式短事务，适合在主循环/事件回调中调用，不要从 SysTick ISR 调用；
 * - 如果通过 rabi_event_post() 传递频率或幅值，请使用模块级静态 payload，不能
 *   把栈变量地址放进异步事件队列；
 * - 新增另一颗陌生芯片时，保留 rabi_gpio_serial.*，只新建对应的 rabi_xxx.*，
 *   在其中实现“组帧 -> write_bits/write_bytes -> 控制脚更新”即可。
 */

typedef rabi_err_t (*rabi_ad9850_amplitude_cb_t)(
    uint16_t amplitude_permille, void *context);

typedef struct
{
    rabi_gpio_serial_t serial;
    rabi_gpio_serial_pin_t fq_ud;
    rabi_gpio_serial_pin_t reset;
    uint32_t reference_clock_hz;

    rabi_ad9850_amplitude_cb_t amplitude_cb;
    void *amplitude_context;
} rabi_ad9850_cfg_t;

typedef struct
{
    rabi_ad9850_cfg_t cfg;
    uint32_t frequency_hz;
    uint32_t tuning_word;
    uint16_t amplitude_permille;
    bool output_enabled;
    bool initialized;
} rabi_ad9850_t;

rabi_err_t rabi_ad9850_init(
    rabi_ad9850_t *device, const rabi_ad9850_cfg_t *cfg);

/* 重新复位、进入串行模式，并恢复缓存的频率和输出开关状态。 */
rabi_err_t rabi_ad9850_reset(rabi_ad9850_t *device);

/* 简化驱动限制输出频率不超过参考时钟的 1/2。 */
rabi_err_t rabi_ad9850_set_frequency(
    rabi_ad9850_t *device, uint32_t frequency_hz);

rabi_err_t rabi_ad9850_set_output_enabled(
    rabi_ad9850_t *device, bool enabled);

/* 没有配置 amplitude_cb 时返回 RABI_ERR_NOT_SUPPORTED。 */
rabi_err_t rabi_ad9850_set_amplitude_permille(
    rabi_ad9850_t *device, uint16_t amplitude_permille);

uint32_t rabi_ad9850_get_frequency(const rabi_ad9850_t *device);

uint16_t rabi_ad9850_get_amplitude_permille(
    const rabi_ad9850_t *device);

#if defined(__cplusplus)
}
#endif
