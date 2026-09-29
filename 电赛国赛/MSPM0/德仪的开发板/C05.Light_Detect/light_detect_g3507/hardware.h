/*
 * hardware.h
 *
 *  Created on: 2024年3月23日
 *      Author: junying
 */

#ifndef HARDWARE_H_
#define HARDWARE_H_

#include "ti_msp_dl_config.h"

//定义按键值
#define KEY1VAL() !(DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY1_PIN))
#define KEY2VAL() !(DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY2_PIN))
#define KEY3VAL() !(DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY3_PIN))
#define KEY4VAL() !(DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY4_PIN))

//定义LED输出函数
#define SetLed(n) ((n)?(DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN)):(DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN)))
#define ToggleLed() (DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN ))
#define SetRed(n) ((n)?(DL_GPIO_clearPins(GPIO_RGB_PORT, GPIO_RGB_RED_PIN)):(DL_GPIO_setPins(GPIO_RGB_PORT, GPIO_RGB_RED_PIN)))
#define SetGreen(n) ((n)?(DL_GPIO_clearPins(GPIO_RGB_PORT, GPIO_RGB_GREEN_PIN)):(DL_GPIO_setPins(GPIO_RGB_PORT, GPIO_RGB_GREEN_PIN)))
#define SetBlue(n) ((n)?(DL_GPIO_clearPins(GPIO_RGB_PORT, GPIO_RGB_BLUE_PIN)):(DL_GPIO_setPins(GPIO_RGB_PORT, GPIO_RGB_BLUE_PIN)))
//设置RGB灯状态，参数n的后3bit是RGB的状态值（bit0-R bit1-G  bit2-B），0-灭 1-亮
void SetRGB(uint8_t n);

//硬件初始化函数
void hardware_init(void);

//读取ADC采样值
//返回值：false - 没有转换完成    true - 读取成功，结果在 *pVal
bool getAdcValue(uint16_t *pVal);

//设置OPA放大系数（输入参数为0~5）
void opa_ChgGain(uint8_t val);
//缺省放大系数定义
#define GainDefault 1

//设置DAC的偏置值，参数val是输出电源毫伏值（范围0~3300）
void dac_SetVal(uint32_t val);
//缺省偏置值定义
#define ShiftDefault    1500

#endif /* HARDWARE_H_ */
