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

// Display Library
unsigned char DispLib[16] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71};

//Set 1 on the specific bit on TUBE4
//Input: n - 0~3 for bit0~bit3 ON
//      others - All Tube OFF
void OutTubeDig(unsigned char n)
{
    DL_GPIO_clearPins(TUBE_B_PORT, TUBE_B_PIN_0_PIN | TUBE_B_PIN_1_PIN | TUBE_B_PIN_2_PIN | TUBE_B_PIN_3_PIN);
    switch(n) {
    case 0:
        DL_GPIO_setPins(TUBE_B_PORT, TUBE_B_PIN_0_PIN);
        break;
    case 1:
        DL_GPIO_setPins(TUBE_B_PORT, TUBE_B_PIN_1_PIN);
        break;
    case 2:
        DL_GPIO_setPins(TUBE_B_PORT, TUBE_B_PIN_2_PIN);
        break;
    case 3:
        DL_GPIO_setPins(TUBE_B_PORT, TUBE_B_PIN_3_PIN);
        break;
    default:
        break;
    }
}

// Display Dot on Tube
// Input: 0 - OFF   1 - ON
void OutTubeDot(unsigned char Val)
{
    if(Val)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_DP_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_DP_PIN);
}

// Display 0~F on Tube
// Input:   DispLib[n] on Tube
void OutTubeContent(unsigned char Val)
{
    if(Val & 0x40)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_G_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_G_PIN);
    if(Val & 0x20)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_F_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_F_PIN);
    if(Val & 0x10)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_E_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_E_PIN);
    if(Val & 0x08)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_D_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_D_PIN);
    if(Val & 0x04)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_C_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_C_PIN);
    if(Val & 0x02)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_B_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_B_PIN);
    if(Val & 0x01)
        DL_GPIO_clearPins(TUBE_PORT, TUBE_PIN_A_PIN);
    else
        DL_GPIO_setPins(TUBE_PORT, TUBE_PIN_A_PIN);
}

// Define the Display Buffer, default is 0x1234
unsigned short DispBuf = 0x1234;

/* This results in approximately 10ms of delay assuming 32MHz CPU_CLK */
#define DELAY (320000)  //10ms
int main(void)
{
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
    OutTubeDig(4);  // All Off
    OutTubeContent(0);  // All Off
    OutTubeDot(0);  // Dot Off

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
                DispBuf ++; // Change the Display Contents due to Key Pressed
            }
        }

    }
}

// Timer Interrupt per 5ms
// Take turns displaying each digit
void TIMER_USER_INST_IRQHandler(void)
{
    static unsigned char cnt = 0;
    //Check the TIMG0 Event
    switch (DL_TimerG_getPendingInterrupt(TIMER_USER_INST)) {
        case DL_TIMER_IIDX_ZERO:    // Zero Event
            // Change LED Display Status per 5ms
            OutTubeDig(4);  // Not 0~3, All Off;
            // Output the Exactly Content from Display Buffer, One Display Digit occupy 4 bits in DispBuf
            OutTubeContent(DispLib[(DispBuf >> (cnt << 2)) & 0x000F]);
            // Turn On the Exactly Digit
            OutTubeDig(cnt);
            // Go Through 0 -3
            cnt++;
            if(cnt > 3)
                cnt = 0;
            break;
        default:
            break;
    }
}
