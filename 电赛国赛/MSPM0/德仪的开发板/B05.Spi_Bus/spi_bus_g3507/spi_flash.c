/*
 * spi_flash.c
 *
 *  Created on: 2024Äê5ÔÂ3ÈÕ
 *      Author: junying
 */
#include "spi_flash.h"

#define FLASH_CMD_WRITE 0x02 /*!< Write to Memory instruction */
#define FLASH_CMD_WRSR  0x01 /*!< Write Status Register instruction */
#define FLASH_CMD_WREN  0x06 /*!< Write enable instruction */
#define FLASH_CMD_READ  0x03 /*!< Read from Memory instruction */
#define FLASH_CMD_RDSR  0x05 /*!< Read Status Register instruction  */
#define FLASH_CMD_RDID  0x9F /*!< Read identification */
#define FLASH_CMD_SE    0x20 /*!< Sector Erase instruction */
#define FLASH_CMD_BE    0x52 /*!< Block Erase instruction (32k)*/
#define FLASH_CMD_CE    0xC7 /*!< Chip Erase instruction */
//#define sFLASH_CMD_BE    0xD8 /*!< Block Erase instruction (64k)*/

#define FLASH_WIP_FLAG 0x01 /*!< Write In Progress (WIP) flag */

#define FLASH_DUMMY_BYTE   0xFF
#define FLASH_SPI_PAGESIZE 0x100

#define FLASH_W25Q128_ID       0x00EF4018
#define FLASH_W25Q128_ID_DTR   0x00EF7018

#define FLASH_M25P64_ID  0x202017

#define FLASH_CS_LOW()  DL_GPIO_clearPins(SPI0_PORT, SPI0_CS0_PIN)
#define FLASH_CS_HIGH() DL_GPIO_setPins(SPI0_PORT, SPI0_CS0_PIN)
uint8_t FLASH_ReadByte(void);
uint8_t FLASH_SendByte(uint8_t byte);
void FLASH_WriteEnable(void);
void FLASH_WaitForWriteEnd(void);
uint8_t FLASH_SendBytes(uint8_t *bytes, uint8_t ByteCnt);

uint8_t gTxPacket[4];
uint8_t gRxPacket[4];


/**
 * @brief  Reads a byte from the SPI Flash.
 * @note   This function must be used only if the Start_Read_Sequence function
 *         has been previously called.
 * @return Byte Read from the SPI Flash.
 */
uint8_t FLASH_ReadByte(void)
{
    return (FLASH_SendByte(FLASH_DUMMY_BYTE));
}

/**
 * @brief  Sends a byte through the SPI interface and return the byte received
 *         from the SPI bus.
 * @param byte byte to send.
 * @return The value of the received byte.
 */
uint8_t FLASH_SendByte(uint8_t byte)
{
    /* Wait until all bytes have been transmitted and the TX FIFO is empty */
    while (DL_SPI_isBusy(SPI_0_INST))
        ;

    /*!< Send byte through the SPI1 peripheral */
    DL_SPI_transmitData8(SPI_0_INST, byte);

    /*!< Return the byte read from the SPI bus */
    return (DL_SPI_receiveDataBlocking8(SPI_0_INST));
}

/**
 * @brief  Sends One More bytes through the SPI interface and return the byte received
 *         from the SPI bus.
 * @param bytes point to bytes buffer to send.
 * @param ByteCnt The Number of the bytes, The Number must less then 32.
 * @return The value of the received byte.
 */
uint8_t FLASH_SendBytes(uint8_t *bytes, uint8_t ByteCnt)
{
    /* Fill TX FIFO with data and transmit to SPI Peripheral */
    DL_SPI_fillTXFIFO8(SPI_0_INST, bytes, ByteCnt);
    /* Wait until all bytes have been transmitted and the TX FIFO is empty */
    while (DL_SPI_isBusy(SPI_0_INST))
        ;
    /*
     * Wait to receive the SPI data
     * This loop expects SPI_PACKET_SIZE bytes
     */
    for (uint8_t i = 0; i < ByteCnt; i++) {
        bytes[i] = DL_SPI_receiveDataBlocking8(SPI_0_INST);
    }

    return (ByteCnt);
}

/**
 * @brief  Enables the write access to the FLASH.
 */
void FLASH_WriteEnable(void)
{
    /*!< Select the FLASH: Chip Select low */
    FLASH_CS_LOW();

    /*!< Send "Write Enable" instruction */
    FLASH_SendByte(FLASH_CMD_WREN);

    /*!< Deselect the FLASH: Chip Select high */
    FLASH_CS_HIGH();
}

/**
 * @brief  Polls the status of the Write In Progress (WIP) flag in the FLASH's
 *         status register and loop until write opertaion has completed.
 */
