/* Rabi 备用模块：MSPM0 ADC12 多 Memory 扫描轮询实现。 */
#include "rabi_adc_scan.h"

static uint32_t result_interrupt_mask(uint8_t mem_index);
static uint32_t sequence_start_address(uint8_t mem_index);
static uint32_t sequence_end_address(uint8_t mem_index);

rabi_err_t rabi_adc_scan_init(const rabi_adc_scan_t *adc)
{
    if (adc == NULL || adc->instance == NULL || adc->channel_count == 0 ||
        adc->poll_limit == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint32_t first = (uint32_t)adc->start_index;
    uint32_t end = first + adc->channel_count;
    if (first > (uint32_t)DL_ADC12_MEM_IDX_11 ||
        end > (uint32_t)DL_ADC12_MEM_IDX_11 + 1U)
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (!DL_ADC12_isPowerEnabled(adc->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (DL_ADC12_getSampleMode(adc->instance) !=
            DL_ADC12_SAMP_MODE_SEQUENCE ||
        DL_ADC12_getTriggerSource(adc->instance) !=
            DL_ADC12_TRIG_SRC_SOFTWARE)
    {
        return RABI_ERR_NOT_SUPPORTED;
    }

    uint8_t last = (uint8_t)(end - 1U);
    if (DL_ADC12_getStartAddress(adc->instance) !=
            sequence_start_address((uint8_t)first) ||
        DL_ADC12_getEndAddress(adc->instance) !=
            sequence_end_address(last))
    {
        /* 对象描述和 SysConfig 的 Start/End 不一致时，宁可报错也不读陈旧 MEMRES。 */
        return RABI_ERR_INVALID_STATE;
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_adc_scan_read(
    const rabi_adc_scan_t *adc,
    uint16_t *results,
    size_t result_capacity)
{
    if (results == NULL) return RABI_ERR_INVALID_ARG;

    rabi_err_t err = rabi_adc_scan_init(adc);
    if (err != RABI_ERR_OK) return err;
    if (result_capacity < adc->channel_count)
    {
        return RABI_ERR_INVALID_SIZE;
    }

    uint8_t first = (uint8_t)adc->start_index;
    uint8_t last = first + adc->channel_count - 1U;
    uint32_t completion_mask = result_interrupt_mask(last);
    uint32_t error_mask = DL_ADC12_INTERRUPT_OVERFLOW |
        DL_ADC12_INTERRUPT_TRIG_OVF;

    DL_ADC12_clearInterruptStatus(
        adc->instance, completion_mask | error_mask);
    DL_ADC12_enableConversions(adc->instance);
    DL_ADC12_startConversion(adc->instance);

    uint32_t remaining = adc->poll_limit;
    while (DL_ADC12_getRawInterruptStatus(
               adc->instance, completion_mask) == 0)
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

    /* 只有最后一个 MEM Loaded 后才开始读取，因此本数组是同一轮完整扫描结果。 */
    for (uint8_t i = 0; i < adc->channel_count; i++)
    {
        results[i] = DL_ADC12_getMemResult(
            adc->instance, (DL_ADC12_MEM_IDX)(first + i));
    }

    DL_ADC12_clearInterruptStatus(adc->instance, completion_mask);
    DL_ADC12_enableConversions(adc->instance);
    return RABI_ERR_OK;
}

static uint32_t result_interrupt_mask(uint8_t mem_index)
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

    return masks[mem_index];
}

static uint32_t sequence_start_address(uint8_t mem_index)
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

    return addresses[mem_index];
}

static uint32_t sequence_end_address(uint8_t mem_index)
{
    static const uint32_t addresses[] = {
        DL_ADC12_SEQ_END_ADDR_00,
        DL_ADC12_SEQ_END_ADDR_01,
        DL_ADC12_SEQ_END_ADDR_02,
        DL_ADC12_SEQ_END_ADDR_03,
        DL_ADC12_SEQ_END_ADDR_04,
        DL_ADC12_SEQ_END_ADDR_05,
        DL_ADC12_SEQ_END_ADDR_06,
        DL_ADC12_SEQ_END_ADDR_07,
        DL_ADC12_SEQ_END_ADDR_08,
        DL_ADC12_SEQ_END_ADDR_09,
        DL_ADC12_SEQ_END_ADDR_10,
        DL_ADC12_SEQ_END_ADDR_11,
    };

    return addresses[mem_index];
}
