#include "plot.h"

#include <stddef.h>

#include "st7796.h"

const PlotStyle PLOT_STYLE_DARK = {
    RGB565(9U, 25U, 40U),
    RGB565(27U, 57U, 74U),
    RGB565(134U, 163U, 178U),
    RGB565(34U, 211U, 238U),
    RGB565(34U, 160U, 176U),
    8U,
    6U,
    2U,
    true,
    true
};

static uint16_t g_plotRow[ST7796_WIDTH];
static int16_t g_traceY[ST7796_WIDTH];
static int16_t g_traceBottomY[ST7796_WIDTH];

static bool valid_area(uint16_t x, uint16_t y, uint16_t width,
                       uint16_t height)
{
    return (width >= 3U) && (height >= 3U) &&
           (((uint32_t)x + width) <= ST7796_WIDTH) &&
           (((uint32_t)y + height) <= ST7796_HEIGHT);
}

static bool grid_at(uint16_t position, uint16_t span, uint8_t divisions)
{
    uint8_t division;

    if ((divisions == 0U) || (span < 2U)) {
        return false;
    }
    for (division = 1U; division < divisions; division++) {
        if (position == (uint16_t)(((uint32_t)division * (span - 1U)) /
                                  divisions)) {
            return true;
        }
    }
    return false;
}

static int16_t value_to_y(int32_t value, int32_t minimum,
                          int32_t maximum, uint16_t height)
{
    int32_t innerHeight = (int32_t)height - 3;
    int32_t result;

    if (value < minimum) value = minimum;
    if (value > maximum) value = maximum;
    result = 1 + ((maximum - value) * innerHeight) / (maximum - minimum);
    return (int16_t)result;
}

static uint16_t base_pixel(uint16_t localX, uint16_t localY,
                           uint16_t width, uint16_t height,
                           int16_t zeroY, const PlotStyle *style)
{
    if (style->drawBorder &&
        ((localX == 0U) || (localY == 0U) ||
         (localX == (uint16_t)(width - 1U)) ||
         (localY == (uint16_t)(height - 1U)))) {
        return style->borderColor;
    }
    if (style->drawZeroAxis && (zeroY >= 0) &&
        (localY == (uint16_t)zeroY)) {
        return style->axisColor;
    }
    if (grid_at(localX, width, style->xDivisions) ||
        grid_at(localY, height, style->yDivisions)) {
        return style->gridColor;
    }
    return style->backgroundColor;
}

void Plot_DrawGrid(uint16_t x, uint16_t y, uint16_t width,
                   uint16_t height, int16_t minimum, int16_t maximum,
                   const PlotStyle *style)
{
    uint16_t localX;
    uint16_t localY;
    int16_t zeroY = -1;

    if ((style == NULL) || !valid_area(x, y, width, height) ||
        (maximum <= minimum)) {
        return;
    }
    if ((minimum <= 0) && (maximum >= 0)) {
        zeroY = value_to_y(0, minimum, maximum, height);
    }
    for (localY = 0U; localY < height; localY++) {
        for (localX = 0U; localX < width; localX++) {
            g_plotRow[localX] = base_pixel(localX, localY, width, height,
                                                zeroY, style);
        }
        ST7796_DrawRGB565(x, (uint16_t)(y + localY), width, 1U, g_plotRow);
    }
}

