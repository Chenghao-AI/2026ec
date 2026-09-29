#ifndef __PE4302_S_H
#define __PE4302_S_H

#include "main.h" // 必须包含 main.h 以引入 CubeMX 生成的引脚宏定义

// --- 模块枚举定义 ---
typedef enum {
    MODULE_1 = 0,
    MODULE_2 = 1
} PE4302_Target_t;

// --- 外部调用的API声明 ---
void PE4302_S_Init(void);
void PE4302_S_Set_Attenuation(PE4302_Target_t target_module, float db);

#endif // __PE4302_S_H
