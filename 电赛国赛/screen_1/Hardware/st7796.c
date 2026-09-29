#include "st7796.h"

#include <stddef.h>

#include "ti_msp_dl_config.h"

static void lcd_delay_ms(uint32_t milliseconds)
{
    while (milliseconds-- > 0U) {
        delay_cycles(32000U);
    }
}

static void spi_write8(uint8_t value)
{
    while (DL_SPI_isTXFIFOFull(SPI_LCD_INST)) {
    }
    DL_SPI_transmitData8(SPI_LCD_INST, value);
}

static void spi_finish(void)
{
    while (!DL_SPI_isTXFIFOEmpty(SPI_LCD_INST)) {
    }
    while (DL_SPI_isBusy(SPI_LCD_INST)) {
    }
    while (!DL_SPI_isRXFIFOEmpty(SPI_LCD_INST)) {
        (void) DL_SPI_receiveData8(SPI_LCD_INST);
    }
}

static void lcd_select(void)
{
    DL_GPIO_clearPins(LCD_CTRL_PORT, LCD_CTRL_CS_PIN);
}

static void lcd_deselect(void)
{
    DL_GPIO_setPins(LCD_CTRL_PORT, LCD_CTRL_CS_PIN);
}

static void lcd_command_data(uint8_t command, const uint8_t *data,
                             uint8_t length)
{
    uint8_t i;

    lcd_select();
    DL_GPIO_clearPins(LCD_CTRL_PORT, LCD_CTRL_DC_PIN);
    spi_write8(command);
    spi_finish();

    if ((data != NULL) && (length > 0U)) {
        DL_GPIO_setPins(LCD_CTRL_PORT, LCD_CTRL_DC_PIN);
        for (i = 0U; i < length; i++) {
            spi_write8(data[i]);
        }
        spi_finish();
    }
    lcd_deselect();
}

static void lcd_command(uint8_t command)
{
    lcd_command_data(command, NULL, 0U);
}

static void lcd_set_window(uint16_t x0, uint16_t y0,
                           uint16_t x1, uint16_t y1)
{
    uint8_t data[4];

    data[0] = (uint8_t)(x0 >> 8);
    data[1] = (uint8_t)x0;
    data[2] = (uint8_t)(x1 >> 8);
    data[3] = (uint8_t)x1;
    lcd_command_data(0x2AU, data, 4U);

    data[0] = (uint8_t)(y0 >> 8);
    data[1] = (uint8_t)y0;
    data[2] = (uint8_t)(y1 >> 8);
    data[3] = (uint8_t)y1;
    lcd_command_data(0x2BU, data, 4U);
}

static void lcd_begin_pixels(void)
{
    lcd_select();
    DL_GPIO_clearPins(LCD_CTRL_PORT, LCD_CTRL_DC_PIN);
    spi_write8(0x2CU);
    spi_finish();
    DL_GPIO_setPins(LCD_CTRL_PORT, LCD_CTRL_DC_PIN);
}

static void lcd_end_pixels(void)
{
    spi_finish();
    lcd_deselect();
}

