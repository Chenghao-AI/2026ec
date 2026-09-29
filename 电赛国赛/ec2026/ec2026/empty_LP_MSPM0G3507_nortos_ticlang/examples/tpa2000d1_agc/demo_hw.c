/* TPA2000D1 综合示例：ADC/DMA、Timer Event、DAC 和关断脚适配。 */
#include <stddef.h>
#include "demo_hw.h"
#include "demo_board_config.h"

#if DEMO_AGC_HW_READY

#include "demo_config.h"
#include "../../optional/rabi_adc_dma.h"
#include "../../optional/rabi_dac.h"
#include "../../optional/rabi_hw_timer.h"

static rabi_dac_t s_gain_dac;
static rabi_hw_timer_t s_sample_timer;
static bool s_ready;

static const rabi_adc_dma_t s_adc_capture = {
    .adc = DEMO_AGC_ADC_INST,
    .adc_dma_trigger = DEMO_AGC_ADC_DMA_TRIGGER,
    .dma = {
        .instance = DEMO_AGC_DMA_INST,
        .channel = DEMO_AGC_DMA_CHANNEL,
        .completion_interrupt = DEMO_AGC_DMA_COMPLETION_INTERRUPT,
        .poll_limit = DEMO_AGC_DMA_POLL_LIMIT,
    },
};

static const rabi_dac_cfg_t s_gain_dac_cfg = {
    .instance = DEMO_AGC_DAC_INST,
    .reference_low_mv = DEMO_AGC_DAC_REFERENCE_LOW_MV,
    .reference_high_mv = DEMO_AGC_DAC_REFERENCE_HIGH_MV,
    .initial_raw = 0U,
    .enable_on_init = true,
};

static const rabi_hw_timer_cfg_t s_sample_timer_cfg = {
    .instance = DEMO_AGC_TIMER_INST,
    .timer_clock_hz = DEMO_AGC_TIMER_CLOCK_HZ,
    .max_period_counts = DEMO_AGC_TIMER_MAX_COUNTS,
    .period_us = 1000000U / DEMO_SAMPLE_RATE_HZ,
    .mode = RABI_HW_TIMER_MODE_PERIODIC,
    .start_on_init = true,
};

rabi_err_t demo_hw_init(void)
{
    s_ready = false;
    demo_hw_set_amplifier_enabled(false);

    rabi_err_t err = rabi_dac_init(&s_gain_dac, &s_gain_dac_cfg);
    if (err != RABI_ERR_OK) return err;

#if DEMO_AGC_DAC_CALIBRATE_ON_INIT
    err = rabi_dac_calibrate(&s_gain_dac);
    if (err != RABI_ERR_OK) return err;
#endif

    err = rabi_dac_set_millivolts(&s_gain_dac, 0U);
    if (err != RABI_ERR_OK) return err;

    err = rabi_adc_dma_init(&s_adc_capture);
    if (err != RABI_ERR_OK) return err;

    /*
     * Timer ZERO Event -> ADC Event Subscriber 的连接由 SysConfig 完成。本函数只
     * 按真实 timer_clock_hz 重写 10 us 周期并启动计数器，不从 Timer ISR 采样。
     */
    err = rabi_hw_timer_init(&s_sample_timer, &s_sample_timer_cfg);
    if (err != RABI_ERR_OK) return err;

    s_ready = true;
    return RABI_ERR_OK;
}

rabi_err_t demo_hw_capture(uint16_t *samples, size_t sample_count)
{
    if (!s_ready) return RABI_ERR_INVALID_STATE;
    return rabi_adc_dma_capture(&s_adc_capture, samples, sample_count);
}

rabi_err_t demo_hw_set_control_mv(uint16_t control_mv)
{
    if (!s_ready) return RABI_ERR_INVALID_STATE;
    if (control_mv > DEMO_CONTROL_MAX_MV) return RABI_ERR_INVALID_ARG;
    return rabi_dac_set_millivolts(&s_gain_dac, control_mv);
}

void demo_hw_set_amplifier_enabled(bool enabled)
{
    if (enabled)
    {
        DL_GPIO_setPins(DEMO_AGC_SHUTDOWN_PORT, DEMO_AGC_SHUTDOWN_PIN);
    }
    else
    {
        DL_GPIO_clearPins(DEMO_AGC_SHUTDOWN_PORT, DEMO_AGC_SHUTDOWN_PIN);
    }
}

bool demo_hw_is_ready(void)
{
    return s_ready;
}

#else

/*
 * 未配置硬件时的安全桩。保留它是为了让整套“业务代码 + UI”先通过编译；它不
 * 伪造 ADC 数据，也不会假装硬件可用。OLED 会明确显示 CFG。
 */
rabi_err_t demo_hw_init(void)
{
    return RABI_ERR_NOT_SUPPORTED;
}

rabi_err_t demo_hw_capture(uint16_t *samples, size_t sample_count)
{
    (void)samples;
    (void)sample_count;
    return RABI_ERR_NOT_SUPPORTED;
}

rabi_err_t demo_hw_set_control_mv(uint16_t control_mv)
{
    (void)control_mv;
    return RABI_ERR_NOT_SUPPORTED;
}

void demo_hw_set_amplifier_enabled(bool enabled)
{
    (void)enabled;
}

bool demo_hw_is_ready(void)
{
    return false;
}

#endif

