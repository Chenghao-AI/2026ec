#include "signal_display.h"

#include <stddef.h>

/*
 * Waveform and spectrum drawing are synchronous, so all temporary formats can
 * share one 1920-byte workspace. A large waveform needs two 480-element arrays
 * because every display column stores both its minimum and maximum value.
 */
typedef union {
    struct {
        int16_t minimum[SIGNAL_DISPLAY_MAX_POINTS];
        int16_t maximum[SIGNAL_DISPLAY_MAX_POINTS];
    } envelope;
    int16_t waveform[SIGNAL_DISPLAY_MAX_POINTS];
    uint16_t spectrum[SIGNAL_DISPLAY_MAX_POINTS];
} SignalDisplayBuffer;

static SignalDisplayBuffer g_signalDisplayBuffer;

static bool valid_map(const SignalLinearMap *map)
{
    return (map != NULL) && (map->inputMaximum > map->inputMinimum);
}

static bool valid_plot_area(uint16_t x, uint16_t y, uint16_t width,
                            uint16_t height, const PlotStyle *style)
{
    return (style != NULL) &&
           (width >= 3U) && (height >= 3U) &&
           (width <= SIGNAL_DISPLAY_MAX_POINTS) &&
           (((uint32_t)x + width) <= ST7796_WIDTH) &&
           (((uint32_t)y + height) <= ST7796_HEIGHT);
}

static uint16_t spectrum_data_columns(uint16_t width,
                                      const PlotStyle *style)
{
    return style->drawBorder ? (uint16_t)(width - 2U) : width;
}

/*
 * Return floor(index * total / bucketCount) without overflowing a 32-bit
 * multiplication. bucketCount is at most 480 in all high-level calls.
 */
static uint32_t bucket_boundary(uint16_t index, uint32_t total,
                                uint16_t bucketCount)
{
    uint32_t quotient = total / bucketCount;
    uint32_t remainder = total % bucketCount;

    return quotient * index + (remainder * index) / bucketCount;
}

static int16_t map_u16_to_i16(uint16_t input,
                              const SignalLinearMap *map)
{
    int32_t outputSpan;
    uint32_t inputSpan;
    uint32_t offset;
    int64_t numerator;
    int64_t mapped;

    if (input < map->inputMinimum) {
        input = map->inputMinimum;
    } else if (input > map->inputMaximum) {
        input = map->inputMaximum;
    }

    inputSpan = (uint32_t)map->inputMaximum - map->inputMinimum;
    outputSpan = (int32_t)map->outputMaximum - map->outputMinimum;
    offset = (uint32_t)input - map->inputMinimum;
    numerator = (int64_t)offset * outputSpan;

    /* Round to the nearest integer for both normal and inverted mappings. */
    if (numerator >= 0) {
        numerator += (int64_t)inputSpan / 2;
    } else {
        numerator -= (int64_t)inputSpan / 2;
    }
    mapped = (int64_t)map->outputMinimum + numerator / inputSpan;

    if (mapped < INT16_MIN) {
        mapped = INT16_MIN;
    } else if (mapped > INT16_MAX) {
        mapped = INT16_MAX;
    }
    return (int16_t)mapped;
}

static uint16_t scale_u32_to_u16(uint32_t input,
                                 uint32_t inputFullScale,
                                 uint16_t outputFullScale)
{
    uint64_t scaled;

    if (input >= inputFullScale) {
        return outputFullScale;
    }
    scaled = (uint64_t)input * outputFullScale + inputFullScale / 2U;
    return (uint16_t)(scaled / inputFullScale);
}

static bool envelope_range(const int16_t *minimumValues,
                           const int16_t *maximumValues,
                           uint16_t columnCount, bool symmetric,
                           int16_t *minimum, int16_t *maximum)
{
    uint16_t index;
    int32_t low;
    int32_t high;

    if ((minimumValues == NULL) || (maximumValues == NULL) ||
        (columnCount == 0U) || (minimum == NULL) || (maximum == NULL)) {
        return false;
    }

    low = minimumValues[0];
    high = maximumValues[0];
    for (index = 0U; index < columnCount; index++) {
        if (minimumValues[index] < low) low = minimumValues[index];
        if (minimumValues[index] > high) high = minimumValues[index];
        if (maximumValues[index] < low) low = maximumValues[index];
        if (maximumValues[index] > high) high = maximumValues[index];
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
        if (low < INT16_MIN) low = INT16_MIN;
        if (high > INT16_MAX) high = INT16_MAX;
        if (high <= low) {
            if (low < INT16_MAX) high = low + 1;
            else low = high - 1;
        }
    }

    *minimum = (int16_t)low;
    *maximum = (int16_t)high;
    return true;
}

