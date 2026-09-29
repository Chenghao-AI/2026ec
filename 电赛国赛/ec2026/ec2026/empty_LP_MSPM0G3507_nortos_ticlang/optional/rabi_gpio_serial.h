/* Rabi 备用模块：轻量 GPIO 串行发送接口。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_gpio.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 轻量 GPIO 串行发送框架
 * ======================
 *
 * 这个模块用于 AD9850、X9C10x、74HC595 等“有 DATA/CLK/LATCH，但不完全是
 * 标准 SPI”的器件。它是一层不认识具体芯片寄存器的“软件移位器”，只负责：
 *
 * 1. 按指定的位序输出 1~64 bit；
 * 2. 在数据稳定后产生一个时钟有效沿；
 * 3. 为 RESET、LATCH、FQ_UD 等控制脚产生脉冲。
 *
 * 它不会解析任何器件寄存器，也不会自动操作 CS、LATCH、LDAC、RESET、FQ_UD
 * 等帧控制脚。具体芯片驱动应放在另一个 rabi_xxx.c 中：先组成数据手册要求的
 * 帧，用 write_bits()/write_bytes() 发出，再用 set_pin()/pulse_pin() 完成更新。
 * 所有接口都同步、阻塞执行，不使用中断、DMA 或动态内存。
 *
 * 面对陌生芯片时，先从数据手册确认下面五项：
 *
 * - 空闲电平：CLK 空闲时是低还是高；
 * - 采样沿：芯片在 CLK 上升沿还是下降沿读取 DATA；
 * - 位序：MSB first 还是 LSB first；
 * - 帧边界：发送多少位，以及由 CS、LATCH、LDAC、FQ_UD 中哪一个脚更新；
 * - 时序：数据建立/保持时间、CLK 高低电平宽度和控制脉冲宽度。
 *
 * 如果器件只是普通 SPI，优先使用 MSPM0 的硬件 SPI；只有协议不标准、速率不高
 * 或需要特殊脉冲时才使用本模块。需要读取 DATA、严格连续高速时钟或 DMA 的器件
 * 也不适合使用这个 TX-only 轻量框架。
 *
 * 一个位的实际时序
 * ------------------
 * clock_idle_high=false 时，时钟有效沿是上升沿：
 *
 *     DATA  ----x======= Dn 保持稳定 =================x----
 *     CLK   ____________/~~~~~~~~~~~~\____________________
 *                        ^ 芯片通常在此处采样
 *            建立时间       高电平宽度       保持/空闲时间
 *          half_period     half_period      half_period
 *
 * clock_idle_high=true 时 CLK 波形上下翻转，有效沿变成下降沿。这个接口只表达
 * “空闲电平 + 第一个跳变为采样沿”的器件；若芯片要求在第二个边沿采样，或要求
 * 独立配置 CPOL/CPHA，请优先使用硬件 SPI，或为该芯片单独扩展时序函数。
 *
 * SysConfig 与首次接入
 * --------------------
 * 1. 在 SysConfig 建立一个 GPIO Pin Group，把 DATA、CLK 和全部控制脚设为
 *    Digital Output；初始电平按数据手册设置，常见情况为 Low。
 * 2. 在具体芯片的 cfg 中填入 SysConfig 生成的 PORT/PIN 宏。PORT 是 GPIOA/
 *    GPIOB 寄存器地址，PIN 必须是单个 DL_GPIO_PIN_x 掩码，不能把多个 PIN 相或。
 * 3. 先调用 rabi_system_init()，再初始化具体芯片驱动。rabi_system_init() 内部的
 *    SYSCFG_DL_init() 会完成 GPIO 电源、IOMUX 和方向配置。
 *
 *     static const rabi_gpio_serial_t s_bus = {
 *         .data = {MY_DEVICE_PORT, MY_DEVICE_DATA_PIN},
 *         .clock = {MY_DEVICE_PORT, MY_DEVICE_CLK_PIN},
 *         .clock_idle_high = false,
 *         .half_period_cycles = CPUCLK_FREQ / 1000000U, // 约 1 us
 *     };
 *
 * 上面的 MY_DEVICE_xxx 只是示意名，必须换成当前 .syscfg 实际生成的宏。
 *
 * 面对陌生芯片的推荐拆分
 * ----------------------
 * 不要把寄存器知识塞进本文件；复制 optional/rabi_ad9850.* 的结构，新建
 * rabi_xxx.h/.c，并按下面顺序实现：
 *
 * 1. cfg 保存串行 DATA/CLK、控制脚和芯片相关参数；
 * 2. init() 检查参数、设置所有脚的已知空闲状态，并按手册执行复位序列；
 * 3. 私有 send_frame() 只做“拉 CS -> 组帧/发送 -> 释放 CS 或脉冲 LATCH”；
 * 4. 对外只暴露业务接口，如 set_frequency()、set_gain()、read_voltage()；
 * 5. 先把 half_period_cycles 调大，用逻辑分析仪核对位序、边沿和帧宽，再提速。
 *
 * 若需要在事件回调中发送，可以直接调用具体芯片接口；不要从 SysTick ISR 调用。
 * 本模块不加锁且不可重入，同一总线不能被主循环和中断同时操作。普通中断只会
 * 拉长某一段脉冲，不会让最小脉宽变短；但有“最大时钟暂停时间”的器件仍不适用。
 */

