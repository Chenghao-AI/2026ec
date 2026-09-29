#include "graphics.h"

#include <stddef.h>

#include "st7796.h"

/*
 * Largest supported glyph block: (6 * scale) x (7 * scale), scale <= 4.
 * Keep it out of the small application stack. Graphics drawing is already
 * synchronous and non-reentrant, so one module-local buffer is sufficient.
 */
static uint16_t g_characterPixels[24U * 28U];

static const uint8_t g_digits[10][7] = {
    {0x0EU,0x11U,0x13U,0x15U,0x19U,0x11U,0x0EU},
    {0x04U,0x0CU,0x04U,0x04U,0x04U,0x04U,0x0EU},
    {0x0EU,0x11U,0x01U,0x02U,0x04U,0x08U,0x1FU},
    {0x1EU,0x01U,0x01U,0x0EU,0x01U,0x01U,0x1EU},
    {0x02U,0x06U,0x0AU,0x12U,0x1FU,0x02U,0x02U},
    {0x1FU,0x10U,0x10U,0x1EU,0x01U,0x01U,0x1EU},
    {0x0EU,0x10U,0x10U,0x1EU,0x11U,0x11U,0x0EU},
    {0x1FU,0x01U,0x02U,0x04U,0x08U,0x08U,0x08U},
    {0x0EU,0x11U,0x11U,0x0EU,0x11U,0x11U,0x0EU},
    {0x0EU,0x11U,0x11U,0x0FU,0x01U,0x01U,0x0EU}
};

static const uint8_t g_letters[26][7] = {
    {0x0EU,0x11U,0x11U,0x1FU,0x11U,0x11U,0x11U},
    {0x1EU,0x11U,0x11U,0x1EU,0x11U,0x11U,0x1EU},
    {0x0EU,0x11U,0x10U,0x10U,0x10U,0x11U,0x0EU},
    {0x1EU,0x11U,0x11U,0x11U,0x11U,0x11U,0x1EU},
    {0x1FU,0x10U,0x10U,0x1EU,0x10U,0x10U,0x1FU},
    {0x1FU,0x10U,0x10U,0x1EU,0x10U,0x10U,0x10U},
    {0x0EU,0x11U,0x10U,0x17U,0x11U,0x11U,0x0FU},
    {0x11U,0x11U,0x11U,0x1FU,0x11U,0x11U,0x11U},
    {0x1FU,0x04U,0x04U,0x04U,0x04U,0x04U,0x1FU},
    {0x07U,0x02U,0x02U,0x02U,0x12U,0x12U,0x0CU},
    {0x11U,0x12U,0x14U,0x18U,0x14U,0x12U,0x11U},
    {0x10U,0x10U,0x10U,0x10U,0x10U,0x10U,0x1FU},
    {0x11U,0x1BU,0x15U,0x15U,0x11U,0x11U,0x11U},
    {0x11U,0x19U,0x15U,0x13U,0x11U,0x11U,0x11U},
    {0x0EU,0x11U,0x11U,0x11U,0x11U,0x11U,0x0EU},
    {0x1EU,0x11U,0x11U,0x1EU,0x10U,0x10U,0x10U},
    {0x0EU,0x11U,0x11U,0x11U,0x15U,0x12U,0x0DU},
    {0x1EU,0x11U,0x11U,0x1EU,0x14U,0x12U,0x11U},
    {0x0FU,0x10U,0x10U,0x0EU,0x01U,0x01U,0x1EU},
    {0x1FU,0x04U,0x04U,0x04U,0x04U,0x04U,0x04U},
    {0x11U,0x11U,0x11U,0x11U,0x11U,0x11U,0x0EU},
    {0x11U,0x11U,0x11U,0x11U,0x11U,0x0AU,0x04U},
    {0x11U,0x11U,0x11U,0x15U,0x15U,0x1BU,0x11U},
    {0x11U,0x11U,0x0AU,0x04U,0x0AU,0x11U,0x11U},
    {0x11U,0x11U,0x0AU,0x04U,0x04U,0x04U,0x04U},
    {0x1FU,0x01U,0x02U,0x04U,0x08U,0x10U,0x1FU}
};