bool Signal_ConvertU16ToI16(const uint16_t *input, uint32_t inputCount,
                            const SignalLinearMap *map, int16_t *output,
                            uint32_t outputCapacity)
{
    uint32_t index;

    if ((input == NULL) || (output == NULL) || !valid_map(map) ||
        (inputCount == 0U) || (outputCapacity < inputCount)) {
        return false;
    }

    for (index = 0U; index < inputCount; index++) {
        output[index] = map_u16_to_i16(input[index], map);
    }
    return true;
}

bool Signal_ConvertU32ToU16(const uint32_t *input, uint32_t inputCount,
                            uint32_t inputFullScale,
                            uint16_t outputFullScale, uint16_t *output,
                            uint32_t outputCapacity)
{
    uint32_t index;

    if ((input == NULL) || (output == NULL) || (inputCount == 0U) ||
        (inputFullScale == 0U) || (outputFullScale == 0U) ||
        (outputCapacity < inputCount)) {
        return false;
    }

    for (index = 0U; index < inputCount; index++) {
        output[index] = scale_u32_to_u16(input[index], inputFullScale,
                                         outputFullScale);
    }
    return true;
}

uint16_t Signal_ReduceWaveformEnvelopeI16(
    const int16_t *input, uint32_t inputCount, int16_t *minimumOutput,
    int16_t *maximumOutput, uint16_t outputCapacity)
{
    uint16_t bucket;

    if ((input == NULL) || (minimumOutput == NULL) ||
        (maximumOutput == NULL) || (inputCount == 0U) ||
        (outputCapacity == 0U)) {
        return 0U;
    }

    if (inputCount <= outputCapacity) {
        uint16_t index;

        for (index = 0U; index < (uint16_t)inputCount; index++) {
            minimumOutput[index] = input[index];
            maximumOutput[index] = input[index];
        }
        return (uint16_t)inputCount;
    }

    for (bucket = 0U; bucket < outputCapacity; bucket++) {
        uint32_t start = bucket_boundary(bucket, inputCount,
                                         outputCapacity);
        uint32_t end = bucket_boundary((uint16_t)(bucket + 1U),
                                       inputCount, outputCapacity);
        uint32_t index;
        int16_t minimum = input[start];
        int16_t maximum = input[start];

        for (index = start + 1U; index < end; index++) {
            if (input[index] < minimum) minimum = input[index];
            if (input[index] > maximum) maximum = input[index];
        }
        minimumOutput[bucket] = minimum;
        maximumOutput[bucket] = maximum;
    }
    return outputCapacity;
}

uint16_t Signal_MapAndReduceWaveformEnvelopeU16(
    const uint16_t *input, uint32_t inputCount,
    const SignalLinearMap *map, int16_t *minimumOutput,
    int16_t *maximumOutput, uint16_t outputCapacity)
{
    uint16_t bucket;

    if ((input == NULL) || (minimumOutput == NULL) ||
        (maximumOutput == NULL) || !valid_map(map) ||
        (inputCount == 0U) || (outputCapacity == 0U)) {
        return 0U;
    }

    if (inputCount <= outputCapacity) {
        uint16_t index;

        for (index = 0U; index < (uint16_t)inputCount; index++) {
            int16_t value = map_u16_to_i16(input[index], map);

            minimumOutput[index] = value;
            maximumOutput[index] = value;
        }
        return (uint16_t)inputCount;
    }

    for (bucket = 0U; bucket < outputCapacity; bucket++) {
        uint32_t start = bucket_boundary(bucket, inputCount,
                                         outputCapacity);
        uint32_t end = bucket_boundary((uint16_t)(bucket + 1U),
                                       inputCount, outputCapacity);
        uint32_t index;
        uint16_t minimum = input[start];
        uint16_t maximum = input[start];
        int16_t firstMapped;
        int16_t secondMapped;

        for (index = start + 1U; index < end; index++) {
            if (input[index] < minimum) minimum = input[index];
            if (input[index] > maximum) maximum = input[index];
        }

        firstMapped = map_u16_to_i16(minimum, map);
        secondMapped = map_u16_to_i16(maximum, map);
        if (firstMapped <= secondMapped) {
            minimumOutput[bucket] = firstMapped;
            maximumOutput[bucket] = secondMapped;
        } else {
            minimumOutput[bucket] = secondMapped;
            maximumOutput[bucket] = firstMapped;
        }
    }
    return outputCapacity;
}

