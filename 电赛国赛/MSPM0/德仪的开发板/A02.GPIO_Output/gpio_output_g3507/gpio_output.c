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
#define DELAY (16000000)    //—”≥Ÿ0.5√Î

//All LEDs combind to 5bits
//input-val    bit4    bit3    bit2    bit1         bit0
//Func         LED_B   LED_G   LED_R   BaseBrd LED  CoreBrd LED
//Pins         PA13    PA12    PA11    PA10      PA0
void LedOutput(unsigned char val)
{
    if(val & 0x1)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN);
    if(val & 0x2)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_PIN);
    if(val & 0x4)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_R_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_R_PIN);
    if(val & 0x8)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_G_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_G_PIN);
    if(val & 0x10)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_B_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_B_PIN);
}

int main(void)
{
    unsigned char cnt = 0;
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: ALL LEDs OFF */
    LedOutput(0);   //All LED OFF

    while (1) {
        /*
         * Call togglePins API to flip the current value of LEDs 1-3. This
         * API causes the corresponding HW bits to be flipped by the GPIO HW
         * without need for additional R-M-W cycles by the processor.
         */
        delay_cycles(DELAY);
        LedOutput(cnt++);   //LEDs changed on bit
    }
}
