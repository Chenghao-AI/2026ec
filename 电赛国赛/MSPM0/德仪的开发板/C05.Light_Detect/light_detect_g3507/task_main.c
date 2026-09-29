/*
 * task_main.c
 *
 *  Created on: 2024年1月21日
 *      Author: junying
 */

#include "task_main.h"
#include "printf.h"     //User Defined Embeded printf Func
#include "uart.h"
#include "hardware.h"
#include "oled.h"

//每10秒UART打印任务
void TaskUartPntPer1S(void);

//每30秒UART打印任务
void TaskUartPntPer3S(void);

//UART接收内容检查
void TaskUartChk(void);

//LED闪烁任务，每500ms（50ticks）执行一次
void TaskLedFlash(void);

//按键检测逻辑，20ms执行一次
void TaskKeyChk(void);

//读取ADC值
void TaskAdcRead(void);

//创建任务配置
schedule_task_t schedule_task[] =
{
    {TaskUartPntPer1S, 1000, 1, 0},    //task_1(函数名) 20 (执行周期) 20(计时器) 0(任务执行标志)
    {TaskUartPntPer3S, 3000, 2, 0},    //task_1(函数名) 20 (执行周期) 20(计时器) 0(任务执行标志)
    {TaskKeyChk, 2, 1, 0},
    {TaskUartChk, 10,  3, 0},
    {TaskLedFlash, 50,  4, 0},
    {TaskAdcRead, 200,  4, 0},      //每2s读取一次ADC结果，实际转换在2s之前完成的
};

//每10秒UART打印任务
void TaskUartPntPer1S(void)
{
    static int cnt = 0;
    printf("This is Task 1 @ %d times from DY-HardwareLab\r\n", cnt);
    cnt ++;
}

//每30秒UART打印任务
void TaskUartPntPer3S(void)
{
    static int cnt = 0;
    printf("This is Task 2 @ %d times from DY-HardwareLab\r\n", cnt);
    cnt ++;
}

//Uart接收内容检查逻辑，目前做回环测试，后续可以插入命令处理逻辑
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
    static uint8_t cnt = 0;
    //LED_1 翻转一次
    ToggleLed();
    SetRGB(cnt++);
}

//偏置设置值
uint32_t SetThr = ShiftDefault;
//偏置按键保存值
uint32_t SaveThr = ShiftDefault;
//偏置按键输入值
uint32_t CurThr = ShiftDefault;

//增益挡位设置值
uint8_t SetGain = GainDefault;
//增益挡位保存值
uint8_t SaveGain = GainDefault;
//增益挡位输入值
uint8_t CurGain = GainDefault;

//按键处理任务，对四个按键进行处理
//KEY1/KEY2调整偏置值-SetThr
//KEY3/KEY4调整增益挡位值-SetGain
void TaskKeyChk(void)
{
    static uint8_t Key1Cnt = 0;
    static uint8_t Key2Cnt = 0;
    static uint8_t ThrCnt = 0;
    static uint8_t Key3Cnt = 0;
    static uint8_t Key4Cnt = 0;
    static uint8_t GainCnt = 0;
    uint32_t dacValue;

    //KEY1 监测逻辑
    if(KEY1VAL())
        Key1Cnt ++;
    else {
        if(Key1Cnt > 1) {   //去抖：大于40ms
            //发生按键的事件
            CurThr += 100;
            if(CurThr > 3300)
                CurThr = 3300;
            printf("One Key1 = %d\r\n", CurThr);
        }
        Key1Cnt = 0;
    }

    //KEY2 监测逻辑
    if(KEY2VAL())
        Key2Cnt ++;
    else {
        if(Key2Cnt > 1) {   //去抖：大于40ms
            if(CurThr < 200)
                CurThr = 0;
            else
                CurThr -= 100;
            printf("One Key2 = %d\r\n", CurThr);
        }
        Key2Cnt = 0;
    }

    //CurThr监测逻辑
    if(SaveThr == CurThr)
    {
        ThrCnt ++;
        if(ThrCnt > 250)
            ThrCnt = 250;
    }
    else
        ThrCnt = 0;
    //SetThr值变更处理
    if ((ThrCnt > 100)&&(SaveThr != SetThr))
    {
        //发生修改设置值的事件
        ThrCnt = 0;
        //刷新偏置值的设置
        printf("One Set Val %d -> %d\r\n", SetThr, SaveThr );
        SetThr = SaveThr;   //全局变量变化
        OLED_ShowNum(32,48,SetThr,4,16,1);  //刷新OLED屏幕
        dac_SetVal(SetThr); //设置DAC输出
        OLED_Refresh();     //显示刷新
    }
    if(SaveThr != CurThr)
    {
        //更新保存值
        SaveThr = CurThr;   //全局变量变化
        OLED_ShowNum(96,48,SaveThr,4,16,1); //刷新OLED屏幕
        OLED_Refresh();
    }

    //KEY3 监测逻辑
    if(KEY3VAL())
        Key3Cnt ++;
    else {
        if(Key3Cnt > 1) {   //去抖：大于40ms
            //发生按键的事件
            CurGain ++;
            if(CurGain > 4)
                CurGain = 5;
            printf("One Key3 = %d\r\n", CurGain);
        }
        Key3Cnt = 0;
    }

    //KEY4 监测逻辑
    if(KEY4VAL())
        Key4Cnt ++;
    else {
        if(Key4Cnt > 1) {   //去抖：大于40ms
            if(CurGain < 2)
                CurGain = 0;
            else
                CurGain --;
            printf("One Key4 = %d\r\n", CurGain);
        }
        Key4Cnt = 0;
    }

    //CurGain监测逻辑
    if(SaveGain == CurGain)
    {
        GainCnt ++;
        if(GainCnt > 250)
            GainCnt = 250;
    }
    else
        GainCnt = 0;
    //SetThr值变更处理
    if ((GainCnt > 100)&&(SaveGain != SetGain))
    {
        //发生修改设置值的事件
        GainCnt = 0;
        printf("One Set Val %d -> %d\r\n", SetGain, SaveGain );
        //变化挡位设置值
        SetGain = SaveGain; //全局变量变化
        OLED_ShowNum(48,32,SetGain,1,16,1); //OLED屏幕更新
        opa_ChgGain(SetGain);   //OPA放大挡位变化
        OLED_Refresh(); //OLED刷新
    }
    if(SaveGain != CurGain)
    {
        //挡位保存值变更
        SaveGain = CurGain; //全局变量变化
        OLED_ShowNum(104,32,SaveGain,1,16,1);   //OLED屏幕内容变化
        OLED_Refresh(); //OLED刷新
    }
}

//读取ADC值
void TaskAdcRead(void)
{
    uint16_t adc_val;
    if(getAdcValue(&adc_val))
    {
        printf("Get ADC= %d\r\n", adc_val);
        OLED_ShowNum(88,16,adc_val,4,16,1); //OLED屏幕内容变化
        OLED_Refresh(); //OLED刷新
    }
    else
        printf("ADC not ready\r\n");
}
