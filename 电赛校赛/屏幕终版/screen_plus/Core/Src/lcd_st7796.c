/**
  ******************************************************************************
  * @file    lcd_st7796.c
  * @brief   ST7796 480x320 landscape LCD driver with drawing primitives
  *
  *          Hardware interface:
  *            SPI1:  SCK=PB3, MOSI=PA7, MISO=PA6
  *            CS1=PB12 (LCD chip select), DC=PB13, RES=PB14, BLK=PB15
  *            CS2=PC4 (touch disable), PEN=PC5 (touch interrupt, unused)
  *
  *          MADCTL = 0xEC  → landscape, BGR order
  *          If left-right mirrored, change to 0x2C.
  ******************************************************************************
  */
#include "lcd_st7796.h"
#include "spi.h"
#include "font_8x16.h"
#include <string.h>

/* =================================================================== */
/*  Internal helpers                                                    */
/* =================================================================== */

#define SPI_TIMEOUT_MS  100U

/* ----- GPIO one-liners --------------------------------------------- */
static void cs_low(void)   { HAL_GPIO_WritePin(CS1_GPIO_Port, CS1_Pin, GPIO_PIN_RESET); }
static void cs_high(void)  { HAL_GPIO_WritePin(CS1_GPIO_Port, CS1_Pin, GPIO_PIN_SET);   }
static void dc_cmd(void)   { HAL_GPIO_WritePin(DC_GPIO_Port,  DC_Pin,  GPIO_PIN_RESET); }
static void dc_data(void)  { HAL_GPIO_WritePin(DC_GPIO_Port,  DC_Pin,  GPIO_PIN_SET);   }
static void res_low(void)  { HAL_GPIO_WritePin(RES_GPIO_Port, RES_Pin, GPIO_PIN_RESET); }
static void res_high(void) { HAL_GPIO_WritePin(RES_GPIO_Port, RES_Pin, GPIO_PIN_SET);   }
static void blk_on(void)   { HAL_GPIO_WritePin(BLK_GPIO_Port, BLK_Pin, GPIO_PIN_SET);   }
static void blk_off(void)  { HAL_GPIO_WritePin(BLK_GPIO_Port, BLK_Pin, GPIO_PIN_RESET); }

/* ----- SPI byte / word write --------------------------------------- */
static void spi_write(const uint8_t *data, uint16_t size)
{
    if (data == NULL || size == 0U) return;
    if (HAL_SPI_Transmit(&hspi1, (uint8_t *)data, size, SPI_TIMEOUT_MS) != HAL_OK)
        Error_Handler();
}

static void spi_write16(uint16_t color, uint32_t count)
{
    /* Send a 16-bit colour value `count` times efficiently */
    static uint8_t buf[512];
    uint16_t chunk = (uint16_t)(sizeof(buf) / 2U);  /* 256 pixels per burst */

    /* Pre-fill buffer with one pixel worth of colour data */
    for (uint16_t i = 0U; i < chunk; i++) {
        buf[2U * i]     = (uint8_t)(color >> 8);
        buf[2U * i + 1] = (uint8_t)(color & 0xFFU);
    }

    while (count > 0U) {
        uint32_t n = (count > (uint32_t)chunk) ? (uint32_t)chunk : count;
        spi_write(buf, (uint16_t)(n * 2U));
        count -= n;
    }
}

/* ----- Low-level LCD protocol -------------------------------------- */
static void lcd_write_command(uint8_t cmd)
{
    cs_low();
    dc_cmd();
    spi_write(&cmd, 1U);
    cs_high();
}

static void lcd_write_data(const uint8_t *data, uint16_t size)
{
    cs_low();
    dc_data();
    spi_write(data, size);
    cs_high();
}

static void lcd_write_register(uint8_t cmd, const uint8_t *data, uint16_t size)
{
    lcd_write_command(cmd);
    if (data != NULL && size > 0U) {
        lcd_write_data(data, size);
    }
}

static void lcd_set_window(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1)
{
    uint8_t dbuf[4];
    dbuf[0] = (uint8_t)(x0 >> 8);
    dbuf[1] = (uint8_t)(x0 & 0xFFU);
    dbuf[2] = (uint8_t)(x1 >> 8);
    dbuf[3] = (uint8_t)(x1 & 0xFFU);
    lcd_write_register(0x2AU, dbuf, 4U);

    dbuf[0] = (uint8_t)(y0 >> 8);
    dbuf[1] = (uint8_t)(y0 & 0xFFU);
    dbuf[2] = (uint8_t)(y1 >> 8);
    dbuf[3] = (uint8_t)(y1 & 0xFFU);
    lcd_write_register(0x2BU, dbuf, 4U);
}

static void lcd_ram_write_begin(void)
{
    cs_low();
    dc_cmd();
    uint8_t ramwr = 0x2CU;
    spi_write(&ramwr, 1U);
    dc_data();
}

static void lcd_ram_write_end(void)
{
    cs_high();
}

