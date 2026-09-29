/* Rabi 备用模块：MSPM0 DAC12 单点模拟输出实现。 */
#include "rabi_dac.h"

rabi_err_t rabi_dac_init(
    rabi_dac_t *dac, const rabi_dac_cfg_t *cfg)
{
    if (dac == NULL || cfg == NULL || cfg->instance == NULL ||
        cfg->reference_high_mv <= cfg->reference_low_mv ||
        cfg->initial_raw > RABI_DAC_MAX_RAW)
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (!DL_DAC12_isPowerEnabled(cfg->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (DL_DAC12_isFIFOEnabled(cfg->instance) ||
        DL_DAC12_isDMATriggerEnabled(cfg->instance))
    {
        /* FIFO/DMA 配置属于 rabi_dac_wave，不能与 CPU 固定输出混用。 */
        return RABI_ERR_NOT_SUPPORTED;
    }

    *dac = (rabi_dac_t){
        .cfg = *cfg,
        .raw = cfg->initial_raw,
        .initialized = true,
    };

    DL_DAC12_output12(dac->cfg.instance, dac->raw);
    return rabi_dac_set_enabled(dac, cfg->enable_on_init);
}

rabi_err_t rabi_dac_set_enabled(rabi_dac_t *dac, bool enabled)
{
    if (dac == NULL || !dac->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (enabled)
    {
        /* 先恢复最新原码，再打开模块，避免重新启用时短暂输出旧 DATA0。 */
        DL_DAC12_output12(dac->cfg.instance, dac->raw);
        DL_DAC12_enable(dac->cfg.instance);
    }
    else
    {
        DL_DAC12_disable(dac->cfg.instance);
    }
    return RABI_ERR_OK;
}

rabi_err_t rabi_dac_set_raw(rabi_dac_t *dac, uint16_t raw)
{
    if (dac == NULL || !dac->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (raw > RABI_DAC_MAX_RAW) return RABI_ERR_INVALID_ARG;

    dac->raw = raw;
    DL_DAC12_output12(dac->cfg.instance, raw);
    return RABI_ERR_OK;
}

rabi_err_t rabi_dac_set_millivolts(
    rabi_dac_t *dac, uint32_t millivolts)
{
    if (dac == NULL || !dac->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (millivolts < dac->cfg.reference_low_mv ||
        millivolts > dac->cfg.reference_high_mv)
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint32_t span =
        dac->cfg.reference_high_mv - dac->cfg.reference_low_mv;
    uint32_t relative = millivolts - dac->cfg.reference_low_mv;
    uint32_t raw = (uint32_t)(((uint64_t)relative * RABI_DAC_MAX_RAW +
                               span / 2U) / span);
    return rabi_dac_set_raw(dac, (uint16_t)raw);
}

rabi_err_t rabi_dac_set_permille(
    rabi_dac_t *dac, uint16_t permille)
{
    if (permille > RABI_DAC_MAX_PERMILLE)
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint32_t raw = ((uint32_t)permille * RABI_DAC_MAX_RAW +
                    RABI_DAC_MAX_PERMILLE / 2U) /
                   RABI_DAC_MAX_PERMILLE;
    return rabi_dac_set_raw(dac, (uint16_t)raw);
}

uint16_t rabi_dac_get_raw(const rabi_dac_t *dac)
{
    return dac != NULL && dac->initialized ? dac->raw : 0U;
}

uint32_t rabi_dac_get_millivolts(const rabi_dac_t *dac)
{
    if (dac == NULL || !dac->initialized) return 0U;

    uint32_t span =
        dac->cfg.reference_high_mv - dac->cfg.reference_low_mv;
    uint32_t relative = (uint32_t)(
        ((uint64_t)dac->raw * span + RABI_DAC_MAX_RAW / 2U) /
        RABI_DAC_MAX_RAW);
    return dac->cfg.reference_low_mv + relative;
}

bool rabi_dac_is_enabled(const rabi_dac_t *dac)
{
    return dac != NULL && dac->initialized &&
        DL_DAC12_isEnabled(dac->cfg.instance);
}

rabi_err_t rabi_dac_calibrate(rabi_dac_t *dac)
{
    if (dac == NULL || !dac->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    bool was_enabled = DL_DAC12_isEnabled(dac->cfg.instance);
    if (!was_enabled) DL_DAC12_enable(dac->cfg.instance);
    DL_DAC12_performSelfCalibrationBlocking(dac->cfg.instance);
    if (!was_enabled) DL_DAC12_disable(dac->cfg.instance);
    return RABI_ERR_OK;
}
