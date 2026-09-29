/* Rabi 备用模块：MSPM0 硬件 I2C Controller 阻塞事务接口。 */
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_i2c.h>
#include "core/rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * 轻量硬件 I2C 框架
 * =================
 *
 * 本模块为 MSPM0 I2C Controller 提供带超时的轮询式写、读和 repeated-start
 * 写后读。它支持 7-bit 地址和每阶段 1~4095 字节，不使用中断、DMA 或动态内存。
 * 具体器件驱动负责解释寄存器地址、大小端、数据含义和上电延时。
 *
 * 典型寄存器读取波形
 * ------------------
 *
 *     START + Addr(W) + Register + RESTART + Addr(R) + Data... + STOP
 *
 * 这种事务必须调用 rabi_i2c_write_read()。若分别调用 write() 和 read()，中间会
 * 出现 STOP，有些器件仍能工作，但不能假定所有传感器都接受这种波形。
 *
 * SysConfig 配置
 * -------------
 * 1. 添加 I2C，选择 Controller 模式和 Standard/Fast 等目标速率；
 * 2. 分配 SCL、SDA，引脚必须使用开漏功能；
 * 3. 总线必须有上拉电阻。LaunchPad 或模块自带上拉不代表所有接法都已经具备；
 * 4. 只有 3.3 V 器件才能直接相连，5 V I2C 需要确认电平或加双向电平转换；
 * 5. 本阻塞框架不需要打开 I2C 中断或 DMA。
 *
 * 建议先用 100 kHz 验证地址和波形，再提高到 400 kHz。总线速度上不去时，优先
 * 检查上拉阻值、线长、模块并联电容和电平转换器，不要只改代码里的超时次数。
 *
 * 最小接入示例
 * ------------
 * 假设 SysConfig 实例名为 I2C_BUS：
 *
 *     static const rabi_i2c_t s_i2c = {
 *         .instance = I2C_BUS_INST,
 *         .poll_limit = 100000U,
 *         .start_delay_cycles = CPUCLK_FREQ / 1000000U, // 建议至少约 1 us
 *     };
 *
 *     uint8_t who_am_i_reg = 0x0f;
 *     uint8_t who_am_i;
 *
 *     rabi_system_init();
 *     rabi_i2c_init(&s_i2c);
 *     rabi_i2c_write_read(
 *         &s_i2c, 0x1e, &who_am_i_reg, 1, &who_am_i, 1);
 *
 * start_delay_cycles 用于满足 MSPM0 I2C 启动事务后的硬件时序/勘误规避要求。
 * 它是 CPU 周期数，不是 I2C 时钟数；不确定时用约 1 us 是偏保守但方便的起点。
 *
 * 面对陌生 I2C 芯片
 * ------------------
 * 先确认：7-bit 地址、地址选择脚、电源电压、最大 SCL、寄存器地址是 8/16 bit、
 * 多字节是否自动递增、数据大小端、上电后首次通信前是否要等待。特别注意：手册
 * 常把“8-bit 写地址/读地址”写成 0xA0/0xA1，而本接口要传去掉最低读写位后的
 * 7-bit 地址 0x50，不能直接传 0xA0。
 *
 * 然后新建 rabi_xxx.h/.c，把地址和寄存器帧封装在具体芯片层。例如 16-bit
 * 大端寄存器地址应先组织为：
 *
 *     uint8_t reg_bytes[2] = {reg >> 8, reg & 0xff};
 *     rabi_i2c_write_read(bus, address, reg_bytes, 2, data, length);
 *
 * 使用边界与故障判断
 * ------------------
 * - 所有接口同步阻塞，适合主循环/事件回调，不要从 SysTick ISR 调用；
 * - poll_limit 是连续无进展轮询次数，不是精确时间；
 * - NACK/总线错误返回 RABI_ERR_FAIL，仲裁丢失返回 RABI_ERR_BUSY；
 * - SDA 被从机永久拉低时，硬件事务可能超时。先检查供电/上拉并复位从机；需要
 *   “手动给 9 个 SCL”恢复时，应另写 GPIO/IOMUX 恢复代码，不应塞进普通事务；
 * - 本模块不加锁、不可重入；大量连续采样应改用中断或 DMA；
 * - 不支持 10-bit 地址、Target 模式、SMBus PEC 和多 Controller 自动重试。
 */

typedef struct
{
    I2C_Regs *instance;

    /* 每个等待点允许连续无进展轮询的最大次数，必须大于 0。 */
    uint32_t poll_limit;

    /* startControllerTransfer 后的 CPU 忙等周期数，建议配置为约 1 us。 */
    uint32_t start_delay_cycles;
} rabi_i2c_t;

/* 检查实例是否已经由 SysConfig 配成已上电、已使能的 Controller。 */
rabi_err_t rabi_i2c_init(const rabi_i2c_t *i2c);

/* 自动产生 START 和 STOP。 */
rabi_err_t rabi_i2c_write(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    const uint8_t *data,
    size_t length);

/* 自动产生 START 和 STOP。 */
rabi_err_t rabi_i2c_read(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    uint8_t *data,
    size_t length);

/*
 * 先写 tx，再在不释放总线的情况下产生 repeated START 并读取 rx，最后 STOP。
 * tx_length 和 rx_length 都必须大于 0。
 */
rabi_err_t rabi_i2c_write_read(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    const uint8_t *tx,
    size_t tx_length,
    uint8_t *rx,
    size_t rx_length);

#if defined(__cplusplus)
}
#endif
