/*
 * uart.h
 *
 *  Created on: 2024Äê1ÔÂ11ÈÕ
 *      Author: junying
 */

#ifndef UART_H_
#define UART_H_

#include "printf.h"
#include "ti_msp_dl_config.h"

#define LineLength  64
// UART Received Buffer, Max Length = LineLength
extern volatile uint8_t LineBuffer[LineLength];

// Flag for the UART Received Status
// Bit15 - Finished for Received One Line
// Bit14 - Got '\r' Flag
// Bit13 ~ Bit0 - The Length of the Received Char
extern volatile uint16_t UART_RX_STA;

#endif /* UART_H_ */
