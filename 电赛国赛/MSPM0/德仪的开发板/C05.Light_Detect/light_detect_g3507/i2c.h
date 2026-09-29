/*
 * i2c.h
 *
 *  Created on: 2024Äê1ÔÂ11ÈÕ
 *      Author: junying
 */

#ifndef I2C_H_
#define I2C_H_

#include "ti_msp_dl_config.h"

#define MAX_DATA_LEN 128 //The Max bytes for transferring

void delay_ms(uint16_t ms);

uint8_t I2C_Write_Bytes(uint8_t DevAddr, uint8_t RegAddr, uint8_t *buf, uint8_t nBytes);

#endif /* I2C_H_ */
