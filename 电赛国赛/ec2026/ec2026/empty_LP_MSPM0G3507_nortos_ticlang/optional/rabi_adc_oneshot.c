/* Rabi 备用模块：MSPM0 ADC12 One Shot 轮询读取实现。 */
#include "rabi_adc_oneshot.h"

static uint32_t result_interrupt_mask(DL_ADC12_MEM_IDX mem_index);
static uint32_t sequence_start_address(DL_ADC12_MEM_IDX mem_index);

rabi_err_t rabi_adc_oneshot_init(const rabi_adc_oneshot_t *adc)
{
    if (adc == NULL || adc->instance == NULL || adc->poll_limit == 0 ||
        (uint32_t)adc->mem_index > (uint32_t)DL_ADC12_MEM_IDX_11)
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (!DL_ADC12_isPowerEnabled(adc->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }

    /* 此封装自己产生 SC 软件触发，不适用于 Timer/Event 硬件触发模式。 */
    if (DL_ADC12_getSampleMode(adc->instance) != DL_ADC12_SAMP_MODE_SINGLE ||
        DL_ADC12_getTriggerSource(adc->instance) != DL_ADC12_TRIG_SRC_SOFTWARE)
    {
        return RABI_ERR_NOT_SUPPORTED;
    }
    if (DL_ADC12_getStartAddress(adc->instance) !=
        sequence_start_address(adc->mem_index))
    {
        /* 防止对象写 MEM3，但 SysConfig 的 Single Conversion 实际仍从 MEM0 开始。 */
        return RABI_ERR_INVALID_STATE;
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_adc_oneshot_read(
    const rabi_adc_oneshot_t *adc, uint16_t *result)
{
    if (result == NULL) return RABI_ERR_INVALID_ARG;

    rabi_err_t err = rabi_adc_oneshot_init(adc);
    if (err != RABI_ERR_OK) return err;

    uint32_t result_mask = result_interrupt_mask(adc->mem_index);
    uint32_t error_mask = DL_ADC12_INTERRUPT_OVERFLOW |
        DL_ADC12_INTERRUPT_TRIG_OVF;

    /* 清除旧结果，避免上一次转换的 RIS 让本次读取立即“假完成”。 */
    DL_ADC12_clearInterruptStatus(
        adc->instance, result_mask | error_mask);
    DL_ADC12_enableConversions(adc->instance);
    DL_ADC12_startConversion(adc->instance);

    uint32_t remaining = adc->poll_limit;
    while (DL_ADC12_getRawInterruptStatus(
               adc->instance, result_mask) == 0)
    {
        if (DL_ADC12_getRawInterruptStatus(
                adc->instance, error_mask) != 0)
        {
            DL_ADC12_stopConversion(adc->instance);
            DL_ADC12_clearInterruptStatus(adc->instance, error_mask);
            return RABI_ERR_FAIL;
        }
        if (--remaining == 0)
        {
            DL_ADC12_stopConversion(adc->instance);
            return RABI_ERR_TIMEOUT;
        }
    }

    *result = DL_ADC12_getMemResult(adc->instance, adc->mem_index);
    DL_ADC12_clearInterruptStatus(adc->instance, result_mask);

    /* TI 单次转换示例同样在每次读取后重新置 ENC，为下一次调用恢复就绪状态。 */
    DL_ADC12_enableConversions(adc->instance);
    return RABI_ERR_OK;
}

static uint32_t result_interrupt_mask(DL_ADC12_MEM_IDX mem_index)
{
    static const uint32_t masks[] = {
        DL_ADC12_INTERRUPT_MEM0_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM1_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM2_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM3_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM4_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM5_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM6_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM7_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM8_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM9_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM10_RESULT_LOADED,
        DL_ADC12_INTERRUPT_MEM11_RESULT_LOADED,
    };

    return masks[(uint32_t)mem_index];
}

static uint32_t sequence_start_address(DL_ADC12_MEM_IDX mem_index)
{
    static const uint32_t addresses[] = {
        DL_ADC12_SEQ_START_ADDR_00,
        DL_ADC12_SEQ_START_ADDR_01,
        DL_ADC12_SEQ_START_ADDR_02,
        DL_ADC12_SEQ_START_ADDR_03,
        DL_ADC12_SEQ_START_ADDR_04,
        DL_ADC12_SEQ_START_ADDR_05,
        DL_ADC12_SEQ_START_ADDR_06,
        DL_ADC12_SEQ_START_ADDR_07,
        DL_ADC12_SEQ_START_ADDR_08,
        DL_ADC12_SEQ_START_ADDR_09,
        DL_ADC12_SEQ_START_ADDR_10,
        DL_ADC12_SEQ_START_ADDR_11,
    };

    return addresses[(uint32_t)mem_index];
}
