/**
  ******************************************************************************
  * @file    lcd_st7796.h
  * @brief   ST7796 480x320 landscape LCD driver header
  *
  *          Pin mapping (matches screen_plus CubeMX config):
  *            CS1  (PB12) = LCD chip select (active low)
  *            DC   (PB13) = Data(High) / Command(Low)
  *            RES  (PB14) = Hardware reset
  *            BLK  (PB15) = Backlight control
  *            CS2  (PC4)  = Touch-panel CS (held high to disable)
  *            SCK  (PB3)  = SPI1_SCK
  *            MOSI (PA7)  = SPI1_MOSI
  *            MISO (PA6)  = SPI1_MISO
  ******************************************************************************
  */
#ifndef __LCD_ST7796_H
#define __LCD_ST7796_H

#include "main.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/*  Landscape dimensions (panel held horizontally)                     */
/* ------------------------------------------------------------------ */
#define LCD_WIDTH   480U
#define LCD_HEIGHT  320U

/* ------------------------------------------------------------------ */
/*  RGB565 colour constants                                            */
/* ------------------------------------------------------------------ */
#define LCD_COLOR_BLACK   0x0000U
#define LCD_COLOR_BLUE    0x001FU
#define LCD_COLOR_RED     0xF800U
#define LCD_COLOR_GREEN   0x07E0U
#define LCD_COLOR_WHITE   0xFFFFU
#define LCD_COLOR_YELLOW  0xFFE0U
#define LCD_COLOR_CYAN    0x07FFU
#define LCD_COLOR_MAGENTA 0xF81FU
#define LCD_COLOR_GRAY    0x8410U
#define LCD_COLOR_ORANGE  0xFC00U

/* Convenience aliases for the spectrum-display code */
#define BLACK   LCD_COLOR_BLACK
#define BLUE    LCD_COLOR_BLUE
#define RED     LCD_COLOR_RED
#define GREEN   LCD_COLOR_GREEN
#define WHITE   LCD_COLOR_WHITE
#define YELLOW  LCD_COLOR_YELLOW
#define GRAY    LCD_COLOR_GRAY

/* ------------------------------------------------------------------ */
/*  Font metrics                                                       */
/* ------------------------------------------------------------------ */
#define FONT_WIDTH   8U
#define FONT_HEIGHT 16U

/* ------------------------------------------------------------------ */
/*  Public API                                                         */
/* ------------------------------------------------------------------ */
void  ST7796_Init(void);
void  LCD_Clear(uint16_t color);
void  LCD_Fill(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint16_t color);
void  LCD_DrawPixel(uint16_t x, uint16_t y, uint16_t color);
void  LCD_DrawLine(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint16_t color);
void  LCD_DrawRectangle(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint16_t color);
void  LCD_ShowChar(uint16_t x, uint16_t y, char ch, uint16_t color, uint16_t bg_color);
void  LCD_ShowString(uint16_t x, uint16_t y, const char *str, uint16_t color, uint16_t bg_color);

#ifdef __cplusplus
}
#endif

#endif /* __LCD_ST7796_H */