void FLASH_WaitForWriteEnd(void)
{
    uint8_t flashstatus = 0;

    /*!< Select the FLASH: Chip Select low */
    FLASH_CS_LOW();

    /*!< Send "Read Status Register" instruction */
    FLASH_SendByte(FLASH_CMD_RDSR);

    /*!< Loop as long as the memory is busy with a write cycle */
    do
    {
        /*!< Send a dummy byte to generate the clock needed by the FLASH
        and put the value of the status register in FLASH_STS variable */
        flashstatus = FLASH_SendByte(FLASH_DUMMY_BYTE);

    } while ((flashstatus & FLASH_WIP_FLAG)); /* Write in progress */

    /*!< Deselect the FLASH: Chip Select high */
    FLASH_CS_HIGH();
}



uint32_t FLASH_ReadID(void)
{
    uint32_t Ret;
    gTxPacket[0] = 0x9F;
    gTxPacket[1] = 0xFF;
    gTxPacket[2] = 0xFF;
    gTxPacket[3] = 0xFF;
    FLASH_CS_LOW();
    FLASH_SendBytes(gTxPacket, 4);

    FLASH_CS_HIGH();
    //Return Manufacture ID, Memory Type ID, and Memory Density ID
    Ret = gTxPacket[1] << 16 | gTxPacket[2] << 8 | gTxPacket[3];
    return Ret;
}

void FLASH_Reset(void)
{
    FLASH_CS_LOW();
    FLASH_SendByte(0x66);
    FLASH_CS_HIGH();
    delay_cycles(1000);

    FLASH_CS_LOW();
    FLASH_SendByte(0x99);
    FLASH_CS_HIGH();
    delay_cycles(1000);

    return ;
}

/**
 * @brief  Erases the specified FLASH sector.
 * @param SectorAddr address of the sector to erase.
 */
void FLASH_EraseSector(uint32_t SectorAddr)
{
    gTxPacket[0] = FLASH_CMD_SE;
    gTxPacket[1] = (SectorAddr & 0xFF0000) >> 16;
    gTxPacket[2] = (SectorAddr & 0xFF00) >> 8;
    gTxPacket[3] = (SectorAddr & 0xFF);
    /*!< Send write enable instruction */
    FLASH_WriteEnable();

    /*!< Sector Erase */
    /*!< Select the FLASH: Chip Select low */
    FLASH_CS_LOW();
    FLASH_SendBytes(gTxPacket, 4);
    /*!< Deselect the FLASH: Chip Select high */
    FLASH_CS_HIGH();

    /*!< Wait the end of Flash writing */
    FLASH_WaitForWriteEnd();
}

/**
 * @brief  Erases the entire FLASH.
 */
void FLASH_EraseChip(void)
{
    /*!< Send write enable instruction */
    FLASH_WriteEnable();

    /*!< Chip Erase */
    /*!< Select the FLASH: Chip Select low */
    FLASH_CS_LOW();
    /*!< Send Chip Erase instruction  */
    FLASH_SendByte(FLASH_CMD_CE);
    /*!< Deselect the FLASH: Chip Select high */
    FLASH_CS_HIGH();

    /*!< Wait the end of Flash writing */
    FLASH_WaitForWriteEnd();
}

/**
 * @brief  Reads a block of data from the FLASH.
 * @param pBuffer pointer to the buffer that receives the data read from the FLASH.
 * @param ReadAddr FLASH's internal address to read from.
 * @param NumByteToRead number of bytes to read from the FLASH.
 */
void FLASH_ReadBuffer(uint8_t* pBuffer, uint32_t ReadAddr, uint16_t NumByteToRead)
{
    /*!< Select the FLASH: Chip Select low */
    FLASH_CS_LOW();

    /*!< Send "Read from Memory " instruction */
    FLASH_SendByte(FLASH_CMD_READ);

    /*!< Send ReadAddr high nibble address byte to read from */
    FLASH_SendByte((ReadAddr & 0xFF0000) >> 16);
    /*!< Send ReadAddr medium nibble address byte to read from */
    FLASH_SendByte((ReadAddr & 0xFF00) >> 8);
    /*!< Send ReadAddr low nibble address byte to read from */
    FLASH_SendByte(ReadAddr & 0xFF);

    while (NumByteToRead--) /*!< while there is data to be read */
    {
        /*!< Read a byte from the FLASH */
        *pBuffer = FLASH_SendByte(FLASH_DUMMY_BYTE);
        /*!< Point to the next location where the byte read will be saved */
        pBuffer++;
    }

    /*!< Deselect the FLASH: Chip Select high */
    FLASH_CS_HIGH();
}