bool Plot_DrawWaveform(uint16_t x, uint16_t y, uint16_t width,
                       uint16_t height, const int16_t *samples,
                       uint16_t sampleCount, int16_t minimum,
                       int16_t maximum, const PlotStyle *style)
{
    uint16_t localX;
    uint16_t localY;
    uint16_t thickness;
    int16_t zeroY = -1;

    if ((samples == NULL) || (style == NULL) || (sampleCount < 2U) ||
        !valid_area(x, y, width, height) || (maximum <= minimum)) {
        return false;
    }

    for (localX = 0U; localX < width; localX++) {
        uint32_t position = ((uint32_t)localX * (sampleCount - 1U));
        uint16_t index = (uint16_t)(position / (width - 1U));
        uint16_t remainder = (uint16_t)(position % (width - 1U));
        int32_t value;

        if (index >= (uint16_t)(sampleCount - 1U)) {
            value = samples[sampleCount - 1U];
        } else {
            value = samples[index] +
                    ((int32_t)(samples[index + 1U] - samples[index]) *
                     remainder) / (width - 1U);
        }
        g_traceY[localX] = value_to_y(value, minimum, maximum, height);
    }

    if ((minimum <= 0) && (maximum >= 0)) {
        zeroY = value_to_y(0, minimum, maximum, height);
    }
    thickness = (style->traceThickness == 0U) ? 1U : style->traceThickness;

    for (localY = 0U; localY < height; localY++) {
        for (localX = 0U; localX < width; localX++) {
            int16_t firstY = g_traceY[(localX == 0U) ? 0U : localX - 1U];
            int16_t secondY = g_traceY[localX];
            int16_t low = (firstY < secondY) ? firstY : secondY;
            int16_t high = (firstY > secondY) ? firstY : secondY;
            int16_t half = (int16_t)(thickness / 2U);

            g_plotRow[localX] = base_pixel(localX, localY, width, height,
                                           zeroY, style);
            low = (int16_t)(low - half);
            high = (int16_t)(high + (int16_t)(thickness - 1U - half));
            if (((int16_t)localY >= low) && ((int16_t)localY <= high)) {
                g_plotRow[localX] = style->traceColor;
            }
        }
        ST7796_DrawRGB565(x, (uint16_t)(y + localY), width, 1U, g_plotRow);
    }
    return true;
}

bool Plot_DrawWaveformEnvelope(uint16_t x, uint16_t y, uint16_t width,
                               uint16_t height,
                               const int16_t *minimumValues,
                               const int16_t *maximumValues,
                               uint16_t columnCount, int16_t minimum,
                               int16_t maximum, const PlotStyle *style)
{
    uint16_t localX;
    uint16_t localY;
    uint16_t thickness;
    int16_t zeroY = -1;

    if ((minimumValues == NULL) || (maximumValues == NULL) ||
        (style == NULL) || (columnCount == 0U) ||
        !valid_area(x, y, width, height) || (maximum <= minimum)) {
        return false;
    }

    for (localX = 0U; localX < width; localX++) {
        uint16_t column = (uint16_t)(((uint32_t)localX * columnCount) /
                                     width);
        int16_t firstValue;
        int16_t secondValue;
        int16_t firstY;
        int16_t secondY;

        if (column >= columnCount) {
            column = (uint16_t)(columnCount - 1U);
        }
        firstValue = minimumValues[column];
        secondValue = maximumValues[column];
        firstY = value_to_y(firstValue, minimum, maximum, height);
        secondY = value_to_y(secondValue, minimum, maximum, height);
        g_traceY[localX] = (firstY < secondY) ? firstY : secondY;
        g_traceBottomY[localX] = (firstY > secondY) ? firstY : secondY;
    }

    if ((minimum <= 0) && (maximum >= 0)) {
        zeroY = value_to_y(0, minimum, maximum, height);
    }
    thickness = (style->traceThickness == 0U) ? 1U :
                style->traceThickness;

    for (localY = 0U; localY < height; localY++) {
        for (localX = 0U; localX < width; localX++) {
            int16_t half = (int16_t)(thickness / 2U);
            int16_t top = (int16_t)(g_traceY[localX] - half);
            int16_t bottom = (int16_t)(
                g_traceBottomY[localX] +
                (int16_t)(thickness - 1U - half));

            g_plotRow[localX] = base_pixel(localX, localY, width, height,
                                           zeroY, style);
            if (((int16_t)localY >= top) &&
                ((int16_t)localY <= bottom)) {
                g_plotRow[localX] = style->traceColor;
            }
        }
        ST7796_DrawRGB565(x, (uint16_t)(y + localY), width, 1U, g_plotRow);
    }
    return true;
}

