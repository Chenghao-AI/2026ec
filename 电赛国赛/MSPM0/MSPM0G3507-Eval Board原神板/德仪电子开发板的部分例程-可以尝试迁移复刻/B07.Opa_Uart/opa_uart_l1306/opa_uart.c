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

// To Using Chinese correctly on UART, please use GBK encoding.

#include "ti_msp_dl_config.h"
#include "string.h"
#include "stdlib.h"
#include "printf.h"     //User Defined Embeded printf Func
#define LineLength  64

/* This results in approximately 10ms of delay assuming 32MHz CPU_CLK */
#define DELAY (320000)

void _putchar(char character)
{
  // send char to console etc.
    DL_UART_Main_transmitDataBlocking(UART_0_INST, character);
}
void OPA_SetGain(uint32_t gain);

// UART Received Buffer, Max Length = LineLength
volatile uint8_t LineBuffer[LineLength];

// Flag for the UART Received Status
// Bit15 - Finished for Received One Line
// Bit14 - Got '\r' Flag
// Bit13 ~ Bit0 - The Length of the Received Char
volatile uint16_t UART_RX_STA = 0;

int main(void)
{
    unsigned short times = 0;
    unsigned short len;
    unsigned short n;
    uint32_t val;
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
    NVIC_ClearPendingIRQ(UART_0_INST_INT_IRQN);     //Clear the IRQ Flag
    NVIC_EnableIRQ(UART_0_INST_INT_IRQN);           //Enable the Received Interrupt
    while (1) {
        if(UART_RX_STA & 0x8000)    //check the received finish flag
        {
            len = UART_RX_STA & 0x3FFF; //Got the Length of the received
            LineBuffer[len] = 0;
            val = atoi((const char *)LineBuffer);
            if((val > 32) || (val < 0))
                printf("\r\nEnter not valid number[%s]", LineBuffer);
            else
                OPA_SetGain(val);
            UART_RX_STA = 0;    //Clear the Flag of the Received
        }
        else {
            times ++;
            if(times % 5000 == 0)   //Per 50S
            {
                printf("\r\nMSPM0+ UART Eample\r\n");
                printf("HardwareLab@DY Lab\r\n");
            }

            if(times %200 == 0)
            {
                printf("\r\nPlease Enter the Gain of OPA[0|2|4|8|16|32]: ");
            }  //Per 2S
            if(times % 50 == 0) DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );  //Per 500ms
            delay_cycles(DELAY);
        }
    }
}

volatile uint8_t gRxData = 0;

void UART_0_INST_IRQHandler(void)
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

DL_OPA_Config MyOpaConfig = {
    .pselChannel    = DL_OPA_PSEL_IN0_POS,
    .nselChannel    = DL_OPA_NSEL_RTAP,
    .mselChannel    = DL_OPA_MSEL_GND,
    .gain           = DL_OPA_GAIN_N1_P2,
    .outputPinState = DL_OPA_OUTPUT_PIN_ENABLED,
    .choppingMode   = DL_OPA_CHOPPING_MODE_DISABLE,
};

void OPA_SetGain(uint32_t gain)
{
    switch(gain)
    {
    case 0:
    case 2:
    case 4:
    case 8:
    case 16:
    case 32:
        DL_OPA_disable(OPA_1_INST);
        break;
    default :
        printf("\r\nEnter Not Valid Gain Value [%d]", gain);
        return;
    }
    switch(gain)
    {
    case 0 :
        MyOpaConfig.gain = DL_OPA_GAIN_N0_P1;
        break;
    case 2 :
        MyOpaConfig.gain = DL_OPA_GAIN_N1_P2;
        break;
    case 4 :
        MyOpaConfig.gain = DL_OPA_GAIN_N3_P4;
        break;
    case 8 :
        MyOpaConfig.gain = DL_OPA_GAIN_N7_P8;
        break;
    case 16 :
        MyOpaConfig.gain = DL_OPA_GAIN_N15_P16;
        break;
    case 32 :
        MyOpaConfig.gain = DL_OPA_GAIN_N31_P32;
        break;
    }
    DL_OPA_init(OPA_1_INST, (DL_OPA_Config *) &MyOpaConfig);

    DL_OPA_enable(OPA_1_INST);
    printf("\r\nSet the Gain of OPA = %d", gain);
    return;
}
