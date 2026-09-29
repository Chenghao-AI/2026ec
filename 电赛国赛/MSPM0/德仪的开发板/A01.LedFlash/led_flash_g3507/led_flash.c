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

/* This results in approximately 0.5s of delay assuming 32MHz CPU_CLK */
#define DELAY (16000000)

int main(void)
{
    unsigned char cnt;
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: All LEDs Off */
    DL_GPIO_setPins(LED_PORT, LED_USER_PIN);
    DL_GPIO_setPins(RGB_PORT, RGB_LED_BLUE_PIN |
                    RGB_LED_RED_PIN |
                    RGB_LED_GREEN_PIN);
    cnt = 0;

    while (1) {
        /*
         * 本例程将LED1和LED2的R/G/B 等四个LED组成4bit，由cnt的低4bit直接控制亮灭
         * June Designed from SHNU.
         */
        delay_cycles(DELAY);
        cnt ++;
        if(cnt & 0x01)  // LED1 Cntl
            DL_GPIO_clearPins(LED_PORT, LED_USER_PIN);
        else
            DL_GPIO_setPins(LED_PORT, LED_USER_PIN);

        if(cnt & 0x02)  // RED Cntl
            DL_GPIO_clearPins(RGB_PORT, RGB_LED_RED_PIN);
        else
            DL_GPIO_setPins(RGB_PORT, RGB_LED_RED_PIN);

        if(cnt & 0x04)  // GREEN Cntl
            DL_GPIO_clearPins(RGB_PORT, RGB_LED_GREEN_PIN);
        else
            DL_GPIO_setPins(RGB_PORT, RGB_LED_GREEN_PIN);

        if(cnt & 0x08)  // BLUE Cntl
            DL_GPIO_clearPins(RGB_PORT, RGB_LED_BLUE_PIN);
        else
            DL_GPIO_setPins(RGB_PORT, RGB_LED_BLUE_PIN);

    }
}
