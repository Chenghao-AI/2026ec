//-----------------------------------------------------------------
// 头文件名: adf4351.h
//-----------------------------------------------------------------

#ifndef _ADF4351_H_
#define _ADF4351_H_

#include "stm32f4xx_hal.h"

// 按照你的实物排针顺序：MUX(PD0) | CLK(PD1) | DATA(PD2) | LE(PD3) | CE(PD4)
#define ADF_CLK_Set   HAL_GPIO_WritePin(GPIOD, GPIO_PIN_1, GPIO_PIN_SET)
#define ADF_CLK_Clr   HAL_GPIO_WritePin(GPIOD, GPIO_PIN_1, GPIO_PIN_RESET)

#define ADF_DATA_Set  HAL_GPIO_WritePin(GPIOD, GPIO_PIN_2, GPIO_PIN_SET)
#define ADF_DATA_Clr  HAL_GPIO_WritePin(GPIOD, GPIO_PIN_2, GPIO_PIN_RESET)

#define ADF_LE_Set    HAL_GPIO_WritePin(GPIOD, GPIO_PIN_3, GPIO_PIN_SET)
#define ADF_LE_Clr    HAL_GPIO_WritePin(GPIOD, GPIO_PIN_3, GPIO_PIN_RESET)

#define ADF_CE_Set    HAL_GPIO_WritePin(GPIOD, GPIO_PIN_4, GPIO_PIN_SET)
#define ADF_CE_Clr    HAL_GPIO_WritePin(GPIOD, GPIO_PIN_4, GPIO_PIN_RESET)

//-----------------------------------------------------------------------------
// 函数声明
//-----------------------------------------------------------------------------
void GPIO_ADF4351_Init(void);
void ADF4351_Init(void);
void ADF4351_Wdata(uint32_t date);

// 【核心新增】全自动动态切频函数，支持任意频点输入
void ADF4351_SetFrequency(double target_freq_mhz);

#endif
