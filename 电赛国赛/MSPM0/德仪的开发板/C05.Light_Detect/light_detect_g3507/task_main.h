/*
 * task_main.h
 *
 *  Created on: 2024年1月21日
 *      Author: junying
 */

#ifndef TASK_MAIN_H_
#define TASK_MAIN_H_
#include "ti_msp_dl_config.h"

typedef struct
{
    void(*task_func)(void);   //函数指针
    uint16_t interval_time;   //执行时间间隔
    uint16_t run_timer;       //倒计时器
    uint8_t  run_sign;        //程序运行标志
} schedule_task_t;

extern schedule_task_t schedule_task[];
#define TASK_NUM 6  //(sizeof(schedule_task)/sizeof(schedule_task_t))

#endif /* TASK_MAIN_H_ */