static const uint8_t *glyph_for(char character)
{
    static const uint8_t blank[7] = {0U,0U,0U,0U,0U,0U,0U};
    static const uint8_t dot[7]   = {0U,0U,0U,0U,0U,0x06U,0x06U};
    static const uint8_t comma[7] = {0U,0U,0U,0U,0x06U,0x04U,0x08U};
    static const uint8_t colon[7] = {0U,0x06U,0x06U,0U,0x06U,0x06U,0U};
    static const uint8_t dash[7]  = {0U,0U,0U,0x1FU,0U,0U,0U};
    static const uint8_t slash[7] = {0x01U,0x02U,0x02U,0x04U,0x08U,0x08U,0x10U};
    static const uint8_t plus[7]  = {0U,0x04U,0x04U,0x1FU,0x04U,0x04U,0U};
    static const uint8_t percent[7] = {0x19U,0x1AU,0x02U,0x04U,0x08U,0x0BU,0x13U};
    static const uint8_t equal[7] = {0U,0x1FU,0U,0x1FU,0U,0U,0U};
    static const uint8_t leftParen[7] = {0x02U,0x04U,0x08U,0x08U,0x08U,0x04U,0x02U};
    static const uint8_t rightParen[7] = {0x08U,0x04U,0x02U,0x02U,0x02U,0x04U,0x08U};

    if ((character >= 'a') && (character <= 'z')) {
        character = (char)(character - 'a' + 'A');
    }
    if ((character >= '0') && (character <= '9')) {
        return g_digits[(uint8_t)(character - '0')];
    }
    if ((character >= 'A') && (character <= 'Z')) {
        return g_letters[(uint8_t)(character - 'A')];
    }
    switch (character) {
        case '.': return dot;
        case ',': return comma;
        case ':': return colon;
        case '-': return dash;
        case '/': return slash;
        case '+': return plus;
        case '%': return percent;
        case '=': return equal;
        case '(': return leftParen;
        case ')': return rightParen;
        default:  return blank;
    }
}

static uint8_t line_outcode(int32_t x, int32_t y)
{
    uint8_t code = 0U;

    if (x < 0) {
        code |= 1U;
    } else if (x >= (int32_t)ST7796_WIDTH) {
        code |= 2U;
    }
    if (y < 0) {
        code |= 4U;
    } else if (y >= (int32_t)ST7796_HEIGHT) {
        code |= 8U;
    }
    return code;
}

static uint8_t clip_line(int32_t *x0, int32_t *y0,
                         int32_t *x1, int32_t *y1)
{
    uint8_t code0 = line_outcode(*x0, *y0);
    uint8_t code1 = line_outcode(*x1, *y1);

    while (1) {
        uint8_t outside;
        int32_t x;
        int32_t y;

        if ((code0 | code1) == 0U) {
            return 1U;
        }
        if ((code0 & code1) != 0U) {
            return 0U;
        }

        outside = (code0 != 0U) ? code0 : code1;

        if ((outside & 8U) != 0U) {
            if (*y1 == *y0) return 0U;
            y = (int32_t)ST7796_HEIGHT - 1;
            x = *x0 + (*x1 - *x0) * (y - *y0) / (*y1 - *y0);
        } else if ((outside & 4U) != 0U) {
            if (*y1 == *y0) return 0U;
            y = 0;
            x = *x0 + (*x1 - *x0) * (y - *y0) / (*y1 - *y0);
        } else if ((outside & 2U) != 0U) {
            if (*x1 == *x0) return 0U;
            x = (int32_t)ST7796_WIDTH - 1;
            y = *y0 + (*y1 - *y0) * (x - *x0) / (*x1 - *x0);
        } else {
            if (*x1 == *x0) return 0U;
            x = 0;
            y = *y0 + (*y1 - *y0) * (x - *x0) / (*x1 - *x0);
        }

        if (outside == code0) {
            *x0 = x;
            *y0 = y;
            code0 = line_outcode(*x0, *y0);
        } else {
            *x1 = x;
            *y1 = y;
            code1 = line_outcode(*x1, *y1);
        }
    }
}

static uint8_t append_char(char *buffer, uint8_t length,
                           uint8_t capacity, char value)
{
    if ((uint8_t)(length + 1U) < capacity) {
        buffer[length++] = value;
        buffer[length] = '\0';
    }
    return length;
}

