#ifndef _PE4302_H_
#define _PE4302_H_

#include "main.h" // 必须包含这个，因为引脚宏都在这里面！

/* * 注意：引脚定义(如 PE1_V1_Pin)已经由 CubeMX 自动在 main.h 中生成。
 * 这里直接声明设置衰减值的函数即可。
 */
void PE1_SetAttenuation(float db);
void PE2_SetAttenuation(float db);
void PE3_SetAttenuation(float db);

#endif