/**
 * @brief  Writes more than one byte to the FLASH with a single WRITE cycle
 *         (Page WRITE sequence).
 * @note   The number of byte can't exceed the FLASH page size.
 * @param pBuffer pointer to the buffer  containing the data to be written
 *         to the FLASH.
 * @param WriteAddr FLASH's internal address to write to.
 * @param NumByteToWrite number of bytes to write to the FLASH, must be equal
 *         or less than "sFLASH_PAGESIZE" value.
 */
void FLASH_WritePage(uint8_t* pBuffer, uint32_t WriteAddr, uint16_t NumByteToWrite)
{
    /*!< Enable the write access to the FLASH */
    FLASH_WriteEnable();

    /*!< Select the FLASH: Chip Select low */
    FLASH_CS_LOW();
    /*!< Send "Write to Memory " instruction */
    FLASH_SendByte(FLASH_CMD_WRITE);
    /*!< Send WriteAddr high nibble address byte to write to */
    FLASH_SendByte((WriteAddr & 0xFF0000) >> 16);
    /*!< Send WriteAddr medium nibble address byte to write to */
    FLASH_SendByte((WriteAddr & 0xFF00) >> 8);
    /*!< Send WriteAddr low nibble address byte to write to */
    FLASH_SendByte(WriteAddr & 0xFF);

    /*!< while there is data to be written on the FLASH */
    while (NumByteToWrite--)
    {
        /*!< Send the current byte */
        FLASH_SendByte(*pBuffer);
        /*!< Point on the next byte to be written */
        pBuffer++;
    }

    /*!< Deselect the FLASH: Chip Select high */
    FLASH_CS_HIGH();

    /*!< Wait the end of Flash writing */
    FLASH_WaitForWriteEnd();
}

/**
 * @brief  Writes block of data to the FLASH. In this function, the number of
 *         WRITE cycles are reduced, using Page WRITE sequence.
 * @param pBuffer pointer to the buffer  containing the data to be written
 *         to the FLASH.
 * @param WriteAddr FLASH's internal address to write to.
 * @param NumByteToWrite number of bytes to write to the FLASH.
 */
void FLASH_WriteBuffer(uint8_t* pBuffer, uint32_t WriteAddr, uint16_t NumByteToWrite)
{
    uint8_t NumOfPage = 0, NumOfSingle = 0, Addr = 0, count = 0, temp = 0;

    Addr        = WriteAddr % FLASH_SPI_PAGESIZE;
    count       = FLASH_SPI_PAGESIZE - Addr;
    NumOfPage   = NumByteToWrite / FLASH_SPI_PAGESIZE;
    NumOfSingle = NumByteToWrite % FLASH_SPI_PAGESIZE;

    if (Addr == 0) /*!< WriteAddr is sFLASH_PAGESIZE aligned  */
    {
        if (NumOfPage == 0) /*!< NumByteToWrite < sFLASH_PAGESIZE */
        {
            FLASH_WritePage(pBuffer, WriteAddr, NumByteToWrite);
        }
        else /*!< NumByteToWrite > sFLASH_PAGESIZE */
        {
            while (NumOfPage--)
            {
                FLASH_WritePage(pBuffer, WriteAddr, FLASH_SPI_PAGESIZE);
                WriteAddr += FLASH_SPI_PAGESIZE;
                pBuffer += FLASH_SPI_PAGESIZE;
            }

            FLASH_WritePage(pBuffer, WriteAddr, NumOfSingle);
        }
    }
    else /*!< WriteAddr is not sFLASH_PAGESIZE aligned  */
    {
        if (NumOfPage == 0) /*!< NumByteToWrite < sFLASH_PAGESIZE */
        {
            if (NumOfSingle > count) /*!< (NumByteToWrite + WriteAddr) > sFLASH_PAGESIZE */
            {
                temp = NumOfSingle - count;

                FLASH_WritePage(pBuffer, WriteAddr, count);
                WriteAddr += count;
                pBuffer += count;

                FLASH_WritePage(pBuffer, WriteAddr, temp);
            }
            else
            {
                FLASH_WritePage(pBuffer, WriteAddr, NumByteToWrite);
            }
        }
        else /*!< NumByteToWrite > sFLASH_PAGESIZE */
        {
            NumByteToWrite -= count;
            NumOfPage   = NumByteToWrite / FLASH_SPI_PAGESIZE;
            NumOfSingle = NumByteToWrite % FLASH_SPI_PAGESIZE;

            FLASH_WritePage(pBuffer, WriteAddr, count);
            WriteAddr += count;
            pBuffer += count;

            while (NumOfPage--)
            {
                FLASH_WritePage(pBuffer, WriteAddr, FLASH_SPI_PAGESIZE);
                WriteAddr += FLASH_SPI_PAGESIZE;
                pBuffer += FLASH_SPI_PAGESIZE;
            }

            if (NumOfSingle != 0)
            {
                FLASH_WritePage(pBuffer, WriteAddr, NumOfSingle);
            }
        }
    }
}