/* =================================================================== */
/*  ST7796 initialisation (landscape, BGR)                              */
/* =================================================================== */
void ST7796_Init(void)
{
    /* --- Ensure touch chip is silent --- */
    HAL_GPIO_WritePin(CS2_GPIO_Port, CS2_Pin, GPIO_PIN_SET);
    blk_off();
    cs_high();

    /* --- Hardware reset sequence --- */
    res_high(); HAL_Delay(5);
    res_low();  HAL_Delay(20);
    res_high(); HAL_Delay(150);

    /* --- Unlock extended registers --- */
    static const uint8_t unlock1[] = {0xC3U};
    static const uint8_t unlock2[] = {0x96U};
    lcd_write_register(0xF0U, unlock1, sizeof(unlock1));
    lcd_write_register(0xF0U, unlock2, sizeof(unlock2));

    /* --- MADCTL: landscape, BGR ---
       0xEC = MY=1, MX=1, MV=1, BGR=1.
       Try 0x2C if the image appears left-right mirrored. */
    static const uint8_t madctl[]  = {0xECU};
    lcd_write_register(0x36U, madctl, sizeof(madctl));

    /* --- Pixel format: RGB565 (16 bpp) --- */
    static const uint8_t colmod[]  = {0x05U};
    lcd_write_register(0x3AU, colmod, sizeof(colmod));

    /* --- Driver timing / power --- */
    static const uint8_t b4[] = {0x01U};
    static const uint8_t b7[] = {0xC6U};
    static const uint8_t e8[] = {0x40U,0x8AU,0x00U,0x00U,0x29U,0x19U,0xA5U,0x33U};
    static const uint8_t c1[] = {0x06U};
    static const uint8_t c2[] = {0xA7U};
    static const uint8_t c5[] = {0x18U};
    lcd_write_register(0xB4U, b4, sizeof(b4));
    lcd_write_register(0xB7U, b7, sizeof(b7));
    lcd_write_register(0xE8U, e8, sizeof(e8));
    lcd_write_register(0xC1U, c1, sizeof(c1));
    lcd_write_register(0xC2U, c2, sizeof(c2));
    lcd_write_register(0xC5U, c5, sizeof(c5));

    /* --- Gamma (positive / negative) --- */
    static const uint8_t gamma_p[] = {
        0xF0U,0x09U,0x0BU,0x06U,0x04U,0x15U,0x2FU,0x54U,
        0x42U,0x3CU,0x17U,0x14U,0x18U,0x1BU
    };
    static const uint8_t gamma_n[] = {
        0xE0U,0x09U,0x0BU,0x06U,0x04U,0x03U,0x2BU,0x43U,
        0x42U,0x3BU,0x16U,0x14U,0x17U,0x1BU
    };
    lcd_write_register(0xE0U, gamma_p, sizeof(gamma_p));
    lcd_write_register(0xE1U, gamma_n, sizeof(gamma_n));

    /* --- Lock back + exit sleep --- */
    static const uint8_t lock1[] = {0x3CU};
    static const uint8_t lock2[] = {0x69U};
    lcd_write_register(0xF0U, lock1, sizeof(lock1));
    lcd_write_register(0xF0U, lock2, sizeof(lock2));

    lcd_write_command(0x13U);  HAL_Delay(20);   /* Normal display mode ON   */
    lcd_write_command(0x11U);  HAL_Delay(120);  /* Sleep out                */
    lcd_write_command(0x29U);  HAL_Delay(20);   /* Display ON               */

    /* --- Clear GRAM before enabling backlight --------------------------
       The ST7796 GRAM is NOT cleared by the hardware reset above — it
       retains whatever pixels were written during the previous power-on
       cycle.  When the screen is independently powered (e.g. across
       ST-LINK reflashes), old GRAM content would otherwise show through
       as a "ghost" overlay.  A full-screen clear here guarantees a
       clean slate before the backlight lights up. */
    LCD_Clear(BLACK);

    blk_on();
}

/* =================================================================== */
/*  Drawing primitives                                                  */
/* =================================================================== */

/**
  * @brief  Fill a rectangular area with a solid colour.
  */
void LCD_Fill(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint16_t color)
{
    /* Clip to screen boundaries (both lower and upper) */
    if (x0 >= LCD_WIDTH || y0 >= LCD_HEIGHT) return;
    if (x0 > x1 || y0 > y1) return;
    if (x1 >= LCD_WIDTH)  x1 = LCD_WIDTH  - 1U;
    if (y1 >= LCD_HEIGHT) y1 = LCD_HEIGHT - 1U;

    uint32_t pixels = (uint32_t)(x1 - x0 + 1U) * (y1 - y0 + 1U);

    lcd_set_window(x0, y0, x1, y1);
    lcd_ram_write_begin();
    spi_write16(color, pixels);
    lcd_ram_write_end();
}

/**
  * @brief  Clear the whole screen to a single colour.
  */
