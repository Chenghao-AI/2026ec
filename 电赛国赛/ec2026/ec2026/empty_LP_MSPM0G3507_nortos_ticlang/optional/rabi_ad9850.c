/* Rabi 备用模块：AD9850 正弦波输出示例实现。 */
#include "rabi_ad9850.h"
#include "ti_msp_dl_config.h"

#define AD9850_CONTROL_POWER_DOWN (1U << 2)
#define AD9850_MAX_AMPLITUDE_PERMILLE 1000U

static rabi_err_t send_frame(rabi_ad9850_t *device, uint32_t tuning_word, bool output_enabled);
static uint32_t calculate_tuning_word(uint32_t frequency_hz, uint32_t reference_clock_hz);
static uint32_t reference_cycles_to_cpu_cycles(const rabi_ad9850_t *device, uint32_t reference_cycles);

rabi_err_t rabi_ad9850_init(rabi_ad9850_t *device, const rabi_ad9850_cfg_t *cfg)
{
    if (device == NULL || cfg == NULL || cfg->reference_clock_hz == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_err_t err = rabi_gpio_serial_init(&cfg->serial);
    if (err != RABI_ERR_OK) return err;

    err = rabi_gpio_serial_set_pin(&cfg->fq_ud, false);
    if (err != RABI_ERR_OK) return err;

    err = rabi_gpio_serial_set_pin(&cfg->reset, false);
    if (err != RABI_ERR_OK) return err;

    *device = (rabi_ad9850_t){
        .cfg = *cfg,
        .frequency_hz = 0,
        .tuning_word = 0,
        .amplitude_permille = 0,
        .output_enabled = false,
        .initialized = true,
    };

    err = rabi_ad9850_reset(device);
    if (err != RABI_ERR_OK) device->initialized = false;
    return err;
}

rabi_err_t rabi_ad9850_reset(rabi_ad9850_t *device)
{
    if (device == NULL || !device->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    uint32_t reset_cycles = reference_cycles_to_cpu_cycles(device, 5U);
    uint32_t recovery_cycles = reference_cycles_to_cpu_cycles(device, 2U);

    /* RESET 高电平至少持续 5 个 AD9850 参考时钟周期。 */
    rabi_err_t err = rabi_gpio_serial_pulse_pin(
        &device->cfg.reset, true, reset_cycles);
    if (err != RABI_ERR_OK) return err;
    delay_cycles(recovery_cycles);

    /*
     * Master Reset 后器件回到并行模式。数据手册规定的 D2/D1/D0=0/1/1
     * 硬件连接就绪后，依次给一个 W_CLK 和 FQ_UD 脉冲进入串行模式。
     */
    err = rabi_gpio_serial_pulse_pin(
        &device->cfg.serial.clock,
        true,
        device->cfg.serial.half_period_cycles);
    if (err != RABI_ERR_OK) return err;

    err = rabi_gpio_serial_pulse_pin(
        &device->cfg.fq_ud,
        true,
        device->cfg.serial.half_period_cycles);
    if (err != RABI_ERR_OK) return err;

    /* 串行模式每次必须完整发送 40 bit；否则应再次 Reset 重新同步。 */
    return send_frame(
        device, device->tuning_word, device->output_enabled);
}

rabi_err_t rabi_ad9850_set_frequency(rabi_ad9850_t *device, uint32_t frequency_hz)
{
    if (device == NULL || !device->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (frequency_hz > device->cfg.reference_clock_hz / 2U)
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint32_t tuning_word = calculate_tuning_word(
        frequency_hz, device->cfg.reference_clock_hz);
    rabi_err_t err = send_frame(
        device, tuning_word, device->output_enabled);
    if (err != RABI_ERR_OK) return err;

    device->frequency_hz = frequency_hz;
    device->tuning_word = tuning_word;
    return RABI_ERR_OK;
}

rabi_err_t rabi_ad9850_set_output_enabled(rabi_ad9850_t *device, bool enabled)
{
    if (device == NULL || !device->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    rabi_err_t err = send_frame(device, device->tuning_word, enabled);
    if (err != RABI_ERR_OK) return err;

    device->output_enabled = enabled;
    return RABI_ERR_OK;
}

rabi_err_t rabi_ad9850_set_amplitude_permille(rabi_ad9850_t *device, uint16_t amplitude_permille)
{
    if (device == NULL || !device->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (amplitude_permille > AD9850_MAX_AMPLITUDE_PERMILLE)
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (device->cfg.amplitude_cb == NULL)
    {
        return RABI_ERR_NOT_SUPPORTED;
    }

    /*
     * 回调在调用者上下文中同步执行。它可以通过 I2C 数字电位器、SPI PGA
     * 或 DAC 调整外部增益，但不要在中断里调用本函数。
     */
    rabi_err_t err = device->cfg.amplitude_cb(
        amplitude_permille, device->cfg.amplitude_context);
    if (err != RABI_ERR_OK) return err;

    device->amplitude_permille = amplitude_permille;
    return RABI_ERR_OK;
}

uint32_t rabi_ad9850_get_frequency(const rabi_ad9850_t *device)
{
    return device != NULL && device->initialized ? device->frequency_hz : 0;
}

uint16_t rabi_ad9850_get_amplitude_permille(
    const rabi_ad9850_t *device)
{
    return device != NULL && device->initialized ?
        device->amplitude_permille : 0;
}

static rabi_err_t send_frame(
    rabi_ad9850_t *device, uint32_t tuning_word, bool output_enabled)
{
    uint8_t control = output_enabled ? 0 : AD9850_CONTROL_POWER_DOWN;

    /* W0~W31: 32-bit FTW，最低位先发送。 */
    rabi_err_t err = rabi_gpio_serial_write_bits(
        &device->cfg.serial,
        tuning_word,
        32,
        RABI_GPIO_SERIAL_LSB_FIRST);
    if (err != RABI_ERR_OK) return err;

    /* W32~W39: Control、Power-Down 和固定为 0 的五位相位字。 */
    err = rabi_gpio_serial_write_bits(
        &device->cfg.serial,
        control,
        8,
        RABI_GPIO_SERIAL_LSB_FIRST);
    if (err != RABI_ERR_OK) return err;

    /* FQ_UD 上升沿把刚刚发送的完整 40-bit 帧更新到 DDS 核心。 */
    return rabi_gpio_serial_pulse_pin(
        &device->cfg.fq_ud,
        true,
        device->cfg.serial.half_period_cycles);
}

static uint32_t calculate_tuning_word(
    uint32_t frequency_hz, uint32_t reference_clock_hz)
{
    /*
     * FTW = round(f_out * 2^32 / f_ref)
     * 必须先提升到 64 bit，否则 frequency_hz << 32 会直接溢出。
     */
    uint64_t numerator = ((uint64_t)frequency_hz << 32) +
        (reference_clock_hz / 2U);
    return (uint32_t)(numerator / reference_clock_hz);
}

static uint32_t reference_cycles_to_cpu_cycles(
    const rabi_ad9850_t *device, uint32_t reference_cycles)
{
    uint64_t numerator = ((uint64_t)CPUCLK_FREQ * reference_cycles) +
        device->cfg.reference_clock_hz - 1U;
    uint64_t cpu_cycles = numerator / device->cfg.reference_clock_hz;

    if (cpu_cycles < device->cfg.serial.half_period_cycles)
    {
        cpu_cycles = device->cfg.serial.half_period_cycles;
    }
    if (cpu_cycles > UINT32_MAX) return UINT32_MAX;
    return (uint32_t)cpu_cycles;
}
