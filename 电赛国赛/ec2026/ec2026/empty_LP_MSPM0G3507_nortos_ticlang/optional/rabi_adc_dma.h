/* Rabi 备用模块：ADC12 FIFO 到 RAM 的 DMA 采样示例。 */
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_adc12.h>
#include "rabi_dma.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * ADC + DMA 最小采样模板
 * =====================
 *
 * 本模块沿用 TI G3507 官方 adc12_max_freq_dma 的基本路径：ADC 开启 FIFO，把两个
 * 16-bit ADC 样本打包成一个 32-bit FIFODATA，DMA 每次从固定 FIFO 地址读取一个
 * Word，并依次写入 uint16_t 样本数组。
 *
 * SysConfig 配置步骤
 * ------------------
 * 1. 添加 ADC12，配置一个通道或 Sequence；需要连续填满缓冲区时打开 Repeat；
 * 2. Trigger 可先用 Software，固定采样频率则改用 Timer Event；
 * 3. 打开 FIFO 和 Configure DMA；
 * 4. ADC 的 DMA Trigger/Sample Count 按目标吞吐配置；可先照官方
 *    adc12_max_freq_dma 示例的默认值验证，再根据采样率调整；
 * 5. 让 ADC 的 DMA 配置自动创建 DMA Channel，地址模式选择 FIFO-to-buffer；
 * 6. DMA 应为 Single Transfer、Source Unchanged、Destination Increment、
 *    Source/Destination Width Word，Trigger 选择 ADC 实例事件；
 * 7. 本轮询示例不需要打开 DMA NVIC。完成判断读取 DMA 通道原始完成标志。
 *
 * 示例配置
 * --------
 *
 *     static const rabi_adc_dma_t s_capture = {
 *         .adc = ADC_CAPTURE_INST,
 *         .adc_dma_trigger = DL_ADC12_DMA_MEM10_RESULT_LOADED,
 *         .dma = {
 *             .instance = DMA,
 *             .channel = DMA_CAPTURE_CHAN_ID,
 *             .completion_interrupt = DL_DMA_INTERRUPT_CHANNEL0,
 *             .poll_limit = 1000000U,
 *         },
 *     };
 *
 *     static uint16_t s_samples[1024] __attribute__((aligned(4)));
 *
 *     rabi_adc_dma_init(&s_capture);
 *     rabi_adc_dma_capture(&s_capture, s_samples, 1024);
 *
 * 若 ADC 配为重复 Sequence，例如 MEM0、MEM1、MEM2，则 samples 按转换时间顺序
 * 交错排列：CH0, CH1, CH2, CH0, CH1, CH2...。sample_count 最好是通道数的整数倍。
 *
 * 重要限制
 * --------
 * - sample_count 必须为偶数，因为一个 FIFO Word 打包两个 16-bit 样本；
 * - 缓冲区必须 4-byte 对齐，并在 DMA 完成前保持有效；
 * - 本示例开始前会停止转换并重置 FIFO；同一 ADC 不能同时被 One Shot/Scan 使用；
 * - 若 ADC 不是 Repeat 模式，产生的样本数必须足够填满请求的缓冲区，否则超时；
 * - DMA 只保证搬运，不保证固定采样间隔。稳定采样率需要 Timer Event 触发 ADC；
 * - 超高采样率下不要在采集同时刷新 OLED；UI/I2C 阻塞事务会消耗总线和 CPU 时间；
 * - 连续无缝采集建议使用双缓冲/Ping-Pong，中断里只换缓冲区，主循环再处理数据。
 */

typedef struct
{
    ADC12_Regs *adc;

    /* 必须与 SysConfig 的 Enabled DMA Triggers 选择一致。 */
    uint32_t adc_dma_trigger;
    rabi_dma_t dma;
} rabi_adc_dma_t;

rabi_err_t rabi_adc_dma_init(const rabi_adc_dma_t *capture);

/* 同步采满 sample_count 个 16-bit 样本；范围为 2~131070 且必须为偶数。 */
rabi_err_t rabi_adc_dma_capture(
    const rabi_adc_dma_t *capture,
    uint16_t *samples,
    size_t sample_count);

#if defined(__cplusplus)
}
#endif
