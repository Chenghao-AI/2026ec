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
#include "printf.h"     //User Defined Embeded printf Func
#include "spi_flash.h"

#define LineLength  64  //UART上的接收缓冲区大小
#define FLASH_WriteAddress  0x000200    //FLASH读写、擦除测试地址
#define FLASH_ReadAddress   FLASH_WriteAddress
#define FLASH_SectorToErase FLASH_WriteAddress

#define BufferSize (countof(Tx_Buffer) - 1)

#define countof(a) (sizeof(a) / sizeof(*(a)))

//FLASH写入内容
uint8_t Tx_Buffer[] = "SPI Firmware Library Example: communication with an SPI FLASH";
uint8_t Rx_Buffer[BufferSize];

/* This results in approximately 10ms of delay assuming 32MHz CPU_CLK */
#define DELAY (320000)
typedef enum
{
    FAILED = 0,
    PASSED = !FAILED
} TestStatus;

//写入、读回的比较函数
TestStatus Buffercmp(uint8_t* pBuffer1, uint8_t* pBuffer2, uint16_t BufferLength);
volatile TestStatus TransferStatus1 = FAILED, TransferStatus2 = PASSED;
__IO uint8_t Index                  = 0x0;

//支持printf函数的底层实现代码
void _putchar(char character)
{
  // send char to console etc.
    DL_UART_Main_transmitDataBlocking(UART_0_INST, character);
}

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
    /* Power on GPIO, initialize pins as digital outputs */
    SYSCFG_DL_init();

    /* Default: LED1 OFF */
    DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );
    NVIC_ClearPendingIRQ(UART_0_INST_INT_IRQN);     //Clear the IRQ Flag
    NVIC_EnableIRQ(UART_0_INST_INT_IRQN);           //Enable the Received Interrupt

    //读取FLASH ID测试
    FLASH_Reset();
    printf("Read ID= %08X\r\n", FLASH_ReadID());
    DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );

    //擦除FLASH
    FLASH_Reset();
    /* Perform a write in the Flash followed by a read of the written data */
    /* Erase SPI FLASH Sector to write on */
    FLASH_EraseSector(FLASH_SectorToErase);

    //写入FLASH
    //FLASH_Reset();
    /* Write Tx_Buffer data to SPI FLASH memory */
    FLASH_WriteBuffer(Tx_Buffer, FLASH_WriteAddress, BufferSize);

    DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );

    //读取FLASH
    //FLASH_Reset();
    /* Read data from SPI FLASH memory */
    FLASH_ReadBuffer(Rx_Buffer, FLASH_ReadAddress, BufferSize);

    //比较读出内容与写入内容比较
    /* Check the correctness of written dada */
    TransferStatus1 = Buffercmp(Tx_Buffer, Rx_Buffer, BufferSize);

    if(PASSED == TransferStatus1)
        printf("Flash write OK.\r\n");
    else
        printf("Flash write fail.\r\n");
    /* TransferStatus1 = PASSED, if the transmitted and received data by SPI1
       are the same */
    /* TransferStatus1 = FAILED, if the transmitted and received data by SPI1
       are different */
    DL_GPIO_togglePins(GPIO_LEDS_PORT, GPIO_LEDS_USER_LED_1_PIN );

    //擦除FLASH
    //FLASH_Reset();
    /* Perform an erase in the Flash followed by a read of the written data */
    /* Erase SPI FLASH Sector to write on */
    FLASH_EraseSector(FLASH_SectorToErase);

    FLASH_Reset();
    /* Read data from SPI FLASH memory */
    FLASH_ReadBuffer(Rx_Buffer, FLASH_ReadAddress, BufferSize);

    /* Check the correctness of erasing operation dada */
    for (Index = 0; Index < BufferSize; Index++)
    {
        if (Rx_Buffer[Index] != 0xFF)
        {
            TransferStatus2 = FAILED;
            break;
        }
    }

    if(PASSED == TransferStatus2)
        printf("Sector erase OK.\r\n");
    else
        printf("Sector erase fail.\r\n");
    /* TransferStatus2 = PASSED, if the specified sector part is erased */
    /* TransferStatus2 = FAILED, if the specified sector part is not well erased */

    //测试完成后，继续做UART回环测试
    while (1) {
        if(UART_RX_STA & 0x8000)    //check the received finish flag
        {
            len = UART_RX_STA & 0x3FFF; //Got the Length of the received
            printf("\r\nYour Enter Msg:\r\n");
            //Send the received Line
            for(n=0; n<len; n++)
                DL_UART_Main_transmitDataBlocking(UART_0_INST, LineBuffer[n]);

            printf("\r\n\r\n");
            UART_RX_STA = 0;    //Clear the Flag of the Received
        }
        else {
            times ++;
            if(times % 5000 == 0)   //Per 50S
            {
                printf("\r\nMSPM0+ UART Example\r\n");
                printf("HardwareLab@DeYan\r\n");
            }

            if(times %200 == 0) printf("Please Enter Char with Return: \r\n");  //Per 2S
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

/**
 * @brief  Compares two buffers.
 * @param  pBuffer1, pBuffer2: buffers to be compared.
 * @param BufferLength buffer's length
 * @return PASSED: pBuffer1 identical to pBuffer2
 *         FAILED: pBuffer1 differs from pBuffer2
 */
TestStatus Buffercmp(uint8_t* pBuffer1, uint8_t* pBuffer2, uint16_t BufferLength)
{
    while (BufferLength--)
    {
        if (*pBuffer1 != *pBuffer2)
        {
            return FAILED;
        }

        pBuffer1++;
        pBuffer2++;
    }

    return PASSED;
}
