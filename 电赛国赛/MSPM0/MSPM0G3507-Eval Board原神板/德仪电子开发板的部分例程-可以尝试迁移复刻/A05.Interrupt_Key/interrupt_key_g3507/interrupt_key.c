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

/* This results in approximately 10ms of delay assuming 32MHz CPU_CLK */
#define DELAY (320000)  //10ms

unsigned char LedSta = 0;   // 0 - Off  1 - On  2 - Flashing

int main(void)
{
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );

    // Enable Key Interrupt
    NVIC_EnableIRQ(GPIO_KEYS_INT_IRQN);

    while (1) {
        //LED working due to differrent LedSta
        switch(LedSta) {
        case 0 :
            // LED Always Off
            DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
            break;
        case 1 :
            // LED Always ON
            DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
            break;
        default :
            // LED Toggle Once
            DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
            break;
        }
        delay_cycles(8000000); //Delay 0.25 Sec
    }
}

//Interrupt Function
void GROUP1_IRQHandler(void)
{
    switch (DL_Interrupt_getPendingGroup(DL_INTERRUPT_GROUP_1)) {
        //Check Key Interrupt
        case GPIO_KEYS_INT_IIDX:
            delay_cycles(DELAY);    //Waiting de-shaking period
            if(!DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY1_PIN))   //Checking Key Again
            {
                while(!DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY1_PIN))
                    ;   // Waiting Key Release
                delay_cycles(DELAY);    //Waiting de-shaking period
                //Action here while get an exactly Press
                LedSta ++;  // LED Status Changed
                if(LedSta > 2)  // While greater then 2 , turn back to 0
                    LedSta = 0;
            }
            break;
    }
}