uint16_t Signal_ReduceSpectrumU16(const uint16_t *input,
                                  uint32_t inputCount, uint16_t *output,
                                  uint16_t outputCapacity)
{
    uint16_t bucket;

    if ((input == NULL) || (output == NULL) || (inputCount == 0U) ||
        (outputCapacity == 0U)) {
        return 0U;
    }

    if (inputCount <= outputCapacity) {
        uint16_t index;

        for (index = 0U; index < (uint16_t)inputCount; index++) {
            output[index] = input[index];
        }
        return (uint16_t)inputCount;
    }

    for (bucket = 0U; bucket < outputCapacity; bucket++) {
        uint32_t start = bucket_boundary(bucket, inputCount,
                                         outputCapacity);
        uint32_t end = bucket_boundary((uint16_t)(bucket + 1U),
                                       inputCount, outputCapacity);
        uint32_t index;
        uint16_t maximum = input[start];

        for (index = start + 1U; index < end; index++) {
            if (input[index] > maximum) {
                maximum = input[index];
            }
        }
        output[bucket] = maximum;
    }
    return outputCapacity;
}

uint16_t Signal_ScaleAndReduceSpectrumU32(const uint32_t *input,
                                          uint32_t inputCount,
                                          uint32_t inputFullScale,
                                          uint16_t outputFullScale,
                                          uint16_t *output,
                                          uint16_t outputCapacity)
{
    uint16_t bucket;

    if ((input == NULL) || (output == NULL) || (inputCount == 0U) ||
        (inputFullScale == 0U) || (outputFullScale == 0U) ||
        (outputCapacity == 0U)) {
        return 0U;
    }

    if (inputCount <= outputCapacity) {
        uint16_t index;

        for (index = 0U; index < (uint16_t)inputCount; index++) {
            output[index] = scale_u32_to_u16(input[index],
                                             inputFullScale,
                                             outputFullScale);
        }
        return (uint16_t)inputCount;
    }

    for (bucket = 0U; bucket < outputCapacity; bucket++) {
        uint32_t start = bucket_boundary(bucket, inputCount,
                                         outputCapacity);
        uint32_t end = bucket_boundary((uint16_t)(bucket + 1U),
                                       inputCount, outputCapacity);
        uint32_t index;
        uint32_t maximum = input[start];

        for (index = start + 1U; index < end; index++) {
            if (input[index] > maximum) {
                maximum = input[index];
            }
        }
        output[bucket] = scale_u32_to_u16(maximum, inputFullScale,
                                          outputFullScale);
    }
    return outputCapacity;
}

bool SignalDisplay_DrawWaveform(uint16_t x, uint16_t y, uint16_t width,
                                uint16_t height, const int16_t *samples,
                                uint32_t sampleCount, int16_t minimum,
                                int16_t maximum, const PlotStyle *style)
{
    uint16_t columnCount;

    if ((samples == NULL) || (sampleCount < 2U) ||
        !valid_plot_area(x, y, width, height, style) ||
        (maximum <= minimum)) {
        return false;
    }

    if (sampleCount <= width) {
        return Plot_DrawWaveform(x, y, width, height, samples,
                                 (uint16_t)sampleCount, minimum, maximum,
                                 style);
    }

    columnCount = Signal_ReduceWaveformEnvelopeI16(
        samples, sampleCount, g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, width);
    if (columnCount == 0U) {
        return false;
    }
    return Plot_DrawWaveformEnvelope(
        x, y, width, height, g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, columnCount, minimum,
        maximum, style);
}