static uint8_t append_uint(char *buffer, uint8_t length,
                           uint8_t capacity, uint32_t value,
                           uint8_t minimumDigits)
{
    char reverse[10];
    uint8_t count = 0U;

    do {
        reverse[count++] = (char)('0' + (value % 10U));
        value /= 10U;
    } while ((value != 0U) && (count < sizeof(reverse)));

    while ((count < minimumDigits) && (count < sizeof(reverse))) {
        reverse[count++] = '0';
    }
    while (count > 0U) {
        length = append_char(buffer, length, capacity, reverse[--count]);
    }
    return length;
}

static uint8_t format_int(char *buffer, uint8_t capacity, int32_t value)
{
    uint8_t length = 0U;
    uint32_t magnitude;

    buffer[0] = '\0';
    if (value < 0) {
        length = append_char(buffer, length, capacity, '-');
        magnitude = (uint32_t)(-(value + 1)) + 1U;
    } else {
        magnitude = (uint32_t)value;
    }
    return append_uint(buffer, length, capacity, magnitude, 1U);
}

static uint8_t format_uint(char *buffer, uint8_t capacity, uint32_t value)
{
    buffer[0] = '\0';
    return append_uint(buffer, 0U, capacity, value, 1U);
}

static uint8_t format_float(char *buffer, uint8_t capacity,
                            float value, uint8_t decimals)
{
    uint32_t multiplier = 1U;
    uint32_t scaled;
    uint32_t integerPart;
    uint32_t fraction;
    uint8_t length = 0U;
    uint8_t index;

    if (decimals > 4U) {
        decimals = 4U;
    }
    for (index = 0U; index < decimals; index++) {
        multiplier *= 10U;
    }

    buffer[0] = '\0';
    if (value < 0.0F) {
        length = append_char(buffer, length, capacity, '-');
        value = -value;
    }
    if (value > 429000.0F) {
        length = append_char(buffer, length, capacity, 'O');
        length = append_char(buffer, length, capacity, 'V');
        length = append_char(buffer, length, capacity, 'F');
        return length;
    }

    scaled = (uint32_t)(value * (float)multiplier + 0.5F);
    integerPart = scaled / multiplier;
    fraction = scaled % multiplier;
    length = append_uint(buffer, length, capacity, integerPart, 1U);
    if (decimals > 0U) {
        length = append_char(buffer, length, capacity, '.');
        length = append_uint(buffer, length, capacity, fraction, decimals);
    }
    return length;
}

void Graphics_DrawPixel(int16_t x, int16_t y, uint16_t color)
{
    if ((x >= 0) && (y >= 0) &&
        (x < (int16_t)ST7796_WIDTH) && (y < (int16_t)ST7796_HEIGHT)) {
        ST7796_FillRect((uint16_t)x, (uint16_t)y, 1U, 1U, color);
    }
}

void Graphics_DrawLine(int16_t x0Value, int16_t y0Value,
                       int16_t x1Value, int16_t y1Value, uint16_t color)
{
    int32_t x0 = x0Value;
    int32_t y0 = y0Value;
    int32_t x1 = x1Value;
    int32_t y1 = y1Value;
    int32_t deltaX;
    int32_t deltaY;
    int32_t stepX;
    int32_t stepY;
    int32_t error;

    if (clip_line(&x0, &y0, &x1, &y1) == 0U) {
        return;
    }
    if (y0 == y1) {
        uint16_t left = (uint16_t)((x0 < x1) ? x0 : x1);
        uint16_t width = (uint16_t)(((x0 < x1) ? x1 - x0 : x0 - x1) + 1);
        ST7796_DrawHLine(left, (uint16_t)y0, width, color);
        return;
    }
    if (x0 == x1) {
        uint16_t top = (uint16_t)((y0 < y1) ? y0 : y1);
        uint16_t height = (uint16_t)(((y0 < y1) ? y1 - y0 : y0 - y1) + 1);
        ST7796_DrawVLine((uint16_t)x0, top, height, color);
        return;
    }

    deltaX = (x1 > x0) ? (x1 - x0) : (x0 - x1);
    deltaY = -((y1 > y0) ? (y1 - y0) : (y0 - y1));
    stepX = (x0 < x1) ? 1 : -1;
    stepY = (y0 < y1) ? 1 : -1;
    error = deltaX + deltaY;

    while (1) {
        int32_t doubleError;

        Graphics_DrawPixel((int16_t)x0, (int16_t)y0, color);
        if ((x0 == x1) && (y0 == y1)) {
            break;
        }
        doubleError = 2 * error;
        if (doubleError >= deltaY) {
            error += deltaY;
            x0 += stepX;
        }
        if (doubleError <= deltaX) {
            error += deltaX;
            y0 += stepY;
        }
    }
}

