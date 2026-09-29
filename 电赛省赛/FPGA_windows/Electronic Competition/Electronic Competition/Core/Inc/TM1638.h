/**
  ******************************************************************************
  * @file    tm1638.h
  * @brief   TM1638 8-Digit Display + 8-LED + 8-Key Module Driver Header
  *          Target MCU: STM32F4 Series (STM32F407ZET6)
  *          IDE/HAL: STM32CubeIDE / STM32 HAL
  *          Pin Mapping:
  *            - STB : PE10
  *            - CLK : PE11
  *            - DIO : PE12
  ******************************************************************************
  */

#ifndef __TM1638_H
#define __TM1638_H

#ifdef __cplusplus
extern "C" {
#endif

#include "main.h"

/* =================================================================================
 * Hardware Pin Configurations (可通过修改引脚宏快速更换引脚)
 * ================================================================================= */
#define TM1638_STB_GPIO_PORT    GPIOE
#define TM1638_STB_PIN          GPIO_PIN_10

#define TM1638_CLK_GPIO_PORT    GPIOE
#define TM1638_CLK_PIN          GPIO_PIN_11

#define TM1638_DIO_GPIO_PORT    GPIOE
#define TM1638_DIO_PIN          GPIO_PIN_12

/* =================================================================================
 * TM1638 Command Definitions
 * ================================================================================= */
#define TM1638_CMD_DATA_SET     0x40    // 数据命令：0x40(自动地址加1), 0x44(固定地址)
#define TM1638_CMD_READ_KEYS    0x42    // 读键扫数据命令
#define TM1638_CMD_ADDR_SET     0xC0    // 地址命令：起始地址0xC0
#define TM1638_CMD_DISP_CTRL    0x80    // 显示控制命令：0x80(关显示), 0x88~0x8F(开显示+8级亮度)

/* =================================================================================
 * Function Prototypes
 * ================================================================================= */

/**
  * @brief  初始化TM1638模块GPIO与显示状态
  */
void TM1638_Init(void);

/**
  * @brief  设置显示亮度 (0~7级)
  * @param  brightness: 0 (最低) 到 7 (最高)
  */
void TM1638_SetBrightness(uint8_t brightness);

/**
  * @brief  向TM1638特定地址写入一个字节数据
  * @param  addr: 显存地址 (0x00 ~ 0x0F)
  * @param  data: 写入的数据
  */
void TM1638_WriteData(uint8_t addr, uint8_t data);

/**
  * @brief  控制单个LED状态 (D1 ~ D8)
  * @param  led_num: LED编号 (1 ~ 8)
  * @param  state: 0为灭，1为亮
  */
void TM1638_SetLED(uint8_t led_num, uint8_t state);

/**
  * @brief  控制全部8个LED状态
  * @param  led_mask: 按位控制D1~D8 (Bit0对应D1, Bit7对应D8)
  */
void TM1638_SetAllLEDs(uint8_t led_mask);

/**
  * @brief  在指定位置显示数码管段码
  * @param  pos: 数码管位置 (0 ~ 7，从左到右)
  * @param  seg: 段码数据
  */
void TM1638_DisplaySeg(uint8_t pos, uint8_t seg);

/**
  * @brief  在指定位置显示十六进制数字 (0~F)
  * @param  pos: 数码管位置 (0 ~ 7)
  * @param  num: 显示数字 (0 ~ 15)
  * @param  show_dp: 是否显示小数点 (1显示, 0不显示)
  */
void TM1638_DisplayHex(uint8_t pos, uint8_t num, uint8_t show_dp);

/**
  * @brief  显示整型数字
  * @param  num: 要显示的整数 (-9999999 ~ 99999999)
  */
void TM1638_DisplayInt(int32_t num);

/**
  * @brief  清空数码管和LED显示
  */
void TM1638_Clear(void);

/**
  * @brief  读取按键状态字节 (返回8个按键的位图，Bit0对应S1 ... Bit7对应S8)
  * @retval uint8_t: 按键位图，按下为1，未按下为0
  */
uint8_t TM1638_ReadKeys(void);

/**
  * @brief  获取当前按下的单键编号 (1~8)，无按键返回0
  * @retval uint8_t: 1~8 表示按下的按键S1~S8，0表示无按键
  */
uint8_t TM1638_GetKeyNum(void);

#ifdef __cplusplus
}
#endif

#endif /* __TM1638_H */
