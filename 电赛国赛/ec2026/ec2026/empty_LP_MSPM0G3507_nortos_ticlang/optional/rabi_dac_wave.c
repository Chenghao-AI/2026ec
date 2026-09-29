/* Rabi 备用模块：MSPM0 DAC12 FIFO + DMA 波表输出实现。 */
#include "rabi_dac_wave.h"

static const uint32_t DAC_WAVE_STATUS_MASK =
    DL_DAC12_INTERRUPT_FIFO_UNDERRUN | DL_DAC12_INTERRUPT_DMA_DONE;

rabi_err_t rabi_dac_wave_init(
    rabi_dac_wave_t *wave, const rabi_dac_wave_cfg_t *cfg)
{
    if (wave == NULL || cfg == NULL || cfg->instance == NULL ||
        cfg->sample_rate_hz == 0U)
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_err_t err = rabi_dma_init(&cfg->dma);
    if (err != RABI_ERR_OK) return err;

    if (!DL_DAC12_isPowerEnabled(cfg->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (!DL_DAC12_isFIFOEnabled(cfg->instance))
    {
        return RABI_ERR_NOT_SUPPORTED;
    }

    DL_DAC12_FIFO_TRIGGER expected_trigger =
        cfg->use_sample_time_generator ?
            DL_DAC12_FIFO_TRIGGER_SAMPLETIMER :
            DL_DAC12_FIFO_TRIGGER_HWTRIG0;
    if (DL_DAC12_getFIFOTriggerSource(cfg->instance) != expected_trigger ||
        (!cfg->use_sample_time_generator &&
         DL_DAC12_isSampleTimeGeneratorEnabled(cfg->instance)))
    {
        return RABI_ERR_INVALID_STATE;
    }

    *wave = (rabi_dac_wave_t){
        .cfg = *cfg,
        .samples = NULL,
        .sample_count = 0U,
        .running = false,
        .initialized = true,
    };

    /* 内置采样器在 DMA 地址装好前先停下，避免初始化阶段读空 FIFO。 */
    if (cfg->use_sample_time_generator)
    {
        DL_DAC12_disableSampleTimeGenerator(wave->cfg.instance);
    }
    DL_DAC12_disableDMATrigger(wave->cfg.instance);
    DL_DAC12_disable(wave->cfg.instance);
    rabi_dma_cancel(&wave->cfg.dma);
    DL_DAC12_clearInterruptStatus(
        wave->cfg.instance, DAC_WAVE_STATUS_MASK);
    return RABI_ERR_OK;
}

rabi_err_t rabi_dac_wave_start(
    rabi_dac_wave_t *wave,
    const uint16_t *samples,
    size_t sample_count)
{
    if (wave == NULL || !wave->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (samples == NULL || sample_count == 0U ||
        sample_count > UINT16_MAX ||
        (((uintptr_t)samples & (sizeof(uint16_t) - 1U)) != 0U))
    {
        return RABI_ERR_INVALID_ARG;
    }

    if (wave->cfg.use_sample_time_generator)
    {
        DL_DAC12_disableSampleTimeGenerator(wave->cfg.instance);
    }
    rabi_dma_cancel(&wave->cfg.dma);
    DL_DAC12_clearInterruptStatus(
        wave->cfg.instance, DAC_WAVE_STATUS_MASK);

    rabi_err_t err = rabi_dma_prepare_memory_to_peripheral(
        &wave->cfg.dma,
        samples,
        (uint32_t)(uintptr_t)&wave->cfg.instance->DATA0,
        sample_count,
        DL_DMA_WIDTH_HALF_WORD,
        wave->cfg.repeat);
    if (err != RABI_ERR_OK) return err;

    wave->samples = samples;
    wave->sample_count = sample_count;
    wave->running = true;
    DL_DAC12_enableDMATrigger(wave->cfg.instance);
    DL_DAC12_enable(wave->cfg.instance);

    if (wave->cfg.use_sample_time_generator)
    {
        DL_DAC12_enableSampleTimeGenerator(wave->cfg.instance);
    }
    return RABI_ERR_OK;
}

rabi_err_t rabi_dac_wave_stop(rabi_dac_wave_t *wave)
{
    if (wave == NULL || !wave->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (wave->cfg.use_sample_time_generator)
    {
        DL_DAC12_disableSampleTimeGenerator(wave->cfg.instance);
    }
    DL_DAC12_disableDMATrigger(wave->cfg.instance);
    DL_DAC12_disable(wave->cfg.instance);
    rabi_dma_cancel(&wave->cfg.dma);
    DL_DAC12_clearInterruptStatus(
        wave->cfg.instance, DAC_WAVE_STATUS_MASK);
    wave->running = false;
    return RABI_ERR_OK;
}

bool rabi_dac_wave_is_complete(const rabi_dac_wave_t *wave)
{
    return wave != NULL && wave->initialized && wave->running &&
        !wave->cfg.repeat && rabi_dma_is_complete(&wave->cfg.dma);
}

uint32_t rabi_dac_wave_get_frequency_millihz(
    const rabi_dac_wave_t *wave)
{
    if (wave == NULL || !wave->initialized || wave->sample_count == 0U)
    {
        return 0U;
    }

    uint64_t millihz =
        ((uint64_t)wave->cfg.sample_rate_hz * 1000U +
         wave->sample_count / 2U) / wave->sample_count;
    return millihz > UINT32_MAX ? UINT32_MAX : (uint32_t)millihz;
}