void Graphics_DrawPolyline(const GraphicsPoint *points, uint16_t count,
                           uint16_t color)
{
    uint16_t index;

    if ((points == NULL) || (count < 2U)) {
        return;
    }
    for (index = 1U; index < count; index++) {
        Graphics_DrawLine(points[index - 1U].x, points[index - 1U].y,
                          points[index].x, points[index].y, color);
    }
}

void Graphics_DrawCircle(int16_t centerX, int16_t centerY, int16_t radius,
                         uint16_t color)
{
    int16_t x;
    int16_t y;
    int16_t error;

    if (radius < 0) {
        return;
    }
    x = radius;
    y = 0;
    error = (int16_t)(1 - radius);
    while (x >= y) {
        Graphics_DrawPixel((int16_t)(centerX + x), (int16_t)(centerY + y), color);
        Graphics_DrawPixel((int16_t)(centerX + y), (int16_t)(centerY + x), color);
        Graphics_DrawPixel((int16_t)(centerX - y), (int16_t)(centerY + x), color);
        Graphics_DrawPixel((int16_t)(centerX - x), (int16_t)(centerY + y), color);
        Graphics_DrawPixel((int16_t)(centerX - x), (int16_t)(centerY - y), color);
        Graphics_DrawPixel((int16_t)(centerX - y), (int16_t)(centerY - x), color);
        Graphics_DrawPixel((int16_t)(centerX + y), (int16_t)(centerY - x), color);
        Graphics_DrawPixel((int16_t)(centerX + x), (int16_t)(centerY - y), color);
        y++;
        if (error < 0) {
            error = (int16_t)(error + 2 * y + 1);
        } else {
            x--;
            error = (int16_t)(error + 2 * (y - x) + 1);
        }
    }
}

void Graphics_FillCircle(int16_t centerX, int16_t centerY, int16_t radius,
                         uint16_t color)
{
    int16_t x;
    int16_t y;
    int16_t error;

    if (radius < 0) {
        return;
    }
    x = radius;
    y = 0;
    error = (int16_t)(1 - radius);
    while (x >= y) {
        Graphics_DrawLine((int16_t)(centerX - x), (int16_t)(centerY + y),
                          (int16_t)(centerX + x), (int16_t)(centerY + y), color);
        Graphics_DrawLine((int16_t)(centerX - x), (int16_t)(centerY - y),
                          (int16_t)(centerX + x), (int16_t)(centerY - y), color);
        Graphics_DrawLine((int16_t)(centerX - y), (int16_t)(centerY + x),
                          (int16_t)(centerX + y), (int16_t)(centerY + x), color);
        Graphics_DrawLine((int16_t)(centerX - y), (int16_t)(centerY - x),
                          (int16_t)(centerX + y), (int16_t)(centerY - x), color);
        y++;
        if (error < 0) {
            error = (int16_t)(error + 2 * y + 1);
        } else {
            x--;
            error = (int16_t)(error + 2 * (y - x) + 1);
        }
    }
}

uint16_t Graphics_TextWidth(const char *text, uint8_t scale)
{
    uint16_t characters = 0U;

    if ((text == NULL) || (scale == 0U) || (scale > 4U)) {
        return 0U;
    }
    while (*text++ != '\0') {
        characters++;
    }
    return (uint16_t)(characters * 6U * scale);
}

uint16_t Graphics_TextHeight(uint8_t scale)
{
    if ((scale == 0U) || (scale > 4U)) {
        return 0U;
    }
    return (uint16_t)(7U * scale);
}

