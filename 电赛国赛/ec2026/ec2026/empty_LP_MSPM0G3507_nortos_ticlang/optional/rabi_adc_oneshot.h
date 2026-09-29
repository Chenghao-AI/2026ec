/* Rabi 备用模块：MSPM0 ADC12 One Shot 轮询读取接口。 */
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_adc12.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * ADC One Shot：一次调用只采一个通道
 * ==================================
 *
 * 适合电位器、母线电压、慢速电流、NTC 等“需要时读一次”的信号。每次 read()：
 *
 *     清结果标志 -> 允许转换 -> 软件触发 -> 轮询完成 -> 读取 MEMRES
 *
 * 本模块不负责把 ADC 原码换算成电压。最常见的无符号近似公式是：
 *
 *     voltage_mv = raw * reference_mv / (2^resolution - 1)
 *
 * 但真实项目还应考虑分压比、放大器增益/偏置、VDDA 实际值和校准误差。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 ADC12，Conversion Mode 选 Single Conversion；
 * 2. Trigger Source 选 Software，Repeat Mode 关闭；
 * 3. 添加一个 ADC Memory，选择模拟输入、参考源、分辨率和采样时间；
 * 4. 高阻信号源需要更长 Sample Time，不能只看 ADC 最大采样率；
 * 5. 本轮询版本不需要启用 ADC Interrupt 或 NVIC；
 * 6. 若使用内部 VREF/温度传感器，还要在 SysConfig 配置 VREF，并等待参考稳定。
 *
 * 最小示例
 * --------
 *
 *     static const rabi_adc_oneshot_t s_voltage_adc = {
 *         .instance = ADC_VOLTAGE_INST,
 *         .mem_index = DL_ADC12_MEM_IDX_0,
 *         .poll_limit = 100000U,
 *     };
 *
 *     uint16_t raw;
 *     rabi_system_init();
 *     rabi_adc_oneshot_init(&s_voltage_adc);
 *     rabi_adc_oneshot_read(&s_voltage_adc, &raw);
 *
 * 面对陌生模拟信号
 * ----------------
 * 先确认 MCU 引脚允许的电压范围。MSPM0 ADC 引脚绝不能因为“有分压”就默认安全：
 * 必须按输入最大值计算分压，考虑电阻误差和过冲；负电压、双极性信号或高压电源
 * 采样通常还需要运放、钳位和 RC。然后确认参考电压、目标带宽和源阻抗，再决定
 * Sample Time、平均次数和 RC 截止频率。
 *
 * 使用边界
 * --------
 * - 同步阻塞，适合主循环/事件回调；不要在 SysTick ISR 调用；
 * - poll_limit 是轮询次数，不是精确微秒；
 * - mem_index 必须对应 SysConfig 中本次 Single Conversion 使用的 Memory；
 * - 配成 Signed Data Format 时仍返回 uint16_t 原始位型，调用者可转成 int16_t；
 * - 连续波形、固定采样率或多通道同步采集应使用扫描、Timer 触发和 DMA。
 */

typedef struct
{
    ADC12_Regs *instance;
    DL_ADC12_MEM_IDX mem_index;
    uint32_t poll_limit;
} rabi_adc_oneshot_t;

/* 检查 ADC 是否已上电，并确认是 Software Trigger 的 Single 模式。 */
rabi_err_t rabi_adc_oneshot_init(const rabi_adc_oneshot_t *adc);

rabi_err_t rabi_adc_oneshot_read(
    const rabi_adc_oneshot_t *adc, uint16_t *result);

#if defined(__cplusplus)
}
#endif
