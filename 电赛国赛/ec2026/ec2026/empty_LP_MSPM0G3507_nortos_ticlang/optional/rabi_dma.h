/* Rabi 备用模块：MSPM0 DMA 轮询式基础示例接口。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_dma.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 轻量 DMA 示例框架
 * =================
 *
 * DMA 最容易出错的地方不是“如何启动”，而是四个配置必须互相匹配：
 *
 *     触发源 + 传输模式 + 数据宽度 + 地址增量
 *
 * 本模块提供三个最小模板：
 *
 * 1. copy_words()：软件触发的 RAM/Flash -> RAM 32-bit 块复制；
 * 2. prepare_peripheral_to_memory()：外设固定数据寄存器 -> RAM 连续缓冲区；
 * 3. prepare_memory_to_peripheral()：RAM/Flash 波表 -> 外设固定数据寄存器。
 *
 * SysConfig：内存复制示例
 * ----------------------
 * 添加一个 DMA Channel，建议选择 Full Channel，并设置：
 *
 *     Trigger        = Software
 *     Transfer Mode  = Single Block
 *     Source/Dest    = Increment
 *     Source/Dest Width = Word (32 bit)
 *
 * 调用：
 *
 *     static const rabi_dma_t s_dma_copy = {
 *         .instance = DMA,
 *         .channel = DMA_COPY_CHAN_ID,
 *         .completion_interrupt = DL_DMA_INTERRUPT_CHANNEL0,
 *         .poll_limit = 100000U,
 *     };
 *
 *     uint32_t dst[16];
 *     rabi_dma_copy_words(&s_dma_copy, dst, src, 16);
 *
 * SysConfig：外设接收示例
 * ----------------------
 * 让 SysConfig 从外设的 DMA 配置入口创建通道，通常设置为：
 *
 *     Trigger        = 对应 ADC/UART/SPI 事件
 *     Transfer Mode  = Single
 *     Source         = Unchanged
 *     Destination    = Increment
 *     Width          = 与外设数据寄存器匹配
 *
 * prepare_peripheral_to_memory() 会重写模式、宽度和增量，但不会猜测/改写设备相关
 * Trigger 编号；触发连接必须由 SysConfig 完成。准备后先启动外设，再调用 wait()。
 *
 * completion_interrupt 要传“通道完成原始中断掩码”，例如 Channel 0 对应
 * DL_DMA_INTERRUPT_CHANNEL0。轮询 RIS 不要求打开 NVIC，也不要求 enableInterrupt()。
 *
 * 关键概念
 * --------
 * - transfer_count 是“传输单元个数”，不是字节数。Word 宽度下 count=100 表示
 *   400 字节；ADC FIFO 一个 Word 可能打包两个 16-bit 样本；
 * - Source Unchanged 用于 UART RXDATA、ADC FIFO 等固定寄存器地址；
 * - Destination Increment 用于把连续结果依次写入数组；
 * - DMA 异步访问缓冲区，完成前栈变量不能退出、缓冲区不能复用；
 * - 源、目标地址必须满足数据宽度的自然对齐，Word 通常要求 4-byte 对齐；
 * - DMA 不会自动理解 C 数组大小，count/width 配错会直接覆盖邻近内存。
 *
 * 使用边界
 * --------
 * - 本示例用轮询完成标志，便于比赛现场快速验证；后台任务可改成 DMA_IRQHandler；
 * - poll_limit 是等待次数，不是精确时间；超时会禁用通道，防止迟到的外设触发
 *   继续写入已经失效的缓冲区；
 * - G3507 的 DMA 通道能力不完全相同，Block/Table/Fill 等高级模式优先选 Full
 *   Channel，并以 SysConfig 的可选项为准；
 * - Ping-Pong、环形缓冲、Scatter-Gather/Table 和多通道仲裁应另写专用模块。
 */

typedef struct
{
    DMA_Regs *instance;
    uint8_t channel;
    uint32_t completion_interrupt;
    uint32_t poll_limit;
} rabi_dma_t;

rabi_err_t rabi_dma_init(const rabi_dma_t *dma);

/* 同步软件触发复制；word_count 范围为 1~65535，源/目标必须 4-byte 对齐。 */
rabi_err_t rabi_dma_copy_words(
    const rabi_dma_t *dma,
    uint32_t *destination,
    const uint32_t *source,
    size_t word_count);

/*
 * 配置并使能“外设固定地址 -> 内存递增地址”，但不产生软件触发。
 * width 仅支持 BYTE、HALF_WORD、WORD；transfer_count 是该 width 的单元个数。
 */
rabi_err_t rabi_dma_prepare_peripheral_to_memory(
    const rabi_dma_t *dma,
    uint32_t peripheral_address,
    void *destination,
    size_t transfer_count,
    DL_DMA_WIDTH width);

/*
 * 配置并使能“内存递增地址 -> 外设固定寄存器”。repeat=true 使用 Full Channel
 * Repeat Single 模式，适合 DAC 循环波表；所选 DMA 通道必须支持 Full Channel。
 * Trigger 仍由 SysConfig 配置，函数本身不会产生软件触发。
 */
rabi_err_t rabi_dma_prepare_memory_to_peripheral(
    const rabi_dma_t *dma,
    const void *source,
    uint32_t peripheral_address,
    size_t transfer_count,
    DL_DMA_WIDTH width,
    bool repeat);

/* 等待 completion_interrupt；成功或超时后都会禁用通道并清理完成标志。 */
rabi_err_t rabi_dma_wait(const rabi_dma_t *dma);

bool rabi_dma_is_complete(const rabi_dma_t *dma);

void rabi_dma_cancel(const rabi_dma_t *dma);

#if defined(__cplusplus)
}
#endif