void Graphics_DrawChar(uint16_t x, uint16_t y, char character,
                       uint8_t scale, uint16_t foreground,
                       uint16_t background)
{
    const uint8_t *glyph;
    uint16_t width;
    uint16_t height;
    uint16_t px;
    uint16_t py;
    uint8_t sourceX;
    uint8_t sourceY;

    if ((scale == 0U) || (scale > 4U)) {
        return;
    }
    width = (uint16_t)(6U * scale);
    height = (uint16_t)(7U * scale);
    if (((uint32_t)x + width > ST7796_WIDTH) ||
        ((uint32_t)y + height > ST7796_HEIGHT)) {
        return;
    }

    glyph = glyph_for(character);
    for (py = 0U; py < height; py++) {
        sourceY = (uint8_t)(py / scale);
        for (px = 0U; px < width; px++) {
            sourceX = (uint8_t)(px / scale);
            if ((sourceX < 5U) &&
                ((glyph[sourceY] & (uint8_t)(0x10U >> sourceX)) != 0U)) {
                g_characterPixels[(uint32_t)py * width + px] = foreground;
            } else {
                g_characterPixels[(uint32_t)py * width + px] = background;
            }
        }
    }
    ST7796_DrawRGB565(x, y, width, height, g_characterPixels);
}

void Graphics_DrawText(uint16_t x, uint16_t y, const char *text,
                       uint8_t scale, uint16_t foreground,
                       uint16_t background)
{
    uint16_t characterWidth;

    if ((text == NULL) || (scale == 0U) || (scale > 4U)) {
        return;
    }
    characterWidth = (uint16_t)(6U * scale);
    while (*text != '\0') {
        if (((uint32_t)x + characterWidth > ST7796_WIDTH) ||
            ((uint32_t)y + 7U * scale > ST7796_HEIGHT)) {
            break;
        }
        Graphics_DrawChar(x, y, *text++, scale, foreground, background);
        x = (uint16_t)(x + characterWidth);
    }
}

void Graphics_DrawInt(uint16_t x, uint16_t y, int32_t value,
                      uint8_t scale, uint16_t foreground,
                      uint16_t background)
{
    char buffer[16];
    (void)format_int(buffer, sizeof(buffer), value);
    Graphics_DrawText(x, y, buffer, scale, foreground, background);
}

void Graphics_DrawUInt(uint16_t x, uint16_t y, uint32_t value,
                       uint8_t scale, uint16_t foreground,
                       uint16_t background)
{
    char buffer[16];
    (void)format_uint(buffer, sizeof(buffer), value);
    Graphics_DrawText(x, y, buffer, scale, foreground, background);
}

void Graphics_DrawFloat(uint16_t x, uint16_t y, float value,
                        uint8_t decimals, uint8_t scale,
                        uint16_t foreground, uint16_t background)
{
    char buffer[24];
    (void)format_float(buffer, sizeof(buffer), value, decimals);
    Graphics_DrawText(x, y, buffer, scale, foreground, background);
}

void Graphics_DrawIntWithUnit(uint16_t x, uint16_t y, int32_t value,
                              const char *unit, uint8_t scale,
                              uint16_t foreground, uint16_t background)
{
    char buffer[32];
    uint8_t length = format_int(buffer, sizeof(buffer), value);

    if ((unit != NULL) && (*unit != '\0')) {
        length = append_char(buffer, length, sizeof(buffer), ' ');
        while (*unit != '\0') {
            length = append_char(buffer, length, sizeof(buffer), *unit++);
        }
    }
    Graphics_DrawText(x, y, buffer, scale, foreground, background);
}

void Graphics_DrawFloatWithUnit(uint16_t x, uint16_t y, float value,
                                uint8_t decimals, const char *unit,
                                uint8_t scale, uint16_t foreground,
                                uint16_t background)
{
    char buffer[32];
    uint8_t length = format_float(buffer, sizeof(buffer), value, decimals);

    if ((unit != NULL) && (*unit != '\0')) {
        length = append_char(buffer, length, sizeof(buffer), ' ');
        while (*unit != '\0') {
            length = append_char(buffer, length, sizeof(buffer), *unit++);
        }
    }
    Graphics_DrawText(x, y, buffer, scale, foreground, background);
}
