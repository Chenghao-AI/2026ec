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

//Control LED on Coreboard ON/OFF
#define LedOnOff(n) (n)?(DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_PIN)):\
                (DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_PIN))
#define ToggleLed() DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_LED_PIN)

//Control CC-Tube DP-Segment ON/OFF
#define TubeDP(n)   (n)?(DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_DP_PIN)):\
                (DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_DP_PIN))
//Control CC-Tube Segment ON/OFF
//Input Val - unsigned char, bit6 ~ bit0
//  bit6    bit5    bit4    bit3    bit2    bit1    bit0
//  G       F       E       D       C       B       A
void TubeOut(unsigned char val)
{
    if(val & 0x40)
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_G_PIN);
    else
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_G_PIN);

    if(val & 0x20)
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_F_PIN);
    else
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_F_PIN);

    if(val & 0x10)
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_E_PIN);
    else
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_E_PIN);

    if(val & 0x08)
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_D_PIN);
    else
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_D_PIN);

    if(val & 0x04)
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_C_PIN);
    else
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_C_PIN);

    if(val & 0x02)
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_B_PIN);
    else
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_B_PIN);

    if(val & 0x01)
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_A_PIN);
    else
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_A_PIN);

}
unsigned char DispLib[16] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71};

int main(void)
{
    unsigned char cnt = 0;
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: Cube Display 0 */
    LedOnOff(0);    //Set LED Off
    TubeDP(0);      //Set DP Off
    TubeOut(DispLib[0]);    //Display Tube as '0'
    delay_cycles(DELAY);    //Delay 0.5S

    while (1) {
        /*
         * Call togglePins API to flip the current value of LEDs 1-3. This
         * API causes the corresponding HW bits to be flipped by the GPIO HW
         * without need for additional R-M-W cycles by the processor.
         */
        delay_cycles(DELAY);    //Delay 0.5 S
        if(cnt & 0x10)  //Control DP Dot ON or OFF due to bit8 in cnt
            TubeDP(1);
        else
            TubeDP(0);
        TubeOut(DispLib[ (cnt++) & 0x0F ]); //Display 0~F due to Display Lib
        delay_cycles(DELAY);    //Delay 0.5 S
        ToggleLed();    // Toggle LED on Core Board
    }
}
