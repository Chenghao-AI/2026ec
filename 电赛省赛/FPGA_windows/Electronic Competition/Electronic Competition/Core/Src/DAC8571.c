#include "DAC8571.h"
#include "i2c.h"    // 引入 CubeMX 自动生成的 I2C 初始化头文件
#include <stdio.h>  // 引入 printf 所需的头文件 (用于报错输出)

// 声明外部的 I2C 句柄 (对应你 CubeMX 配置的 I2C1)
extern I2C_HandleTypeDef hi2c1;

/**
 * DAC8571_A0 由 A0 引脚的电平决定
 * 0: A0 引脚接 GND
 * 1: A0 引脚接 3.3V/5V
 */
#define DAC8571_A0 0

/* * I2C 8位写地址计算：
 * 默认基础地址是 0x98。A0 状态位占据的是第 1 位（而不是第 0 位的 R/W 位），因此必须是 << 1。
 */
static uint8_t m_dac8571_i2c_address = 0x98 | (DAC8571_A0 << 1);

/* * 废弃了原有的联合体位域写法。
 * 强制写入 0x10，表示直接加载数据更新 DAC 寄存器并输出，规避编译器编译差异。
 */
#define DAC_CONTROL_LOAD_BIT 0x10

/**
 * @brief DAC8571 设置直流电压输出
 * @param data 模拟量 单位 V
 */
void DAC8571_SetDirectCurrent(double data)
{
    // 1. 增加硬件保护限幅，防止由于传入参数异常导致满幅输出烧毁后级运放
    if (data > VOLTAGE_MAX) data = VOLTAGE_MAX;
    if (data < VOLTAGE_MIN) data = VOLTAGE_MIN;

    // 2. 将电压值转换为 16 位数字量
    // 公式: D = Vout / Vref * 65535
    uint16_t binary_voltage = (uint16_t)(data * 1000.0 / VREF * 0xFFFF);

    // 3. 组合 3 字节的数据帧：[控制字节] -> [高8位] -> [低8位]
    uint8_t data_buf[3];
    data_buf[0] = DAC_CONTROL_LOAD_BIT;
    data_buf[1] = (uint8_t)((binary_voltage >> 8) & 0xFF);
    data_buf[2] = (uint8_t)(binary_voltage & 0xFF);

    // 4. 调用 HAL 库阻塞发送函数，超时时间设为 50ms
    HAL_StatusTypeDef status = HAL_I2C_Master_Transmit(&hi2c1, m_dac8571_i2c_address, data_buf, 3, 50);

    // 5. 【极其关键的调试逻辑】错误捕获
    if (status != HAL_OK)
    {
        // ！！今晚调试时，请在下面这行代码前双击打上一个断点 (Breakpoint) ！！
        // 如果程序停在这里，说明 I2C 根本没有应答 (ACK)。
        // 此时去检查: 1. A0引脚电平与代码是否一致 2. 杜邦线是否松动 3. 稳压电源是否共地
        printf("I2C Transmit Error! Status: %d\r\n", status);
    }
}

/**
 * @brief DAC8571 初始化
 */
void DAC8571_Init(void)
{
    // 底层的 I2C 时钟和 GPIO 初始化已由 CubeMX 的 MX_I2C1_Init() 搞定。
    // 这里只需在上电时强制输出 0V，确保后级模拟电路处于已知安全状态。
    DAC8571_SetDirectCurrent(0.0);
}
