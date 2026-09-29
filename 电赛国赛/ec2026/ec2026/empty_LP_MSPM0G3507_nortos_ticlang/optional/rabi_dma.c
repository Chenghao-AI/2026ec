/* Rabi 备用模块：MSPM0 DMA 轮询式基础示例实现。 */
#include "rabi_dma.h"

static uint32_t width_bytes(DL_DMA_WIDTH width);
static bool is_aligned(uintptr_t address, uint32_t alignment);
static void prepare_channel(const rabi_dma_t *dma);

rabi_err_t rabi_dma_init(const rabi_dma_t *dma)
{
    if (dma == NULL || dma->instance == NULL ||
        dma->channel >= DMA_SYS_N_DMA_CHANNEL ||
        dma->completion_interrupt == 0 || dma->poll_limit == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /* 一个对象只监听一个通道完成 bit，防止误清除其他通道的完成状态。 */
    if ((dma->completion_interrupt &
            (dma->completion_interrupt - 1U)) != 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_dma_copy_words(
    const rabi_dma_t *dma,
    uint32_t *destination,
    const uint32_t *source,
    size_t word_count)
{
    rabi_err_t err = rabi_dma_init(dma);
    if (err != RABI_ERR_OK) return err;
    if (destination == NULL || source == NULL || word_count == 0 ||
        word_count > UINT16_MAX ||
        !is_aligned((uintptr_t)destination, sizeof(uint32_t)) ||
        !is_aligned((uintptr_t)source, sizeof(uint32_t)))
    {
        return RABI_ERR_INVALID_ARG;
    }

    prepare_channel(dma);

    /* 软件触发块复制的四个关键属性全部在这里显式写出。 */
    DL_DMA_configMode(dma->instance, dma->channel,
        DL_DMA_SINGLE_BLOCK_TRANSFER_MODE, DL_DMA_NORMAL_MODE);
    DL_DMA_setSrcIncrement(
        dma->instance, dma->channel, DL_DMA_ADDR_INCREMENT);
    DL_DMA_setDestIncrement(
        dma->instance, dma->channel, DL_DMA_ADDR_INCREMENT);
    DL_DMA_setSrcWidth(
        dma->instance, dma->channel, DL_DMA_WIDTH_WORD);
    DL_DMA_setDestWidth(
        dma->instance, dma->channel, DL_DMA_WIDTH_WORD);

    DL_DMA_setSrcAddr(dma->instance, dma->channel,
        (uint32_t)(uintptr_t)source);
    DL_DMA_setDestAddr(dma->instance, dma->channel,
        (uint32_t)(uintptr_t)destination);
    DL_DMA_setTransferSize(
        dma->instance, dma->channel, (uint16_t)word_count);

    DL_DMA_enableChannel(dma->instance, dma->channel);
    DL_DMA_startTransfer(dma->instance, dma->channel);
    return rabi_dma_wait(dma);
}

rabi_err_t rabi_dma_prepare_peripheral_to_memory(
    const rabi_dma_t *dma,
    uint32_t peripheral_address,
    void *destination,
    size_t transfer_count,
    DL_DMA_WIDTH width)
{
    rabi_err_t err = rabi_dma_init(dma);
    if (err != RABI_ERR_OK) return err;

    uint32_t bytes = width_bytes(width);
    if (peripheral_address == 0 || destination == NULL || bytes == 0 ||
        transfer_count == 0 || transfer_count > UINT16_MAX ||
        !is_aligned(peripheral_address, bytes) ||
        !is_aligned((uintptr_t)destination, bytes))
    {
        return RABI_ERR_INVALID_ARG;
    }

    prepare_channel(dma);

    /* 每次外设 DMA 请求搬一个单元，累计 transfer_count 次后产生通道完成标志。 */
    DL_DMA_configMode(dma->instance, dma->channel,
        DL_DMA_SINGLE_TRANSFER_MODE, DL_DMA_NORMAL_MODE);
    DL_DMA_setSrcIncrement(
        dma->instance, dma->channel, DL_DMA_ADDR_UNCHANGED);
    DL_DMA_setDestIncrement(
        dma->instance, dma->channel, DL_DMA_ADDR_INCREMENT);
    DL_DMA_setSrcWidth(dma->instance, dma->channel, width);
    DL_DMA_setDestWidth(dma->instance, dma->channel, width);

    DL_DMA_setSrcAddr(
        dma->instance, dma->channel, peripheral_address);
    DL_DMA_setDestAddr(dma->instance, dma->channel,
        (uint32_t)(uintptr_t)destination);
    DL_DMA_setTransferSize(
        dma->instance, dma->channel, (uint16_t)transfer_count);
    DL_DMA_enableChannel(dma->instance, dma->channel);
    return RABI_ERR_OK;
}

rabi_err_t rabi_dma_prepare_memory_to_peripheral(
    const rabi_dma_t *dma,
    const void *source,
    uint32_t peripheral_address,
    size_t transfer_count,
    DL_DMA_WIDTH width,
    bool repeat)
{
    rabi_err_t err = rabi_dma_init(dma);
    if (err != RABI_ERR_OK) return err;

    uint32_t bytes = width_bytes(width);
    if (source == NULL || peripheral_address == 0U || bytes == 0U ||
        transfer_count == 0U || transfer_count > UINT16_MAX ||
        !is_aligned((uintptr_t)source, bytes) ||
        !is_aligned(peripheral_address, bytes))
    {
        return RABI_ERR_INVALID_ARG;
    }

    prepare_channel(dma);

    DL_DMA_configMode(dma->instance, dma->channel,
        repeat ? DL_DMA_FULL_CH_REPEAT_SINGLE_TRANSFER_MODE :
                 DL_DMA_SINGLE_TRANSFER_MODE,
        DL_DMA_NORMAL_MODE);
    DL_DMA_setSrcIncrement(
        dma->instance, dma->channel, DL_DMA_ADDR_INCREMENT);
    DL_DMA_setDestIncrement(
        dma->instance, dma->channel, DL_DMA_ADDR_UNCHANGED);
    DL_DMA_setSrcWidth(dma->instance, dma->channel, width);
    DL_DMA_setDestWidth(dma->instance, dma->channel, width);

    DL_DMA_setSrcAddr(dma->instance, dma->channel,
        (uint32_t)(uintptr_t)source);
    DL_DMA_setDestAddr(
        dma->instance, dma->channel, peripheral_address);
    DL_DMA_setTransferSize(
        dma->instance, dma->channel, (uint16_t)transfer_count);
    DL_DMA_enableChannel(dma->instance, dma->channel);
    return RABI_ERR_OK;
}

rabi_err_t rabi_dma_wait(const rabi_dma_t *dma)
{
    rabi_err_t err = rabi_dma_init(dma);
    if (err != RABI_ERR_OK) return err;

    uint32_t remaining = dma->poll_limit;
    while (!rabi_dma_is_complete(dma))
    {
        if (--remaining == 0)
        {
            rabi_dma_cancel(dma);
            return RABI_ERR_TIMEOUT;
        }
    }

    DL_DMA_disableChannel(dma->instance, dma->channel);
    DL_DMA_clearInterruptStatus(
        dma->instance, dma->completion_interrupt);
    return RABI_ERR_OK;
}

bool rabi_dma_is_complete(const rabi_dma_t *dma)
{
    if (rabi_dma_init(dma) != RABI_ERR_OK) return false;

    return DL_DMA_getRawInterruptStatus(
        dma->instance, dma->completion_interrupt) != 0;
}

void rabi_dma_cancel(const rabi_dma_t *dma)
{
    if (rabi_dma_init(dma) != RABI_ERR_OK) return;

    DL_DMA_disableChannel(dma->instance, dma->channel);
    DL_DMA_clearInterruptStatus(
        dma->instance, dma->completion_interrupt);
}

static uint32_t width_bytes(DL_DMA_WIDTH width)
{
    switch (width)
    {
        case DL_DMA_WIDTH_BYTE:
            return 1U;
        case DL_DMA_WIDTH_HALF_WORD:
            return 2U;
        case DL_DMA_WIDTH_WORD:
            return 4U;
        default:
            return 0;
    }
}

static bool is_aligned(uintptr_t address, uint32_t alignment)
{
    return (address & (alignment - 1U)) == 0;
}

static void prepare_channel(const rabi_dma_t *dma)
{
    /* 先关闭并清旧完成标志，避免重装地址时通道仍响应迟到的外设请求。 */
    DL_DMA_disableChannel(dma->instance, dma->channel);
    DL_DMA_clearInterruptStatus(
        dma->instance, dma->completion_interrupt);
}
