#ifndef __DAC8571_H
#define __DAC8571_H

#include "main.h"   // 引入 F407 HAL 库的核心头文件
#include <stdbool.h>
#include <stdint.h>

/* 参考电压 单位为mV */
#define VREF 5000.0f
/* 最大电压 单位为V */
#define VOLTAGE_MAX 5.0f
/* 最小电压 单位为V */
#define VOLTAGE_MIN 0.0f

/**
 * @brief DAC8571 控制寄存器 (保留了商家优秀的联合体和位域写法)
 */
typedef union DAC8571_ControlRegister {
    uint8_t value;  // 改为 uint8_t 以完美适配 HAL 库的发送缓冲数组
    struct bits
    {
        uint8_t pd0 : 1;
        uint8_t reserved_c1 : 1;
        uint8_t brcsel : 1;
        uint8_t reserved_c3 : 1;
        uint8_t load0 : 1;        // 置1时表示直接更新DAC寄存器并输出
        uint8_t load1 : 1;
        uint8_t reserved_c6 : 1;
        uint8_t reserved_c7 : 1;
    } bits;
} dac8571_control_reg_t;

/**
 * @brief DAC8571 模块应用层初始化
 * @note 底层的 I2C 时钟和 GPIO 初始化已由 CubeMX 的 MX_I2C1_Init() 完成。
 * 这里强制执行一次输出 0V，确保单片机复位瞬间，DAC 输出安全电平，防止冲击后级电路。
 */
void DAC8571_Init(void);

/**
 * @brief DAC8571 设置直流电压输出
 * @param data 期望输出的模拟电压值（单位：V）。例如输入 0.3 即代表要求输出 300mV。
 */
void DAC8571_SetDirectCurrent(double data);

#endif /* __DAC8571_H */
