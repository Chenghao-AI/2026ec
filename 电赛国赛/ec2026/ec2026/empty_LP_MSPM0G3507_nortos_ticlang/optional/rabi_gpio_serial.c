/* Rabi 备用模块：轻量 GPIO 串行发送实现。 */
#include "rabi_gpio_serial.h"
#include "ti_msp_dl_config.h"

static bool is_pin_valid(const rabi_gpio_serial_pin_t *pin);
static bool is_bit_order_valid(rabi_gpio_serial_bit_order_t bit_order);
static void set_pin_fast(const rabi_gpio_serial_pin_t *pin, bool high);
static void delay_if_needed(uint32_t cycles);
static void write_one_bit(const rabi_gpio_serial_t *serial, bool bit);

rabi_err_t rabi_gpio_serial_init(const rabi_gpio_serial_t *serial)
{
    /*
     * 这里验证的是“运行时描述符”而不是硬件配置。GPIO 是否真的被复用成普通
     * 数字输出，只能由 SysConfig 保证；DriverLib 没有必要在每次发送前重配 IOMUX。
     */
    if (serial == NULL || !is_pin_valid(&serial->data) ||
        !is_pin_valid(&serial->clock) || serial->half_period_cycles == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    if (serial->data.port == serial->clock.port &&
        serial->data.pin == serial->clock.pin)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /*
     * 每次事务从确定状态开始：DATA 默认拉低，CLK 回到配置的空闲电平。
     * 这里只写输出锁存器，不会改变方向，也不会产生一次完整的时钟有效沿。
     */
    set_pin_fast(&serial->data, false);
    set_pin_fast(&serial->clock, serial->clock_idle_high);
    return RABI_ERR_OK;
}

rabi_err_t rabi_gpio_serial_set_pin(
    const rabi_gpio_serial_pin_t *pin, bool high)
{
    if (!is_pin_valid(pin)) return RABI_ERR_INVALID_ARG;

    /* 便捷接口主要供具体器件驱动操作 CS、RESET、LATCH、FQ_UD 等控制脚。 */
    set_pin_fast(pin, high);
    return RABI_ERR_OK;
}

rabi_err_t rabi_gpio_serial_pulse_pin(
    const rabi_gpio_serial_pin_t *pin,
    bool active_high,
    uint32_t pulse_cycles)
{
    if (!is_pin_valid(pin) || pulse_cycles == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /*
     * 先强制进入非有效电平，可让上电状态不确定的控制脚得到一个完整脉冲。
     * 三段都等待 pulse_cycles，使有效沿两侧也满足最小保护时间。
     */
    set_pin_fast(pin, !active_high);
    delay_if_needed(pulse_cycles);
    set_pin_fast(pin, active_high);
    delay_if_needed(pulse_cycles);
    set_pin_fast(pin, !active_high);
    delay_if_needed(pulse_cycles);

    return RABI_ERR_OK;
}

rabi_err_t rabi_gpio_serial_write_bits(
    const rabi_gpio_serial_t *serial,
    uint64_t data,
    uint8_t bit_count,
    rabi_gpio_serial_bit_order_t bit_order)
{
    if (serial == NULL || bit_count == 0 || bit_count > 64 ||
        !is_bit_order_valid(bit_order))
    {
        return RABI_ERR_INVALID_ARG;
    }

    /* init() 同时完成参数检查，并保证第一个 bit 之前 CLK 已处于空闲状态。 */
    rabi_err_t err = rabi_gpio_serial_init(serial);
    if (err != RABI_ERR_OK) return err;

    for (uint8_t i = 0; i < bit_count; i++)
    {
        /*
         * MSB first 从“本次有效字段”的最高位开始。例如 bit_count=12 时从
         * data[11] 开始，而不是从 uint64_t 的 bit 63 开始。
         */
        uint8_t shift = bit_order == RABI_GPIO_SERIAL_LSB_FIRST ?
            i : (bit_count - 1U - i);
        bool bit = ((data >> shift) & 0x01U) != 0;

        write_one_bit(serial, bit);
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_gpio_serial_write_bytes(
    const rabi_gpio_serial_t *serial,
    const uint8_t *buffer,
    size_t length,
    rabi_gpio_serial_bit_order_t bit_order)
{
    if (serial == NULL || buffer == NULL || length == 0 ||
        !is_bit_order_valid(bit_order))
    {
        return RABI_ERR_INVALID_ARG;
    }

    /*
     * 整个 buffer 只初始化一次总线，避免每个字节之间额外写 DATA/CLK。
     * 字节间仍有正常的最后一位恢复时间，但不会插入额外时钟或帧控制信号。
     */
    rabi_err_t err = rabi_gpio_serial_init(serial);
    if (err != RABI_ERR_OK) return err;

    for (size_t i = 0; i < length; i++)
    {
        for (uint8_t bit_index = 0; bit_index < 8; bit_index++)
        {
            uint8_t shift = bit_order == RABI_GPIO_SERIAL_LSB_FIRST ?
                bit_index : (7U - bit_index);
            bool bit = ((buffer[i] >> shift) & 0x01U) != 0;
            write_one_bit(serial, bit);
        }
    }

    return RABI_ERR_OK;
}

static bool is_pin_valid(const rabi_gpio_serial_pin_t *pin)
{
    if (pin == NULL || pin->port == NULL || pin->pin == 0) return false;

    /*
     * n & (n - 1) == 0 仅对 2 的幂成立，因此可确认 pin 只包含一个 bit。
     * 这样能避免调用者误传 PIN_0 | PIN_1，导致两个外设控制脚被同时翻转。
     */
    return (pin->pin & (pin->pin - 1U)) == 0;
}

static bool is_bit_order_valid(rabi_gpio_serial_bit_order_t bit_order)
{
    return bit_order == RABI_GPIO_SERIAL_LSB_FIRST ||
        bit_order == RABI_GPIO_SERIAL_MSB_FIRST;
}

static void set_pin_fast(const rabi_gpio_serial_pin_t *pin, bool high)
{
    /*
     * setPins/clearPins 写 GPIO 的原子置位/清零寄存器，不需要先 read-modify-write，
     * 因而不会意外覆盖同一 GPIO 端口上由 OLED、键盘等模块控制的其他引脚。
     */
    if (high)
    {
        DL_GPIO_setPins(pin->port, pin->pin);
    }
    else
    {
        DL_GPIO_clearPins(pin->port, pin->pin);
    }
}

static void delay_if_needed(uint32_t cycles)
{
    /*
     * delay_cycles() 是 CPU 忙等。中断可以延长实际时间，但不会缩短这里要求的
     * 最小时间；因此此框架适合“只有最小脉宽限制”的低速写事务。
     */
    if (cycles != 0) delay_cycles(cycles);
}

static void write_one_bit(const rabi_gpio_serial_t *serial, bool bit)
{
    /* A：先改变 DATA，再等待一个建立时间。 */
    set_pin_fast(&serial->data, bit);
    delay_if_needed(serial->half_period_cycles);

    /* B：从空闲电平跳到有效电平；芯片应在这个第一个边沿采样 DATA。 */
    set_pin_fast(&serial->clock, !serial->clock_idle_high);
    delay_if_needed(serial->half_period_cycles);

    /* C：回到空闲电平，并保留一个保持/字间隔时间后才发送下一位。 */
    set_pin_fast(&serial->clock, serial->clock_idle_high);
    delay_if_needed(serial->half_period_cycles);
}