bool SignalDisplay_DrawWaveformAuto(uint16_t x, uint16_t y,
                                    uint16_t width, uint16_t height,
                                    const int16_t *samples,
                                    uint32_t sampleCount, bool symmetric,
                                    const PlotStyle *style)
{
    uint16_t columnCount;
    int16_t minimum;
    int16_t maximum;

    if ((samples == NULL) || (sampleCount < 2U) ||
        !valid_plot_area(x, y, width, height, style)) {
        return false;
    }

    if (sampleCount <= width) {
        return Plot_DrawWaveformAuto(x, y, width, height, samples,
                                     (uint16_t)sampleCount, symmetric,
                                     style);
    }

    columnCount = Signal_ReduceWaveformEnvelopeI16(
        samples, sampleCount, g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, width);
    if ((columnCount == 0U) ||
        !envelope_range(g_signalDisplayBuffer.envelope.minimum,
                        g_signalDisplayBuffer.envelope.maximum,
                        columnCount, symmetric, &minimum, &maximum)) {
        return false;
    }
    return Plot_DrawWaveformEnvelope(
        x, y, width, height, g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, columnCount, minimum,
        maximum, style);
}

bool SignalDisplay_DrawMappedWaveform(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint16_t *samples, uint32_t sampleCount,
    const SignalLinearMap *map, int16_t minimum, int16_t maximum,
    const PlotStyle *style)
{
    uint16_t columnCount;

    if ((samples == NULL) || (sampleCount < 2U) || !valid_map(map) ||
        !valid_plot_area(x, y, width, height, style) ||
        (maximum <= minimum)) {
        return false;
    }

    if (sampleCount <= width) {
        if (!Signal_ConvertU16ToI16(samples, sampleCount, map,
                                    g_signalDisplayBuffer.waveform,
                                    SIGNAL_DISPLAY_MAX_POINTS)) {
            return false;
        }
        return Plot_DrawWaveform(x, y, width, height,
                                 g_signalDisplayBuffer.waveform,
                                 (uint16_t)sampleCount, minimum, maximum,
                                 style);
    }

    columnCount = Signal_MapAndReduceWaveformEnvelopeU16(
        samples, sampleCount, map,
        g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, width);
    if (columnCount == 0U) {
        return false;
    }
    return Plot_DrawWaveformEnvelope(
        x, y, width, height, g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, columnCount, minimum,
        maximum, style);
}

bool SignalDisplay_DrawMappedWaveformAuto(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint16_t *samples, uint32_t sampleCount,
    const SignalLinearMap *map, bool symmetric, const PlotStyle *style)
{
    uint16_t columnCount;
    int16_t minimum;
    int16_t maximum;

    if ((samples == NULL) || (sampleCount < 2U) || !valid_map(map) ||
        !valid_plot_area(x, y, width, height, style)) {
        return false;
    }

    if (sampleCount <= width) {
        if (!Signal_ConvertU16ToI16(samples, sampleCount, map,
                                    g_signalDisplayBuffer.waveform,
                                    SIGNAL_DISPLAY_MAX_POINTS)) {
            return false;
        }
        return Plot_DrawWaveformAuto(x, y, width, height,
                                     g_signalDisplayBuffer.waveform,
                                     (uint16_t)sampleCount, symmetric,
                                     style);
    }

    columnCount = Signal_MapAndReduceWaveformEnvelopeU16(
        samples, sampleCount, map,
        g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, width);
    if ((columnCount == 0U) ||
        !envelope_range(g_signalDisplayBuffer.envelope.minimum,
                        g_signalDisplayBuffer.envelope.maximum,
                        columnCount, symmetric, &minimum, &maximum)) {
        return false;
    }
    return Plot_DrawWaveformEnvelope(
        x, y, width, height, g_signalDisplayBuffer.envelope.minimum,
        g_signalDisplayBuffer.envelope.maximum, columnCount, minimum,
        maximum, style);
}

bool SignalDisplay_DrawSpectrum(uint16_t x, uint16_t y, uint16_t width,
                                uint16_t height,
                                const uint16_t *magnitudes,
                                uint32_t binCount, uint16_t maximum,
                                const PlotStyle *style)
{
    uint16_t reducedCount;
    uint16_t dataColumns;

    if (!valid_plot_area(x, y, width, height, style) ||
        (maximum == 0U)) {
        return false;
    }
    dataColumns = spectrum_data_columns(width, style);
    reducedCount = Signal_ReduceSpectrumU16(
        magnitudes, binCount, g_signalDisplayBuffer.spectrum, dataColumns);
    if (reducedCount == 0U) {
        return false;
    }
    return Plot_DrawSpectrum(x, y, width, height,
                             g_signalDisplayBuffer.spectrum, reducedCount,
                             maximum, style);
}

