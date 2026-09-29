/* Rabi 备用模块：MSPM0 硬件 SPI 阻塞事务接口。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_gpio.h>
#include <ti/driverlib/dl_spi.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 轻量硬件 SPI 框架
 * =================
 *
 * 本模块把 MSPM0 DriverLib 的 8-bit Controller SPI 封装成带超时、可选手动 CS
 * 的阻塞事务。它不认识具体芯片寄存器，不修改 CPOL、CPHA、位序或波特率；这些
 * 硬件属性全部交给 SysConfig。具体芯片驱动只负责：
 *
 *     拉低 CS -> 发送命令/地址 -> 同步收发数据 -> 等待 SPI 空闲 -> 释放 CS
 *
 * 为什么优先使用手动 GPIO CS
 * ---------------------------
 * 很多 ADC、DAC、Flash 和射频芯片要求一整个“命令 + 数据”期间 CS 始终有效。
 * 硬件 STE/CS 在某些配置下可能按字节释放，所以比赛现场更推荐把 CS 配成普通
 * Digital Output，由本模块明确控制事务边界。若器件没有 CS，或你确认硬件 STE
 * 行为符合手册，可以把 cs.port=NULL、cs.pin=0，本模块就不会操作 CS。
 *
 * SPI 是全双工总线
 * ----------------
 * 每发送一个字节，RX FIFO 都会同时收到一个字节；即使调用 write()，实现也必须
 * 把这些无用数据读走，否则长帧会让 RX FIFO 溢出。read() 则通过发送 dummy_tx
 * 产生 SCLK。transfer() 可同时提供 tx/rx，也允许二者指向同一个缓冲区。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 SPI，Mode 选择 Controller；
 * 2. Data Size 选择 8 bit，关闭 Packing；
 * 3. 根据芯片手册设置 CPOL/CPHA（常说的 Mode 0~3）、MSB/LSB first 和 SCLK；
 * 4. 配置 SCLK、PICO/MOSI；需要读回时再配置 POCI/MISO；
 * 5. 推荐另建一个 GPIO Digital Output 作为 CS，初始值设为非有效电平；
 * 6. 本阻塞框架不需要 SPI 中断和 DMA。
 *
 * SysConfig 生成的宏名取决于实例名。假设实例名为 SPI_BUS、CS GPIO 名为
 * GPIO_SPI_CS，接入形式通常如下：
 *
 *     static const rabi_spi_t s_spi = {
 *         .instance = SPI_BUS_INST,
 *         .cs = {GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN},
 *         .cs_active_low = true,
 *         .dummy_tx = 0xff,
 *         .poll_limit = 100000U,
 *         .cs_setup_cycles = CPUCLK_FREQ / 1000000U,
 *         .cs_hold_cycles = CPUCLK_FREQ / 1000000U,
 *     };
 *
 *     rabi_system_init();
 *     rabi_spi_init(&s_spi);
 *
 * 面对陌生 SPI 芯片
 * ------------------
 * 先从数据手册确认六件事：电压、最大 SCLK、SPI Mode、位序、CS 帧边界、寄存器
 * 地址中是否夹带读写位/自增位。然后新建 rabi_xxx.h/.c，在私有函数里组帧：
 *
 *     uint8_t command = REGISTER_ADDRESS | READ_BIT;
 *     rabi_spi_write_then_read(&s_spi, &command, 1, data, data_length);
 *
 * 写寄存器则通常把“命令、地址、数据”放进一个小数组后调用 rabi_spi_write()。
 * 不要把芯片寄存器定义塞进 rabi_spi.c，这样换题时基础层仍然可复用。
 *
 * 使用边界
 * --------
 * - 这是主循环/事件回调使用的同步阻塞接口，不要在 SysTick ISR 中调用；
 * - poll_limit 是“连续空转次数”而不是精确微秒，作用是避免断线时永久卡死；
 * - 不加锁、不可重入，同一个 SPI 实例不能被中断和主循环同时操作；
 * - 大数据量、高采样率或严格无间隙传输应改用 FIFO 中断/DMA；
 * - 只支持 SysConfig 已配置好的 8-bit Controller 模式。
 */

typedef struct
{
    GPIO_Regs *port;
    uint32_t pin;
} rabi_spi_cs_t;

typedef struct
{
    SPI_Regs *instance;

    /* 两项同时为 0 表示不使用手动 CS；否则 pin 必须是单个 DL_GPIO_PIN_x。 */
    rabi_spi_cs_t cs;
    bool cs_active_low;

    /* 只读事务期间为产生 SCLK 而发送的填充值，常见选择为 0xff 或 0x00。 */
    uint8_t dummy_tx;

    /* 每个等待点允许连续轮询的最大次数，必须大于 0。 */
    uint32_t poll_limit;

    /* CS 生效后、首个时钟前，以及末个时钟后、CS 释放前的 CPU 忙等周期数。 */
    uint32_t cs_setup_cycles;
    uint32_t cs_hold_cycles;
} rabi_spi_t;

/* 检查 SysConfig 结果，并把手动 CS 设置为非有效电平。 */
rabi_err_t rabi_spi_init(const rabi_spi_t *spi);

/*
 * 同步全双工传输。tx 或 rx 可以有一个为 NULL，但不能同时为 NULL。
 * tx=NULL 时发送 dummy_tx；rx=NULL 时仍会读空 RX FIFO，只是不保存数据。
 */
rabi_err_t rabi_spi_transfer(
    const rabi_spi_t *spi,
    const uint8_t *tx,
    uint8_t *rx,
    size_t length);

rabi_err_t rabi_spi_write(
    const rabi_spi_t *spi, const uint8_t *data, size_t length);

rabi_err_t rabi_spi_read(
    const rabi_spi_t *spi, uint8_t *data, size_t length);

/*
 * 在同一个 CS 有效窗口内先发送 command，再发送 dummy_tx 并接收 data。
 * 适合绝大多数“发寄存器地址，然后连续读 N 字节”的传感器、ADC 和 Flash。
 */
rabi_err_t rabi_spi_write_then_read(
    const rabi_spi_t *spi,
    const uint8_t *command,
    size_t command_length,
    uint8_t *data,
    size_t data_length);

#if defined(__cplusplus)
}
#endif