void ST7796_Init(void)
{
    static const uint8_t b6[] = {0x00U, 0x02U};
    static const uint8_t b5[] = {0x02U, 0x03U, 0x00U, 0x04U};
    static const uint8_t b1[] = {0x80U, 0x10U};
    static const uint8_t e8[] = {
        0x40U, 0x8AU, 0x00U, 0x00U, 0x29U, 0x19U, 0xA5U, 0x33U
    };
    static const uint8_t gamma_pos[] = {
        0xF0U, 0x09U, 0x13U, 0x12U, 0x12U, 0x2BU, 0x3CU,
        0x44U, 0x4BU, 0x1BU, 0x18U, 0x17U, 0x1DU, 0x21U
    };
    static const uint8_t gamma_neg[] = {
        0xF0U, 0x09U, 0x13U, 0x0CU, 0x0DU, 0x27U, 0x3BU,
        0x44U, 0x4DU, 0x0BU, 0x17U, 0x17U, 0x1DU, 0x21U
    };
    uint8_t value;

    lcd_deselect();
    DL_GPIO_setPins(LCD_CTRL_PORT, LCD_CTRL_DC_PIN);

    DL_GPIO_clearPins(LCD_CTRL_PORT, LCD_CTRL_RESET_PIN);
    lcd_delay_ms(100U);
    DL_GPIO_setPins(LCD_CTRL_PORT, LCD_CTRL_RESET_PIN);
    lcd_delay_ms(50U);

    value = 0xC3U; lcd_command_data(0xF0U, &value, 1U);
    value = 0x96U; lcd_command_data(0xF0U, &value, 1U);
    value = 0x68U; lcd_command_data(0x36U, &value, 1U);
    value = 0x05U; lcd_command_data(0x3AU, &value, 1U);
    value = 0x80U; lcd_command_data(0xB0U, &value, 1U);
    lcd_command_data(0xB6U, b6, sizeof(b6));
    lcd_command_data(0xB5U, b5, sizeof(b5));
    lcd_command_data(0xB1U, b1, sizeof(b1));
    value = 0x00U; lcd_command_data(0xB4U, &value, 1U);
    value = 0xC6U; lcd_command_data(0xB7U, &value, 1U);
    value = 0x24U; lcd_command_data(0xC5U, &value, 1U);
    value = 0x31U; lcd_command_data(0xE4U, &value, 1U);
    lcd_command_data(0xE8U, e8, sizeof(e8));
    lcd_command(0xC2U);
    lcd_command(0xA7U);
    lcd_command_data(0xE0U, gamma_pos, sizeof(gamma_pos));
    lcd_command_data(0xE1U, gamma_neg, sizeof(gamma_neg));

    value = 0xECU; lcd_command_data(0x36U, &value, 1U);
    value = 0xC3U; lcd_command_data(0xF0U, &value, 1U);
    value = 0x69U; lcd_command_data(0xF0U, &value, 1U);
    lcd_command(0x13U);
    lcd_command(0x11U);
    lcd_delay_ms(120U);
    lcd_command(0x29U);
    lcd_delay_ms(20U);

    /* Landscape 480x320, BGR color order. */
    value = 0x28U;
    lcd_command_data(0x36U, &value, 1U);
    ST7796_FillScreen(RGB565(5U, 12U, 22U));
}

void ST7796_FillRect(uint16_t x, uint16_t y, uint16_t width,
                     uint16_t height, uint16_t color)
{
    uint32_t count;
    uint8_t high;
    uint8_t low;

    if ((width == 0U) || (height == 0U) ||
        (x >= ST7796_WIDTH) || (y >= ST7796_HEIGHT)) {
        return;
    }
    if (((uint32_t)x + width) > ST7796_WIDTH) {
        width = (uint16_t)(ST7796_WIDTH - x);
    }
    if (((uint32_t)y + height) > ST7796_HEIGHT) {
        height = (uint16_t)(ST7796_HEIGHT - y);
    }

    lcd_set_window(x, y, (uint16_t)(x + width - 1U),
                   (uint16_t)(y + height - 1U));
    lcd_begin_pixels();

    high = (uint8_t)(color >> 8);
    low = (uint8_t)color;
    count = (uint32_t)width * height;
    while (count-- > 0U) {
        spi_write8(high);
        spi_write8(low);
    }
    lcd_end_pixels();
}

void ST7796_FillScreen(uint16_t color)
{
    ST7796_FillRect(0U, 0U, ST7796_WIDTH, ST7796_HEIGHT, color);
}

void ST7796_DrawHLine(uint16_t x, uint16_t y, uint16_t width,
                      uint16_t color)
{
    ST7796_FillRect(x, y, width, 1U, color);
}

void ST7796_DrawVLine(uint16_t x, uint16_t y, uint16_t height,
                      uint16_t color)
{
    ST7796_FillRect(x, y, 1U, height, color);
}

void ST7796_DrawRect(uint16_t x, uint16_t y, uint16_t width,
                     uint16_t height, uint16_t color)
{
    if ((width < 2U) || (height < 2U)) {
        return;
    }
    ST7796_DrawHLine(x, y, width, color);
    ST7796_DrawHLine(x, (uint16_t)(y + height - 1U), width, color);
    ST7796_DrawVLine(x, y, height, color);
    ST7796_DrawVLine((uint16_t)(x + width - 1U), y, height, color);
}

void ST7796_DrawRGB565(uint16_t x, uint16_t y, uint16_t width,
                       uint16_t height, const uint16_t *pixels)
{
    uint32_t count;
    uint16_t color;

    if ((pixels == NULL) || (width == 0U) || (height == 0U) ||
        (((uint32_t)x + width) > ST7796_WIDTH) ||
        (((uint32_t)y + height) > ST7796_HEIGHT)) {
        return;
    }

    lcd_set_window(x, y, (uint16_t)(x + width - 1U),
                   (uint16_t)(y + height - 1U));
    lcd_begin_pixels();
    count = (uint32_t)width * height;
    while (count-- > 0U) {
        color = *pixels++;
        spi_write8((uint8_t)(color >> 8));
        spi_write8((uint8_t)color);
    }
    lcd_end_pixels();
}
