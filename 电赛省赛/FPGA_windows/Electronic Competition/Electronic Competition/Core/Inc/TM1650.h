//-----------------------------------------------------------------
// 头文件名: TM1650.h
// 适  用: STM32F407ZET6 - HAL库环境 (引脚 PB3 / PB4)
//-----------------------------------------------------------------

#ifndef __TM1650_H__
#define __TM1650_H__

#include "main.h"  // 引入 HAL 库核心头文件

// 字库与键值映射数组
static uint8_t s_7number[16] = {0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F,0x77,0x7C,0x39,0x5E,0x79,0x71};
static uint32_t key_number[7][4] = {11,12,13,14,21,22,23,24,31,32,33,34,41,42,43,44,51,52,53,54,61,62,63,64,71,72,73,74};
static uint8_t key_numberH[7][4] = {0x44,0x45,0x46,0x47,\
                                    0x4C,0x4D,0x4E,0x4F,\
                                    0x54,0x55,0x56,0x57,\
                                    0x5C,0x5D,0x5E,0x5F,\
                                    0x64,0x65,0x66,0x67,\
                                    0x6C,0x6D,0x6E,0x6F,\
                                    0x74,0x75,0x76,0x77,};

// 引脚端口定义
#define TM1650_GPIO_PORT GPIOB

// 硬件引脚宏定义
#define TM1650_SCL_pin GPIO_PIN_5
#define TM1650_SDA_pin GPIO_PIN_4

// 核心：使用 HAL 库的 GPIO 读写 API 映射
#define TM1650_SCL_H    HAL_GPIO_WritePin(TM1650_GPIO_PORT, TM1650_SCL_pin, GPIO_PIN_SET)
#define TM1650_SCL_L    HAL_GPIO_WritePin(TM1650_GPIO_PORT, TM1650_SCL_pin, GPIO_PIN_RESET)
#define TM1650_SDA_H    HAL_GPIO_WritePin(TM1650_GPIO_PORT, TM1650_SDA_pin, GPIO_PIN_SET)
#define TM1650_SDA_L    HAL_GPIO_WritePin(TM1650_GPIO_PORT, TM1650_SDA_pin, GPIO_PIN_RESET)
#define READ_SDA        HAL_GPIO_ReadPin(TM1650_GPIO_PORT, TM1650_SDA_pin)

// 外部调用的函数声明
void DisplayNumber_4BitDig(unsigned short num);
void TM1650_Init(void);
void DisplayNumber_HexDig(unsigned short num);
unsigned char TM1650_Read_KEY(void);
uint32_t TM1650_Gte_KEY(void); // 保持原厂拼写，防止 main.c 报错

#endif
