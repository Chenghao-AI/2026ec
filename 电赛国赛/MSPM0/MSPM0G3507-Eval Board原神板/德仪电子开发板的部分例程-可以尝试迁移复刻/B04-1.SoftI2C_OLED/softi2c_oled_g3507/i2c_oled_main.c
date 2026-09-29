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

// HardwareLab例程：采用I2C外设驱动OLED测试例程

#include "ti_msp_dl_config.h"
#include "string.h"
#include "printf.h"     //User Defined Embeded printf Func
#include "uart.h"
#include "oled.h"
#include "bmp.h"


int main(void)
{
    unsigned short times = 0;
    unsigned short len;
    unsigned short n;
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
    NVIC_ClearPendingIRQ(UART_0_INST_INT_IRQN);     //Clear the IRQ Flag
    NVIC_EnableIRQ(UART_0_INST_INT_IRQN);           //Enable the Received Interrupt

    printf("Start Init\r\n");
    uint8_t t=' ';
    OLED_Init();
    OLED_ColorTurn(0);
    OLED_DisplayTurn(0);
    printf("End of Init\r\n");

    while (1) {
        printf("Screen 1\r\n");
        OLED_ShowPicture(0,0,128,64,BMP2,1);
        OLED_Refresh();
        delay_ms(2000);
        OLED_Clear();
        printf("Screen 2\r\n");
        OLED_ShowChinese(0,0,0,16,1);//德
        OLED_ShowChinese(18,0,1,16,1);//研
        OLED_ShowChinese(36,0,2,16,1);//电
        OLED_ShowChinese(54,0,3,16,1);//科
        OLED_ShowChinese(72,0,6,16,1);//实
        OLED_ShowChinese(90,0,7,16,1);//验
        OLED_ShowChinese(108,0,8,16,1);//室
        printf("Screen 3\r\n");
        OLED_ShowString(8,16,(u8 *)" HardwareLab ",16,1);
        OLED_ShowString(20,32,(u8 *)"2024/01/11",16,1);
        OLED_ShowString(0,48,(u8 *)"ASCII:",16,1);
        OLED_ShowString(63,48,(u8 *)"CODE:",16,1);
        OLED_ShowChar(48,48,t,16,1);//显示ASCII×码
        printf("Screen 4\r\n");
        t++;
        if(t>'~')t=' ';
        OLED_ShowNum(103,48,t,3,16,1);
        OLED_Refresh();
        delay_ms(2000);
        OLED_Clear();
        OLED_ShowChinese(0,0,1,16,1);  //16*16 研
        OLED_ShowChinese(16,0,0,24,1); //24*24 研
        OLED_ShowChinese(24,20,0,32,1);//32*32 研
        OLED_ShowChinese(64,0,0,64,1); //64*64 研
        printf("Screen 5\r\n");
        OLED_Refresh();
        delay_ms(2000);
        OLED_Clear();
        printf("Screen 6\r\n");
        OLED_ShowString(0,0,(u8 *)"ABC",8,1);//6*8 “ABC”
        OLED_ShowString(0,8,(u8 *)"ABC",12,1);//6*12 “ABC”
        OLED_ShowString(0,20,(u8 *)"ABC",16,1);//8*16 “ABC”
        OLED_ShowString(0,36,(u8 *)"ABC",24,1);//12*24 “ABC”
        OLED_Refresh();
        delay_ms(2000);
        printf("Screen 7\r\n");
        OLED_ScrollDisplay(9,4,1,3);    //左移循环显示3整屏
        printf("Screen 8\r\n");

        DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
        printf("Screen 9\r\n");
    }
}