void LCD_Clear(uint16_t color)
{
    LCD_Fill(0U, 0U, LCD_WIDTH - 1U, LCD_HEIGHT - 1U, color);
}

/**
  * @brief  Draw a single pixel.
  */
void LCD_DrawPixel(uint16_t x, uint16_t y, uint16_t color)
{
    if (x >= LCD_WIDTH || y >= LCD_HEIGHT) return;
    lcd_set_window(x, y, x, y);
    lcd_ram_write_begin();
    uint8_t px[2] = { (uint8_t)(color >> 8), (uint8_t)(color & 0xFFU) };
    spi_write(px, 2U);
    lcd_ram_write_end();
}

/**
  * @brief  Bresenham line drawing (any angle).
  */
void LCD_DrawLine(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint16_t color)
{
    int16_t dx = (int16_t)x1 - (int16_t)x0;
    int16_t dy = (int16_t)y1 - (int16_t)y0;

    /* --- Horizontal line → fast fill --- */
    if (dy == 0) {
        if (x0 > x1) { uint16_t t = x0; x0 = x1; x1 = t; }
        LCD_Fill(x0, y0, x1, y0, color);
        return;
    }
    /* --- Vertical line → fast fill --- */
    if (dx == 0) {
        if (y0 > y1) { uint16_t t = y0; y0 = y1; y1 = t; }
        LCD_Fill(x0, y0, x0, y1, color);
        return;
    }

    /* --- Bresenham --- */
    int16_t sx = (dx > 0) ? 1 : -1;
    int16_t sy = (dy > 0) ? 1 : -1;
    dx = (dx > 0) ? dx : -dx;
    dy = (dy > 0) ? dy : -dy;

    int16_t err = dx - dy;
    int16_t cx = (int16_t)x0;
    int16_t cy = (int16_t)y0;

    while (1) {
        LCD_DrawPixel((uint16_t)cx, (uint16_t)cy, color);
        if (cx == (int16_t)x1 && cy == (int16_t)y1) break;
        int16_t e2 = err * 2;
        if (e2 > -dy) { err -= dy; cx += sx; }
        if (e2 <  dx) { err += dx; cy += sy; }
    }
}

/**
  * @brief  Hollow rectangle outline.
  */
void LCD_DrawRectangle(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint16_t color)
{
    LCD_DrawLine(x0, y0, x1, y0, color);  /* top    */
    LCD_DrawLine(x0, y1, x1, y1, color);  /* bottom */
    LCD_DrawLine(x0, y0, x0, y1, color);  /* left   */
    LCD_DrawLine(x1, y0, x1, y1, color);  /* right  */
}

/* =================================================================== */
/*  Text rendering (8×16 font)                                          */
/* =================================================================== */

static const uint8_t* font_get_glyph(char ch)
{
    if (ch < 0x20 || ch > 0x7E) {
        ch = 0x20;   /* fall back to space */
    }
    return g_font_8x16[(uint8_t)ch - 0x20U];
}

/**
  * @brief  Draw one 8×16 character at (x,y).  Does NOT clip — caller
  *         must ensure the glyph fits inside the visible area.
  */
void LCD_ShowChar(uint16_t x, uint16_t y, char ch, uint16_t color, uint16_t bg_color)
{
    const uint8_t *glyph = font_get_glyph(ch);

    lcd_set_window(x, y, (uint16_t)(x + FONT_WIDTH - 1U), (uint16_t)(y + FONT_HEIGHT - 1U));
    lcd_ram_write_begin();

    for (uint8_t row = 0U; row < FONT_HEIGHT; row++) {
        uint8_t line = glyph[row];
        for (uint8_t col = 0U; col < FONT_WIDTH; col++) {
            uint16_t c = (line & 0x80U) ? color : bg_color;
            uint8_t px[2] = { (uint8_t)(c >> 8), (uint8_t)(c & 0xFFU) };
            spi_write(px, 2U);
            line <<= 1;
        }
    }

    lcd_ram_write_end();
}

/**
  * @brief  Draw a null-terminated ASCII string starting at (x,y).
  *         Wraps to the next line when it hits the right edge.
  */
void LCD_ShowString(uint16_t x, uint16_t y, const char *str, uint16_t color, uint16_t bg_color)
{
    if (str == NULL) return;

    uint16_t cx = x;
    uint16_t cy = y;

    while (*str) {
        if (*str == '\n') {
            cx = x;
            cy = (uint16_t)(cy + FONT_HEIGHT);
            str++;
            continue;
        }
        /* Wrap if the next character would exceed the screen width */
        if ((uint32_t)cx + FONT_WIDTH > LCD_WIDTH) {
            cx = x;
            cy = (uint16_t)(cy + FONT_HEIGHT);
        }
        /* Stop if we've run out of vertical space */
        if ((uint32_t)cy + FONT_HEIGHT > LCD_HEIGHT) break;

        LCD_ShowChar(cx, cy, *str, color, bg_color);
        cx = (uint16_t)(cx + FONT_WIDTH);
        str++;
    }
}
