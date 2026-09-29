/*
 * spi_flash.h
 *
 *  Created on: 2024Äê5ÔÂ3ÈÕ
 *      Author: junying
 */

#ifndef SPI_FLASH_H_
#define SPI_FLASH_H_

#include "ti_msp_dl_config.h"

void FLASH_Reset(void);
uint32_t FLASH_ReadID(void);
void FLASH_EraseSector(uint32_t SectorAddr);
void FLASH_EraseChip(void);
void FLASH_WritePage(uint8_t* pBuffer, uint32_t WriteAddr, uint16_t NumByteToWrite);
void FLASH_WriteBuffer(uint8_t* pBuffer, uint32_t WriteAddr, uint16_t NumByteToWrite);
void FLASH_ReadBuffer(uint8_t* pBuffer, uint32_t ReadAddr, uint16_t NumByteToRead);

#endif /* SPI_FLASH_H_ */
