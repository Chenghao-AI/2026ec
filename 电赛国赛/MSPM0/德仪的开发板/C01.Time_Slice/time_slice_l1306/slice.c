/*
 * slice.c
 *
 *  Created on: 2024年1月21日
 *      Author: junying
 */

#include "task_main.h"
#include "ti_msp_dl_config.h"

//SysTick中断服务程序，每10ms中断一次
void SysTick_Handler(void)
{
    // 在中断中调用次函数判断任务标志
    uint8_t index = 0;

    // 循环判断
    for (index = 0; index < TASK_NUM; index++)
    {
        // 判断计时器是否到时间
        if (schedule_task[index].run_timer)    //不为0
        {
            // 计时器减1
            schedule_task[index].run_timer--;
            //判断计时器是否到时间
            if (0 == schedule_task[index].run_timer)
            {
                // 恢复倒计时器的时间
                schedule_task[index].run_timer = schedule_task[index].interval_time;
                // 任务标志置1
                schedule_task[index].run_sign = 1;
            }
        }
    }
}

int main(void)
{
    uint8_t index = 0;
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
    NVIC_ClearPendingIRQ(UART_0_INST_INT_IRQN);     //Clear the IRQ Flag
    NVIC_EnableIRQ(UART_0_INST_INT_IRQN);           //Enable the Received Interrupt

    while (1) {
        // 循环判断任务
        for (index = 0; index < TASK_NUM; index++)
        {
            if (schedule_task[index].run_sign)
            {
                // 清除任务标志
                schedule_task[index].run_sign = 0;
                // 使用函数指针，执行任务，
                schedule_task[index].task_func();
            }
        }

    }
}