bool Plot_GetWaveformRange(const int16_t *samples, uint16_t sampleCount,
                           bool symmetric, int16_t *minimum,
                           int16_t *maximum)
{
    uint16_t index;
    int32_t low;
    int32_t high;

    if ((samples == NULL) || (sampleCount == 0U) ||
        (minimum == NULL) || (maximum == NULL)) {
        return false;
    }
    low = samples[0];
    high = samples[0];
    for (index = 1U; index < sampleCount; index++) {
        if (samples[index] < low) low = samples[index];
        if (samples[index] > high) high = samples[index];
    }

    if (symmetric) {
        int32_t magnitudeLow = (low < 0) ? -low : low;
        int32_t magnitudeHigh = (high < 0) ? -high : high;
        int32_t magnitude = (magnitudeLow > magnitudeHigh) ?
                            magnitudeLow : magnitudeHigh;

        if (magnitude == 0) magnitude = 1;
        if (magnitude > 32767) magnitude = 32767;
        low = -magnitude;
        high = magnitude;
    } else {
        int32_t span = high - low;
        int32_t margin;

        if (span == 0) span = 2;
        margin = span / 20;
        if (margin < 1) margin = 1;
        low -= margin;
        high += margin;
        if (low < -32768) low = -32768;
        if (high > 32767) high = 32767;
        if (high <= low) {
            if (low < 32767) high = low + 1;
            else low = high - 1;
        }
    }

    *minimum = (int16_t)low;
    *maximum = (int16_t)high;
    return true;
}

bool Plot_DrawWaveformAuto(uint16_t x, uint16_t y, uint16_t width,
                           uint16_t height, const int16_t *samples,
                           uint16_t sampleCount, bool symmetric,
                           const PlotStyle *style)
{
    int16_t minimum;
    int16_t maximum;

    if (!Plot_GetWaveformRange(samples, sampleCount, symmetric,
                               &minimum, &maximum)) {
        return false;
    }
    return Plot_DrawWaveform(x, y, width, height, samples, sampleCount,
                             minimum, maximum, style);
}

bool Plot_DrawSpectrum(uint16_t x, uint16_t y, uint16_t width,
                       uint16_t height, const uint16_t *magnitudes,
                       uint16_t binCount, uint16_t maximum,
                       const PlotStyle *style)
{
    uint16_t localX;
    uint16_t localY;
    uint16_t baseline;
    uint16_t dataStart;
    uint16_t dataWidth;

    if ((magnitudes == NULL) || (style == NULL) || (binCount == 0U) ||
        (maximum == 0U) || !valid_area(x, y, width, height)) {
        return false;
    }
    baseline = (uint16_t)(height - 2U);
    dataStart = style->drawBorder ? 1U : 0U;
    dataWidth = style->drawBorder ? (uint16_t)(width - 2U) : width;

    for (localY = 0U; localY < height; localY++) {
        for (localX = 0U; localX < width; localX++) {
            bool dataColumn = (localX >= dataStart) &&
                              (localX < (uint16_t)(dataStart + dataWidth));
            uint16_t barTop = baseline;

            if (dataColumn) {
                uint16_t dataX = (uint16_t)(localX - dataStart);
                uint16_t bin;
                uint32_t magnitude;
                uint16_t barHeight;

                if ((dataWidth <= 1U) || (binCount <= 1U)) {
                    bin = 0U;
                } else {
                    bin = (uint16_t)(((uint32_t)dataX *
                                      (binCount - 1U)) /
                                     (dataWidth - 1U));
                }
                magnitude = magnitudes[bin];
                if (magnitude > maximum) magnitude = maximum;
                barHeight = (uint16_t)(
                    (magnitude * (height - 3U)) / maximum);
                barTop = (uint16_t)(baseline - barHeight);
            }

            g_plotRow[localX] = base_pixel(localX, localY, width, height,
                                           (int16_t)baseline, style);
            if (dataColumn && (localY >= barTop) &&
                (localY <= baseline)) {
                g_plotRow[localX] = style->traceColor;
            }
        }
        ST7796_DrawRGB565(x, (uint16_t)(y + localY), width, 1U, g_plotRow);
    }
    return true;
}

bool Plot_DrawSpectrumAuto(uint16_t x, uint16_t y, uint16_t width,
                           uint16_t height, const uint16_t *magnitudes,
                           uint16_t binCount, const PlotStyle *style)
{
    uint16_t index;
    uint32_t maximum = 0U;

    if ((magnitudes == NULL) || (binCount == 0U)) {
        return false;
    }
    for (index = 0U; index < binCount; index++) {
        if (magnitudes[index] > maximum) maximum = magnitudes[index];
    }
    if (maximum == 0U) {
        maximum = 1U;
    } else {
        maximum += maximum / 10U;
        if (maximum > 65535U) maximum = 65535U;
    }
    return Plot_DrawSpectrum(x, y, width, height, magnitudes, binCount,
                             (uint16_t)maximum, style);
}
