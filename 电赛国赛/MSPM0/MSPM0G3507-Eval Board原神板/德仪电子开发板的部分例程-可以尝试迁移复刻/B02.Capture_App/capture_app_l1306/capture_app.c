/*
 * Copyright (c) 2023, Texas Instruments Incorporated
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * *  Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * *  Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * *  Neither the name of Texas Instruments Incorporated nor the names of
 *    its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "ti_msp_dl_config.h"
#include "printf.h"

volatile uint32_t gCaptureOverflowC0Cnt;
volatile uint32_t gCaptureOverflowC1Cnt;
volatile uint32_t gCaptureCnt;
volatile uint32_t gCaptureCntLast;
volatile bool gCheckCaptures;
uint32_t gLoadValue;

// UART Received Buffer, Max Length = LineLength
#define LineLength  64
volatile uint8_t LineBuffer[LineLength];
void _putchar(char character)   //为了提供printf的底层函数
{
  // send char to console etc.
    DL_UART_Main_transmitDataBlocking(UART_0_INST, character);
}

// Flag for the UART Received Status
// Bit15 - Finished for Received One Line
// Bit14 - Got '\r' Flag
// Bit13 ~ Bit0 - The Length of the Received Char
volatile uint16_t UART_RX_STA = 0;

int main(void)
{
    volatile static uint32_t pwmPeriod;
    volatile static uint32_t pwmDuty;

    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    gLoadValue = DL_TimerG_getLoadValue(CAPTURE_0_INST);

    /* Initialize capture global states */
    gCaptureOverflowC1Cnt = 0;
    gCaptureOverflowC0Cnt = 0;
    gCaptureCnt = 0;
    gCaptureCntLast = 0;
    gCheckCaptures = false;

    printf("Start Capture the PWM waveform\r\n");
    /*
     * Forcing timers to halt immediately to prevent timers getting out of sync
     * when code is halted
     */
    DL_TimerG_setCoreHaltBehavior(
        CAPTURE_0_INST, DL_TIMER_CORE_HALT_IMMEDIATE);
    DL_TimerG_setCoreHaltBehavior(PWM_0_INST, DL_TIMER_CORE_HALT_IMMEDIATE);

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );

    NVIC_EnableIRQ(CAPTURE_0_INST_INT_IRQN);    //Enable the interrupt of Capture
    DL_TimerG_startCounter(CAPTURE_0_INST);     //Start Capture
    NVIC_EnableIRQ(PWM_0_INST_INT_IRQN);    //Enable the interrupt of PWM
    DL_TimerG_startCounter(PWM_0_INST);     //Start PWM Signal Generate

    while (1) {
        while (false == gCheckCaptures) {
            __WFE();
        }
        gCheckCaptures = false;

        /*
         * Calculate PWM period and PWM duty cycle. IMPORTANT: These calculation
         * assume timer is running in DOWN counting mode
         */
        //周期计算：总溢出次数 * 溢出周期clk数 + 上次保留值 - 当前捕获值（减计数下的计算公式）
        pwmPeriod = gLoadValue*gCaptureOverflowC1Cnt + gCaptureCntLast - gCaptureCnt;
        //占空比计算：高电平溢出次数 * 溢出周期clk数 + 上次保留值 - 当前高电平结束捕获值（减计数下的计算公式）
        pwmDuty = (gLoadValue * gCaptureOverflowC0Cnt + gCaptureCntLast -
                DL_TimerG_getCaptureCompareValue(CAPTURE_0_INST, DL_TIMER_CC_0_INDEX) )* 100 /
                        pwmPeriod;
        gCaptureOverflowC1Cnt = 0;  //溢出统计清零

        printf("The pwmPeriod = %d\t with Duty = %d\r\n", pwmPeriod, pwmDuty);

        DL_GPIO_togglePins(GPIO_LEDS_PORT,
            GPIO_LEDS_USER_LED_1_PIN );     //Toggle the LED on Core Board

        //__BKPT(0);
    }
}

void PWM_0_INST_IRQHandler(void)
{
    static unsigned int cnt = 0;    //Interrupt occur times
    static unsigned int ccr = 7470;  //Default CCR
    switch (DL_TimerG_getPendingInterrupt(PWM_0_INST)) {
        case DL_TIMERG_IIDX_LOAD:
            cnt ++;
            if(cnt > 8)      //About 8 Sec
            {
                cnt = 0;
                ccr -= 300;      //改变占空比，减计数情况下，CCR越小占空比越大
                if(ccr < 300)
                    ccr = 14700;  //back the Max CCR
                //Effect the CCR Value
                DL_TimerG_setCaptureCompareValue(PWM_0_INST, ccr, DL_TIMER_CC_0_INDEX);
                printf("Set CCR=%d\r\n", (100-(ccr*100/15000)));    //切换占空比，此时测量可能导致周期和占空比均不稳定
            }
            break;
        default:
            break;
    }
}

void CAPTURE_0_INST_IRQHandler(void)
{
    switch (DL_TimerG_getPendingInterrupt(CAPTURE_0_INST)) {
        case DL_TIMERG_IIDX_CC0_DN: //发生高电平捕获事件，保留当前的溢出数
            gCaptureOverflowC0Cnt = gCaptureOverflowC1Cnt;
            break;
        case DL_TIMERG_IIDX_CC1_DN: //发生周期捕获事件，读取捕获值，更新上次捕获保留值
            gCaptureCntLast = gCaptureCnt;
            gCaptureCnt = DL_TimerG_getCaptureCompareValue(
                CAPTURE_0_INST, DL_TIMER_CC_1_INDEX);
            gCheckCaptures = true;  //指示有新的完整捕获事件
            break;
        case DL_TIMERG_IIDX_ZERO:   //溢出事件，溢出统计累计
            gCaptureOverflowC1Cnt ++;
            break;
        default:
            break;
    }
}

volatile uint8_t gRxData = 0;

void UART_0_INST_IRQHandler(void)   //UART接收中断，识别回车符处理
{
    switch (DL_UART_Main_getPendingInterrupt(UART_0_INST)) {
        case DL_UART_MAIN_IIDX_RX:
            gRxData = DL_UART_Main_receiveData(UART_0_INST);
            if((UART_RX_STA & 0x8000)==0)  //Receive Not Finished
            {
                if(UART_RX_STA&0x4000) //Received 0x0D('\r')
                {
                    if(gRxData!=0x0a)UART_RX_STA=0;   //Received Error
                    else UART_RX_STA|=0x8000;  //Received Finished
                }
                else //Not Got 0x0D('\r')
                {
                    if(gRxData==0x0d)UART_RX_STA|=0x4000;
                    else
                    {
                        LineBuffer[UART_RX_STA&0X3FFF]=gRxData ;    // Got One Valid Char
                        UART_RX_STA++;
                        if(UART_RX_STA>(LineLength-1))UART_RX_STA=0;   //Received Error, Restart Again
                    }
                }
            }
            break;
        default:
            break;
    }
}

