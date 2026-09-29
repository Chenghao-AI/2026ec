//-----------------------------------------------------------------
// ADF4351子程序的头文件
// 头文件名:adf4351.h
// 作    者:凌智电子
// 开始日期：	2019-02-07
// 完成日期：	2019-07-09
// 修改日期：	2019-07-09
// 当前版本: 	V1.0
// 历史版本:
//	  -V1.0:基本用法
//-----------------------------------------------------------------

#ifndef _ADF4351_H_
#define _ADF4351_H_

#include <stm32f10x.h>


#define ADF_CE_Set (GPIO_SetBits(GPIOD,GPIO_Pin_14))         
#define ADF_CE_Clr (GPIO_ResetBits(GPIOD,GPIO_Pin_14))

#define ADF_LE_Set (GPIO_SetBits(GPIOD,GPIO_Pin_12))         
#define ADF_LE_Clr (GPIO_ResetBits(GPIOD,GPIO_Pin_12))

#define ADF_DATA_Set (GPIO_SetBits(GPIOD,GPIO_Pin_10))         
#define ADF_DATA_Clr (GPIO_ResetBits(GPIOD,GPIO_Pin_10))

#define ADF_CLK_Set (GPIO_SetBits(GPIOD,GPIO_Pin_8))         
#define ADF_CLK_Clr (GPIO_ResetBits(GPIOD,GPIO_Pin_8))

//-----------------------------------------------------------------------------
// 函数声明
//-----------------------------------------------------------------------------

extern void ADF4351_Wdata(u32 date);
extern void ADF4351_Init(u32 date); 
extern void GPIO_AD4351_Init(void);
	
#endif
