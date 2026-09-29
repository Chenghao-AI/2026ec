/*
 * task_main.c
 *
 *  Created on: 2024年1月21日
 *      Author: junying
 */

#include "task_main.h"
#include "printf.h"     //User Defined Embeded printf Func
#include "uart.h"

//每秒UART打印任务
void TaskUartPntPer1S(void);

//每3秒UART打印任务
void TaskUartPntPer3S(void);

//UART接收内容检查
void TaskUartChk(void);

//LED闪烁任务，每500ms（50ticks）执行一次
void TaskLedFlash(void);

//创建任务配置
schedule_task_t schedule_task[] =
{
    {TaskUartPntPer1S, 100, 1, 0},    //task_1(函数名) 20 (执行周期) 20(计时器) 0(任务执行标志)
    {TaskUartPntPer3S, 300, 2, 0},
    {TaskUartChk, 10,  3, 0},
    {TaskLedFlash, 50,  4, 0},
};

//每秒UART打印任务
void TaskUartPntPer1S(void)
{
    static int cnt = 0;
    printf("This is Task 1 @ %d Sec from DY-HardwareLab\r\n", cnt);
    cnt ++;
}

void TaskUartPntPer3S(void)
{
    static int cnt = 0;
    printf("This is Task 2 @ %d Sec from DY-HardwareLab\r\n", cnt);
    cnt +=3;
}

void TaskUartChk(void)
{
    unsigned short len;
    unsigned short n;
    if(UART_RX_STA & 0x8000)    //check the received finish flag
    {
        len = UART_RX_STA & 0x3FFF; //Got the Length of the received
        printf("\r\nYou Send:\t\r\n");
        //Send the received Line
        for(n=0; n<len; n++)
            DL_UART_Main_transmitDataBlocking(UART_0_INST, LineBuffer[n]);

        printf("\r\n from DY-HardwareLab\r\n");
        UART_RX_STA = 0;    //Clear the Flag of the Received
    }
}

//LED闪烁任务，每500ms（50ticks）执行一次
void TaskLedFlash(void)
{
    //LED_1 翻转一次
    DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
}