bool SignalDisplay_DrawSpectrumAuto(uint16_t x, uint16_t y,
                                    uint16_t width, uint16_t height,
                                    const uint16_t *magnitudes,
                                    uint32_t binCount,
                                    const PlotStyle *style)
{
    uint16_t reducedCount;
    uint16_t dataColumns;

    if (!valid_plot_area(x, y, width, height, style)) {
        return false;
    }
    dataColumns = spectrum_data_columns(width, style);
    reducedCount = Signal_ReduceSpectrumU16(
        magnitudes, binCount, g_signalDisplayBuffer.spectrum, dataColumns);
    if (reducedCount == 0U) {
        return false;
    }
    return Plot_DrawSpectrumAuto(x, y, width, height,
                                  g_signalDisplayBuffer.spectrum,
                                  reducedCount, style);
}

bool SignalDisplay_DrawSpectrumU32(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint32_t *magnitudes, uint32_t binCount,
    uint32_t inputFullScale, const PlotStyle *style)
{
    uint16_t reducedCount;
    uint16_t dataColumns;

    if ((magnitudes == NULL) || (binCount == 0U) ||
        (inputFullScale == 0U) ||
        !valid_plot_area(x, y, width, height, style)) {
        return false;
    }

    dataColumns = spectrum_data_columns(width, style);
    reducedCount = Signal_ScaleAndReduceSpectrumU32(
        magnitudes, binCount, inputFullScale, UINT16_MAX,
        g_signalDisplayBuffer.spectrum, dataColumns);
    if (reducedCount == 0U) {
        return false;
    }
    return Plot_DrawSpectrum(x, y, width, height,
                             g_signalDisplayBuffer.spectrum, reducedCount,
                             UINT16_MAX, style);
}

bool SignalDisplay_DrawSpectrumU32Auto(
    uint16_t x, uint16_t y, uint16_t width, uint16_t height,
    const uint32_t *magnitudes, uint32_t binCount,
    const PlotStyle *style)
{
    uint32_t index;
    uint32_t maximum = 0U;
    uint32_t margin;

    if ((magnitudes == NULL) || (binCount == 0U) ||
        !valid_plot_area(x, y, width, height, style)) {
        return false;
    }

    for (index = 0U; index < binCount; index++) {
        if (magnitudes[index] > maximum) maximum = magnitudes[index];
    }
    if (maximum == 0U) {
        maximum = 1U;
    } else {
        margin = maximum / 10U;
        if (margin == 0U) margin = 1U;
        if (margin > (UINT32_MAX - maximum)) {
            maximum = UINT32_MAX;
        } else {
            maximum += margin;
        }
    }

    return SignalDisplay_DrawSpectrumU32(
        x, y, width, height, magnitudes, binCount, maximum, style);
}

bool SignalDisplay_FindSpectrumPeak(const uint16_t *magnitudes,
                                    uint32_t binCount, uint32_t firstBin,
                                    uint32_t lastBinExclusive,
                                    uint32_t sampleRateHz,
                                    uint32_t fftLength,
                                    SignalSpectrumPeak *peak)
{
    uint32_t index;
    uint32_t peakIndex;
    uint16_t peakMagnitude;
    uint64_t frequency;

    if ((magnitudes == NULL) || (peak == NULL) ||
        (sampleRateHz == 0U) || (fftLength == 0U) ||
        (firstBin >= lastBinExclusive) ||
        (lastBinExclusive > binCount) ||
        (lastBinExclusive > fftLength)) {
        return false;
    }

    peakIndex = firstBin;
    peakMagnitude = magnitudes[firstBin];
    for (index = firstBin + 1U; index < lastBinExclusive; index++) {
        if (magnitudes[index] > peakMagnitude) {
            peakMagnitude = magnitudes[index];
            peakIndex = index;
        }
    }

    frequency = (uint64_t)peakIndex * sampleRateHz + fftLength / 2U;
    frequency /= fftLength;
    if (frequency > UINT32_MAX) {
        frequency = UINT32_MAX;
    }

    peak->binIndex = peakIndex;
    peak->magnitude = peakMagnitude;
    peak->frequencyHz = (uint32_t)frequency;
    return true;
}
