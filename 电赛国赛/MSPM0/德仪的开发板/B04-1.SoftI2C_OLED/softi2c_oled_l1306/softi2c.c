/*
 * softi2c.c
 *
 *  Created on: 2024年1月12日
 *      Author: junying
 */

#include "i2c.h"

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
/* Data sent to the Target */
uint8_t gTxPacket[MAX_DATA_LEN+1];

/* Counters for TX length and bytes sent */
uint32_t gTxLen, gTxCount;

#define DELAY (32000)

#define OLED_SCL_Clr() DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_SCL_PIN)     //SCL
#define OLED_SCL_Set() DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_SCL_PIN)

#define OLED_SDA_Clr() DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_SDA_PIN)     //SDA
#define OLED_SDA_Set() DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_SDA_PIN)

void delay_ms(uint16_t ms)
{
    while(ms --)
        delay_cycles(DELAY);
}

//ÑÓÊ±
void IIC_delay(void)
{
    delay_cycles(100);
//    u8 t=3;
//    while(t--);
}

//ÆðÊ¼ÐÅºÅ
void I2C_Start(void)
{
    OLED_SDA_Set();
    OLED_SCL_Set();
    IIC_delay();
    OLED_SDA_Clr();
    IIC_delay();
    OLED_SCL_Clr();
    IIC_delay();
}

//½áÊøÐÅºÅ
void I2C_Stop(void)
{
    OLED_SDA_Clr();
    OLED_SCL_Set();
    IIC_delay();
    OLED_SDA_Set();
}

//µÈ´ýÐÅºÅÏìÓ¦
void I2C_WaitAck(void) //²âÊý¾ÝÐÅºÅµÄµçÆ½
{
    OLED_SDA_Set();
    IIC_delay();
    OLED_SCL_Set();
    IIC_delay();
    OLED_SCL_Clr();
    IIC_delay();
}

//Ð´ÈëÒ»¸ö×Ö½Ú
void Send_Byte(u8 dat)
{
    u8 i;
    for(i=0;i<8;i++)
    {
        if(dat&0x80)//½«datµÄ8Î»´Ó×î¸ßÎ»ÒÀ´ÎÐ´Èë
        {
            OLED_SDA_Set();
    }
        else
        {
            OLED_SDA_Clr();
    }
        IIC_delay();
        OLED_SCL_Set();
        IIC_delay();
        OLED_SCL_Clr();//½«Ê±ÖÓÐÅºÅÉèÖÃÎªµÍµçÆ½
        dat<<=1;
  }
}

uint8_t I2C_Write_Bytes(uint8_t DevAddr, uint8_t RegAddr, uint8_t *buf, uint8_t nBytes)
{
    uint8_t n;
    I2C_Start();
    Send_Byte(DevAddr<<1);
    I2C_WaitAck();
    Send_Byte(RegAddr);
    I2C_WaitAck();
    for(n=0; n<nBytes; n++)
    {
        Send_Byte(buf[n]);
        I2C_WaitAck();
    }
    I2C_Stop();
    delay_cycles(1000);
    return nBytes;
}
