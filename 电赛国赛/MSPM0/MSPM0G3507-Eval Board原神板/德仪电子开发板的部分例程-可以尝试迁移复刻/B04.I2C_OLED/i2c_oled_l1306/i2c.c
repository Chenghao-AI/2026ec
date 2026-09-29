/*
 * i2c.c
 *
 *  Created on: 2024年1月11日
 *      Author: junying
 */

#include "i2c.h"

//寄存器地址
uint8_t gTxRegAddr;

#define DELAY (32000)
void delay_ms(uint16_t ms)
{
    while(ms --)
        delay_cycles(DELAY);
}

uint8_t I2C_Write_Bytes(uint8_t DevAddr, uint8_t RegAddr, uint8_t *buf, uint8_t nBytes)
{
    uint8_t n;
    uint32_t Byte4Fill;
    gTxRegAddr = RegAddr;

    DL_I2C_fillControllerTXFIFO(I2C_INST, &buf[0], nBytes);

    /* Wait for I2C to be Idle */
    while (!(
        DL_I2C_getControllerStatus(I2C_INST) & DL_I2C_CONTROLLER_STATUS_IDLE))
        ;

    DL_I2C_flushControllerTXFIFO(I2C_INST); //清除FIFO
    DL_I2C_fillControllerTXFIFO(I2C_INST, &gTxRegAddr, 1);  //填写寄存器地址

    /* Send the packet to the controller.
     * This function will send Start + Stop automatically.
     */
    DL_I2C_startControllerTransfer(I2C_INST, DevAddr,
        DL_I2C_CONTROLLER_DIRECTION_TX, (nBytes+1));
    n = 0;
    do {
        Byte4Fill = DL_I2C_getControllerTXFIFOCounter(I2C_INST);    //填写数据
        if(Byte4Fill > 1)
        {
            DL_I2C_fillControllerTXFIFO(I2C_INST, &buf[n], 1);
            n++;
        }
    }while(n<nBytes);

    /* Poll until the Controller writes all bytes */
    while (DL_I2C_getControllerStatus(I2C_INST) &
           DL_I2C_CONTROLLER_STATUS_BUSY_BUS)
        ;   //等待全部发送完毕

    /* Trap if there was an error */
    if (DL_I2C_getControllerStatus(I2C_INST) &
        DL_I2C_CONTROLLER_STATUS_ERROR) {
        /* LED will remain high if there is an error */
        __BKPT(0);
    }

    /* Add delay between transfers */
    delay_cycles(1000);

    return nBytes;
}
