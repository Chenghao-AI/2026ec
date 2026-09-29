/* Rabi 备用模块：MSPM0 ADC12 多 Memory 扫描轮询接口。 */
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
 * ADC Scan：一次触发顺序采多个通道
 * =================================
 *
 * SysConfig 把不同模拟输入配置到连续的 ADC Memory，例如 MEM0~MEM3。本模块发出
 * 一次软件触发，等待最后一个 MEM 的 Result Loaded 标志，然后按 MEM 顺序读回：
 *
 *     results[0] <- MEM(start_index)
 *     results[1] <- MEM(start_index + 1)
 *     ...
 *
 * 它适合一次性读取电压、电流、温度、电位器等一组慢变量。这里的“扫描”是一触发
 * 一整组，不是后台无限循环；要固定采样率时应使用 Timer Event + Repeat Sequence，
 * 数据量较大时再接 DMA。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 ADC12，Conversion Mode 选择 Sequence Conversion；
 * 2. Trigger Source 选择 Software，Repeat Mode 关闭；
 * 3. 设置 Sequence Start/End，并为范围内每个 MEM 选择模拟通道；
 * 4. 每个 MEM 的 Trigger Mode 通常选 Auto Next，让序列自动推进；
 * 5. 根据最慢/最高阻的信号选择采样时间；各通道切换后都要让采样电容充分稳定；
 * 6. 本轮询版本不需要启用 ADC 中断或 NVIC。
 *
 * 最小示例
 * --------
 *
 *     static const rabi_adc_scan_t s_scan = {
 *         .instance = ADC_SCAN_INST,
 *         .start_index = DL_ADC12_MEM_IDX_0,
 *         .channel_count = 4,
 *         .poll_limit = 100000U,
 *     };
 *
 *     uint16_t values[4];
 *     rabi_adc_scan_init(&s_scan);
 *     rabi_adc_scan_read(&s_scan, values, 4);
 *
 * 陷阱
 * ----
 * - results 顺序是 MEM 顺序，不是物理 ADC Channel 编号顺序；
 * - 同一个序列里的采样并非真正同时发生。通道间相位差约等于前面通道的采样与
 *   转换时间；需要真正同步采样时要使用多个 ADC、同步事件或外部采样保持；
 * - 前一通道源阻抗很高且电压差很大时，MUX 切换残留会影响下一通道，可增加
 *   Sample Time、降低源阻抗，必要时加入一次丢弃采样；
 * - 扫描结果仍是原码，分压、参考、增益与单位换算应放在具体业务驱动。
 */

typedef struct
{
    ADC12_Regs *instance;
    DL_ADC12_MEM_IDX start_index;
    uint8_t channel_count;
    uint32_t poll_limit;
} rabi_adc_scan_t;

/* 检查 ADC 是否为 Software Trigger 的非重复 Sequence 模式。 */
rabi_err_t rabi_adc_scan_init(const rabi_adc_scan_t *adc);

/* result_capacity 以 uint16_t 元素计，必须不小于 channel_count。 */
rabi_err_t rabi_adc_scan_read(
    const rabi_adc_scan_t *adc,
    uint16_t *results,
    size_t result_capacity);

#if defined(__cplusplus)
}
#endif
