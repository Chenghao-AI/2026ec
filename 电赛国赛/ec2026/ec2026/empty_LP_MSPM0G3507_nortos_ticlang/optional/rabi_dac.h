/* Rabi 备用模块：MSPM0 DAC12 单点模拟输出接口。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_dac12.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * DAC12 单点输出
 * ============
 *
 * 用于产生直流偏置、比较器阈值、可调参考、电源给定值或慢速控制量。支持按 12-bit
 * 原码、毫伏和 0~1000 千分比写输出；不负责连续波形，波表请用 rabi_dac_wave。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 DAC12，Resolution 选 12 bit，Representation 选 Binary；
 * 2. Output 选 Enable，并确认生成的 DAC OUT 引脚没有和 LaunchPad 外设冲突；
 * 3. FIFO Disable、DMA Trigger Disable、Sample Time Generator Disable；
 * 4. Amplifier 一般选 On。关闭后的 Hi-Z/Pulldown 行为要按题目安全需求选择；
 * 5. Reference 可选 VDDA/VSSA 或外部/内部 VREF。若选择内部 VREF，还要添加 VREF
 *    模块并等待其稳定；把实际上下参考毫伏值填到 reference_low/high_mv；
 * 6. SYSCFG_DL_init() 通常已给 DAC 上电并 enable，本模块会按 enable_on_init 统一
 *    最终状态，不修改参考源、引脚和放大器设置。
 *
 * 最小示例
 * --------
 *
 *     static rabi_dac_t s_bias_dac;
 *     static const rabi_dac_cfg_t s_bias_dac_cfg = {
 *         .instance = DAC0,
 *         .reference_low_mv = 0U,
 *         .reference_high_mv = 2500U,
 *         .initial_raw = 0U,
 *         .enable_on_init = true,
 *     };
 *
 *     rabi_dac_init(&s_bias_dac, &s_bias_dac_cfg);
 *     rabi_dac_set_millivolts(&s_bias_dac, 1000U);
 *     rabi_dac_set_permille(&s_bias_dac, 500U); // 参考范围中点
 *
 * 换算与校准
 * ----------
 * 对 Binary 12-bit 配置，理想换算为：
 *
 *     Vout = Vref_low + raw / 4095 * (Vref_high - Vref_low)
 *
 * reference_high_mv 应填“实际参考”，而不是看到 2.5 V 选项就无条件填 2500。VDDA
 * 供电误差会直接变成输出比例误差；高精度题应测量/校准。rabi_dac_calibrate() 调用
 * TI 的阻塞自校准，校准期间输出会暂时三态，只应在初始化安全阶段使用。
 *
 * 模拟边界
 * --------
 * - DAC 输出不是电源和功放。负载过重会产生压降、失真或稳定性问题，需要时后接
 *   运放缓冲，并检查容性负载、输出摆幅和建立时间；
 * - DAC 不能直接产生负电压。双极性输出通常需要运放移位/反相；
 * - 0 和满量程附近受输出缓冲摆幅、失调和参考限制，不能默认精确到电源轨；
 * - set_enabled(false) 后引脚是 Hi-Z 还是下拉由 SysConfig Amplifier 配置决定，
 *   不应把软件 disable 当作功率级唯一安全关断；
 * - 本模块为主循环同步接口，不要从高频 ISR 调用。PID 输出可先限幅，再映射到 DAC。
 */

#define RABI_DAC_MAX_RAW 4095U
#define RABI_DAC_MAX_PERMILLE 1000U

typedef struct
{
    DAC12_Regs *instance;
    uint32_t reference_low_mv;
    uint32_t reference_high_mv;
    uint16_t initial_raw;
    bool enable_on_init;
} rabi_dac_cfg_t;

typedef struct
{
    rabi_dac_cfg_t cfg;
    uint16_t raw;
    bool initialized;
} rabi_dac_t;

rabi_err_t rabi_dac_init(
    rabi_dac_t *dac, const rabi_dac_cfg_t *cfg);

rabi_err_t rabi_dac_set_enabled(rabi_dac_t *dac, bool enabled);

rabi_err_t rabi_dac_set_raw(rabi_dac_t *dac, uint16_t raw);

rabi_err_t rabi_dac_set_millivolts(
    rabi_dac_t *dac, uint32_t millivolts);

rabi_err_t rabi_dac_set_permille(
    rabi_dac_t *dac, uint16_t permille);

uint16_t rabi_dac_get_raw(const rabi_dac_t *dac);

uint32_t rabi_dac_get_millivolts(const rabi_dac_t *dac);

bool rabi_dac_is_enabled(const rabi_dac_t *dac);

/* 阻塞自校准；校准期间输出三态。只在初始化/安全状态调用。 */
rabi_err_t rabi_dac_calibrate(rabi_dac_t *dac);

#if defined(__cplusplus)
}
#endif