typedef struct
{
    /* SysConfig 生成的 GPIOx 寄存器地址和“单个”DL_GPIO_PIN_x 掩码。 */
    GPIO_Regs *port;
    uint32_t pin;
} rabi_gpio_serial_pin_t;

typedef enum
{
    RABI_GPIO_SERIAL_LSB_FIRST,
    RABI_GPIO_SERIAL_MSB_FIRST,
} rabi_gpio_serial_bit_order_t;

typedef struct
{
    rabi_gpio_serial_pin_t data;
    rabi_gpio_serial_pin_t clock;

    /*
     * false: CLK 空闲为低，有效沿为上升沿。
     * true : CLK 空闲为高，有效沿为下降沿。
     */
    bool clock_idle_high;

    /*
     * DATA 建立、CLK 有效和 CLK 恢复三段延时各自的最小 CPU 周期数。
     * CPU 主频可能被 SysConfig 修改，所以优先用 CPUCLK_FREQ 换算，不要写死
     * “32 MHz 下的周期数”。陌生器件建议先取 CPUCLK_FREQ / 1000000U（约 1 us）。
     * delay_cycles() 是忙等，因此发送期间当前执行上下文不会做其他工作。
     */
    uint32_t half_period_cycles;
} rabi_gpio_serial_t;

/*
 * 检查配置，并把 DATA 拉低、CLK 恢复到指定空闲电平。
 * SysConfig 必须已经把相关引脚配置为 Digital Output；本函数不修改 IOMUX、
 * GPIO 方向或电源。可在具体芯片 init() 中调用，也可在总线失步时重新调用。
 */
rabi_err_t rabi_gpio_serial_init(const rabi_gpio_serial_t *serial);

/* 立即设置一个控制脚；不附带延时，也不会改变 DATA/CLK 总线状态。 */
rabi_err_t rabi_gpio_serial_set_pin(
    const rabi_gpio_serial_pin_t *pin, bool high);

/*
 * 产生一个完整控制脉冲，并在返回前恢复非有效电平。
 * active_high=true 表示低-高-低，false 表示高-低-高；pulse_cycles 同时用作
 * 脉冲前保护、有效宽度和脉冲后保护。若器件三段要求不同，应在具体驱动中用
 * set_pin() + delay_cycles() 明确写出，而不要勉强复用本便捷函数。
 */
rabi_err_t rabi_gpio_serial_pulse_pin(
    const rabi_gpio_serial_pin_t *pin,
    bool active_high,
    uint32_t pulse_cycles);

/*
 * 发送 data 的低 bit_count 位，允许 1~64 bit。
 * LSB_FIRST 从 bit 0 开始；MSB_FIRST 从 bit_count - 1 开始，而不是固定从 bit 63。
 * 返回时 CLK 已恢复空闲电平，DATA 保持为最后发送的一位。
 */
rabi_err_t rabi_gpio_serial_write_bits(
    const rabi_gpio_serial_t *serial,
    uint64_t data,
    uint8_t bit_count,
    rabi_gpio_serial_bit_order_t bit_order);

/*
 * 整个 buffer 作为一次连续事务发送，字节顺序固定为 buffer[0]、buffer[1] ...；
 * bit_order 只控制每个字节内部的位序。比如一个 16-bit 大端寄存器值，应由具体
 * 驱动先组织为 {value >> 8, value & 0xff}，本模块不会猜测 CPU/芯片大小端。
 */
rabi_err_t rabi_gpio_serial_write_bytes(
    const rabi_gpio_serial_t *serial,
    const uint8_t *buffer,
    size_t length,
    rabi_gpio_serial_bit_order_t bit_order);

#if defined(__cplusplus)
}
#endif
