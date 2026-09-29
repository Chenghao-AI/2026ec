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
unsigned char LedSta = 0;
int main(void)
{
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );

    // Enable IRQ due to Timer TIMG0
    NVIC_EnableIRQ(TIMER_USER_INST_INT_IRQN);
    // Start Timer TIMG0
    DL_TimerG_startCounter(TIMER_USER_INST);

    while (1) {
        // Check Key Input to Change the LED Working Status
        if(!DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY1_PIN))
        {
            delay_cycles(DELAY);    //Delay 10ms to de-sharking when pressed down
            if(!DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY1_PIN))   // Double check the exactlly Key Press Event
            {
                while(!DL_GPIO_readPins(GPIO_KEYS_PORT, GPIO_KEYS_KEY1_PIN))
                    ;   // Waiting for the Key Release
                delay_cycles(DELAY);    // Delay 10ms to de-sharking when key released
                //Start the Procedure after Got exactly Key Event
                LedSta ++;  // LED Status Changed
                if(LedSta > 2)  // When Exceed 2, turn back to 0(LED OFF)
                    LedSta = 0;
            }
        }

    }
}

void TIMER_USER_INST_IRQHandler(void)
{
    //Check the TIMG0 Event
    switch (DL_TimerG_getPendingInterrupt(TIMER_USER_INST)) {
        case DL_TIMER_IIDX_ZERO:    // Zero Event
            // Change LED Display Status per 500ms
            switch(LedSta) {
            case 0 :    // All Off
                DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN);
                break;
            case 1 :    // All On
                DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN);
                break;
            default :   // Toggle LED
                DL_GPIO_togglePins(GPIO_LEDS_PORT,
                    GPIO_LEDS_USER_LED_1_PIN );
                break;
            }
            break;
        default:
            break;
    }
}
