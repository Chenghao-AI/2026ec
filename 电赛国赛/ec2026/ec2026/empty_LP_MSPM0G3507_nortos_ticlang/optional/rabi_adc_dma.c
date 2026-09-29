/* Rabi 备用模块：ADC12 FIFO 到 RAM 的 DMA 采样示例实现。 */
#include "rabi_adc_dma.h"

static rabi_err_t wait_adc_idle(const rabi_adc_dma_t *capture);

rabi_err_t rabi_adc_dma_init(const rabi_adc_dma_t *capture)
{
    if (capture == NULL || capture->adc == NULL ||
        capture->adc_dma_trigger == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_err_t err = rabi_dma_init(&capture->dma);
    if (err != RABI_ERR_OK) return err;

    if (!DL_ADC12_isPowerEnabled(capture->adc))
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (!DL_ADC12_isFIFOEnabled(capture->adc) ||
        !DL_ADC12_isDMAEnabled(capture->adc))
    {
        return RABI_ERR_NOT_SUPPORTED;
    }
    if (DL_ADC12_getEnabledDMATrigger(
            capture->adc, capture->adc_dma_trigger) == 0)
    {
        return RABI_ERR_INVALID_STATE;
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_adc_dma_capture(
    const rabi_adc_dma_t *capture,
    uint16_t *samples,
    size_t sample_count)
{
    rabi_err_t err = rabi_adc_dma_init(capture);
    if (err != RABI_ERR_OK) return err;
    if (samples == NULL || sample_count < 2U ||
        (sample_count & 1U) != 0 ||
        sample_count / 2U > UINT16_MAX ||
        (((uintptr_t)samples) & (sizeof(uint32_t) - 1U)) != 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /*
     * 先确保 ADC 停止，再切换 FIFOEN 以从空 FIFO 开始。否则上一轮尾部残留样本
     * 会成为本轮 samples[0]，造成所有通道顺序整体错位。
     */
    DL_ADC12_stopConversion(capture->adc);
    err = wait_adc_idle(capture);
    if (err != RABI_ERR_OK) return err;
    DL_ADC12_disableConversions(capture->adc);
    DL_ADC12_disableFIFO(capture->adc);
    DL_ADC12_enableFIFO(capture->adc);
    DL_ADC12_clearDMATriggerStatus(
        capture->adc, capture->adc_dma_trigger);

    err = rabi_dma_prepare_peripheral_to_memory(&capture->dma,
        DL_ADC12_getFIFOAddress(capture->adc),
        samples,
        sample_count / 2U,
        DL_DMA_WIDTH_WORD);
    if (err != RABI_ERR_OK) return err;

    uint32_t adc_error_mask = DL_ADC12_INTERRUPT_OVERFLOW |
        DL_ADC12_INTERRUPT_TRIG_OVF |
        DL_ADC12_INTERRUPT_UNDERFLOW;
    DL_ADC12_clearInterruptStatus(capture->adc, adc_error_mask);
    DL_ADC12_enableConversions(capture->adc);
    DL_ADC12_startConversion(capture->adc);

    err = rabi_dma_wait(&capture->dma);

    /* 无论成功还是超时，都立即停 ADC，避免 Repeat 模式继续把 FIFO 写爆。 */
    DL_ADC12_stopConversion(capture->adc);
    rabi_err_t idle_err = wait_adc_idle(capture);
    if (err == RABI_ERR_OK && idle_err != RABI_ERR_OK) err = idle_err;

    if (DL_ADC12_getRawInterruptStatus(
            capture->adc, adc_error_mask) != 0)
    {
        DL_ADC12_clearInterruptStatus(capture->adc, adc_error_mask);
        if (err == RABI_ERR_OK) err = RABI_ERR_FAIL;
    }

    DL_ADC12_clearDMATriggerStatus(
        capture->adc, capture->adc_dma_trigger);
    DL_ADC12_enableConversions(capture->adc);
    return err;
}

static rabi_err_t wait_adc_idle(const rabi_adc_dma_t *capture)
{
    uint32_t remaining = capture->dma.poll_limit;
    while ((DL_ADC12_getStatus(capture->adc) &
            DL_ADC12_STATUS_CONVERSION_ACTIVE) != 0)
    {
        if (--remaining == 0) return RABI_ERR_TIMEOUT;
    }
    return RABI_ERR_OK;
}
