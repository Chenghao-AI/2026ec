#include "TJC_SCREEN.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

extern UART_HandleTypeDef huart1;

#define TJC_COMMAND_BUFFER_SIZE 128U
#define TJC_ADD_READY           0xFEU
#define TJC_ADD_FINISHED        0xFDU
#define TJC_DEFAULT_TIMEOUT_MS  1000U

#define TJC_TIME_AXIS_Y         222U
#define TJC_TIME_PLOT_X         20U
#define TJC_TIME_PLOT_WIDTH     500U
#define TJC_TIME_HALF_HEIGHT    159U
#define TJC_TIME_LONG_WINDOW_CYCLES 3.2f
#define TJC_COLOR_TIME          64495U

#define TJC_FREQ_AXIS_X         28U
#define TJC_FREQ_AXIS_Y         338U
#define TJC_FREQ_INTERIOR_X     29U
#define TJC_FREQ_INTERIOR_Y     66U
#define TJC_FREQ_INTERIOR_H     272U
#define TJC_FREQ_LINE_WIDTH     3U
#define TJC_COLOR_SPECTRUM      64495U

static uint8_t s_touch_frame[4];
static uint8_t s_touch_index;
static volatile uint8_t s_touch_ready;

static uint8_t s_response_code;
static uint8_t s_response_ff_count;
static volatile uint8_t s_add_ready;
static volatile uint8_t s_add_finished;

static uint8_t s_time_pixels_one[TJC_TIME_DISPLAY_POINTS];
static uint8_t s_time_pixels_three[TJC_TIME_DISPLAY_POINTS];
static uint8_t s_time_display_cycles = TJC_TIME_CYCLES_ONE;
static uint8_t s_time_data_valid;

static HAL_StatusTypeDef TJC_SendCommandV(const char *fmt, va_list args)
{
    static const uint8_t end_bytes[3] = {0xFFU, 0xFFU, 0xFFU};
    char buffer[TJC_COMMAND_BUFFER_SIZE];
    int length;
    HAL_StatusTypeDef status;

    if (fmt == NULL) {
        return HAL_ERROR;
    }

    length = vsnprintf(buffer, sizeof(buffer), fmt, args);
    if ((length < 0) || ((size_t)length >= sizeof(buffer))) {
        return HAL_ERROR;
    }

    status = HAL_UART_Transmit(&huart1,
                               (uint8_t *)buffer,
                               (uint16_t)length,
                               200U);
    if (status != HAL_OK) {
        return status;
    }

    return HAL_UART_Transmit(&huart1,
                             (uint8_t *)end_bytes,
                             sizeof(end_bytes),
                             100U);
}

static HAL_StatusTypeDef TJC_SendCommandChecked(const char *fmt, ...)
{
    HAL_StatusTypeDef status;
    va_list args;

    va_start(args, fmt);
    status = TJC_SendCommandV(fmt, args);
    va_end(args);
    return status;
}

static HAL_StatusTypeDef TJC_WaitFlag(volatile uint8_t *flag,
                                      uint32_t timeout_ms)
{
    uint32_t start_tick = HAL_GetTick();

    while (*flag == 0U) {
        if ((HAL_GetTick() - start_tick) >= timeout_ms) {
            return HAL_TIMEOUT;
        }
    }

    *flag = 0U;
    return HAL_OK;
}

static float TJC_AbsFloat(float value)
{
    return (value < 0.0f) ? -value : value;
}

static uint8_t TJC_MapSignedVoltage(float voltage_mv, float full_scale_mv)
{
    float value;

    if (full_scale_mv <= 0.0f) {
        return 128U;
    }

    value = 128.0f + ((voltage_mv / full_scale_mv) * 127.0f);
    if (value < 0.0f) {
        value = 0.0f;
    } else if (value > 255.0f) {
        value = 255.0f;
    }

    return (uint8_t)(value + 0.5f);
}

static bool TJC_TimeIsMonotonic(const TJC_TimePoint *points,
                                uint16_t point_count)
{
    uint16_t i;

    for (i = 1U; i < point_count; ++i) {
        if (points[i].time_ms <= points[i - 1U].time_ms) {
            return false;
        }
    }
    return true;
}

static void TJC_BuildTimePixels(const TJC_TimePoint *points,
                                uint16_t point_count,
                                float voltage_full_scale_mv,
                                float display_span_ms,
                                uint8_t *pixels)
{
    uint16_t source_index = 0U;
    uint16_t x;

    for (x = 0U; x < TJC_TIME_DISPLAY_POINTS; ++x) {
        float voltage_mv;
        float target_time = points[0].time_ms
                          + (display_span_ms * (float)x
                          / (float)(TJC_TIME_DISPLAY_POINTS - 1U));
        uint16_t next_index;
        float interval;
        float ratio;

        while (((source_index + 1U) < (point_count - 1U))
               && (points[source_index + 1U].time_ms < target_time)) {
            ++source_index;
        }

        next_index = source_index + 1U;
        interval = points[next_index].time_ms - points[source_index].time_ms;
        ratio = (interval > 0.0f)
              ? ((target_time - points[source_index].time_ms) / interval)
              : 0.0f;
        voltage_mv = points[source_index].voltage_mv
                   + ratio * (points[next_index].voltage_mv
                   - points[source_index].voltage_mv);

        pixels[x] = TJC_MapSignedVoltage(voltage_mv, voltage_full_scale_mv);
    }
}

static uint16_t TJC_TimePixelToScreenY(uint8_t pixel)
{
    int32_t delta = (int32_t)pixel - 128;

    if (delta >= 0) {
        return (uint16_t)((int32_t)TJC_TIME_AXIS_Y
               - (delta * (int32_t)TJC_TIME_HALF_HEIGHT / 127));
    }

    return (uint16_t)((int32_t)TJC_TIME_AXIS_Y
           + ((-delta) * (int32_t)TJC_TIME_HALF_HEIGHT / 128));
}

static HAL_StatusTypeDef TJC_RenderCachedTimeWaveform(void)
{
    HAL_StatusTypeDef status;
    const uint8_t *pixels;
    uint16_t i;

    if (s_time_data_valid == 0U) {
        return HAL_ERROR;
    }

    pixels = (s_time_display_cycles == TJC_TIME_CYCLES_THREE)
           ? s_time_pixels_three
           : s_time_pixels_one;

    status = TJC_SendCommandChecked("ref p0");
    if (status != HAL_OK) {
        return status;
    }

    for (i = 0U; i < (TJC_TIME_DISPLAY_POINTS - 1U); ++i) {
        uint16_t x1 = TJC_TIME_PLOT_X
                    + (uint16_t)(((uint32_t)i * TJC_TIME_PLOT_WIDTH)
                    / (TJC_TIME_DISPLAY_POINTS - 1U));
        uint16_t x2 = TJC_TIME_PLOT_X
                    + (uint16_t)(((uint32_t)(i + 1U) * TJC_TIME_PLOT_WIDTH)
                    / (TJC_TIME_DISPLAY_POINTS - 1U));
        uint16_t y1 = TJC_TimePixelToScreenY(pixels[i]);
        uint16_t y2 = TJC_TimePixelToScreenY(pixels[i + 1U]);

        status = TJC_SendCommandChecked("line %u,%u,%u,%u,%u",
                                        (unsigned int)x1,
                                        (unsigned int)y1,
                                        (unsigned int)x2,
                                        (unsigned int)y2,
                                        (unsigned int)TJC_COLOR_TIME);
        if (status != HAL_OK) {
            return status;
        }

        if ((i & 31U) == 31U) {
            status = TJC_SendCommandChecked("doevents");
            if (status != HAL_OK) {
                return status;
            }
        }
    }

    return HAL_OK;
}

HAL_StatusTypeDef TJC_Init(void)
{
    s_touch_index = 0U;
    s_touch_ready = 0U;
    s_response_code = 0U;
    s_response_ff_count = 0U;
    s_add_ready = 0U;
    s_add_finished = 0U;
    s_time_display_cycles = TJC_TIME_CYCLES_ONE;
    s_time_data_valid = 0U;

    return HAL_UART_Receive_IT(&huart1, &g_usart1_rx_byte, 1U);
}

void TJC_SendCmd(const char *fmt, ...)
{
    va_list args;

    va_start(args, fmt);
    (void)TJC_SendCommandV(fmt, args);
    va_end(args);
}

void TJC_UART_RxCpltCallback(uint8_t rx_data)
{
    /*
     * Touch frames have priority once AA has been received:
     * AA 01 command 55.
     */
    if ((s_touch_index != 0U) || (rx_data == 0xAAU)) {
        switch (s_touch_index) {
        case 0U:
            s_touch_frame[0] = rx_data;
            s_touch_index = 1U;
            break;

        case 1U:
            if (rx_data == 0x01U) {
                s_touch_frame[1] = rx_data;
                s_touch_index = 2U;
            } else if (rx_data != 0xAAU) {
                s_touch_index = 0U;
            }
            break;

        case 2U:
            s_touch_frame[2] = rx_data;
            s_touch_index = 3U;
            break;

        default:
            if (rx_data == 0x55U) {
                s_touch_frame[3] = rx_data;
                s_touch_ready = 1U;
                s_touch_index = 0U;
            } else if (rx_data == 0xAAU) {
                s_touch_frame[0] = rx_data;
                s_touch_index = 1U;
            } else {
                s_touch_index = 0U;
            }
            break;
        }
        return;
    }

    /*
     * addt replies are FE FF FF FF (ready) and FD FF FF FF (finished).
     */
    if (s_response_code == 0U) {
        if ((rx_data == TJC_ADD_READY) || (rx_data == TJC_ADD_FINISHED)) {
            s_response_code = rx_data;
            s_response_ff_count = 0U;
        }
        return;
    }

    if (rx_data == 0xFFU) {
        ++s_response_ff_count;
        if (s_response_ff_count == 3U) {
            if (s_response_code == TJC_ADD_READY) {
                s_add_ready = 1U;
            } else {
                s_add_finished = 1U;
            }
            s_response_code = 0U;
            s_response_ff_count = 0U;
        }
    } else {
        s_response_code = 0U;
        s_response_ff_count = 0U;
    }
}

bool TJC_GetTouchCommand(uint8_t *command)
{
    bool ready = false;
    uint32_t primask;

    if ((command != NULL) && (s_touch_ready != 0U)) {
        primask = __get_PRIMASK();
        __disable_irq();
        if (s_touch_ready != 0U) {
            *command = s_touch_frame[2];
            s_touch_ready = 0U;
            ready = true;
        }
        if (primask == 0U) {
            __enable_irq();
        }
    }

    return ready;
}

HAL_StatusTypeDef TJC_StreamWaveform(uint8_t waveform_id,
                                     uint8_t channel,
                                     const uint8_t *samples,
                                     uint16_t sample_count,
                                     uint32_t timeout_ms)
{
    HAL_StatusTypeDef status;

    if ((samples == NULL) || (sample_count == 0U)
        || (sample_count > 1024U) || (channel > 3U)) {
        return HAL_ERROR;
    }

    s_add_ready = 0U;
    s_add_finished = 0U;

    status = TJC_SendCommandChecked("addt %u,%u,%u",
                                    (unsigned int)waveform_id,
                                    (unsigned int)channel,
                                    (unsigned int)sample_count);
    if (status != HAL_OK) {
        return status;
    }

    status = TJC_WaitFlag(&s_add_ready, timeout_ms);
    if (status != HAL_OK) {
        return status;
    }

    status = HAL_UART_Transmit(&huart1,
                               (uint8_t *)samples,
                               sample_count,
                               timeout_ms);
    if (status != HAL_OK) {
        return status;
    }

    return TJC_WaitFlag(&s_add_finished, timeout_ms);
}

void TJC_UpdateTimeText(float upp_mv, float rms_mv, float fundamental_hz)
{
    float display_frequency_khz;

    display_frequency_khz =
        ((float)((uint32_t)((fundamental_hz + 250.0f) / 500.0f))
         * 500.0f) / 1000.0f;

    TJC_SendCmd("txt_upp.txt=\"%.1f mV\"", upp_mv);
    TJC_SendCmd("txt_rms.txt=\"%.1f mV\"", rms_mv);
    TJC_SendCmd("txt_freq.txt=\"%.1f kHz\"", display_frequency_khz);
}

void TJC_UpdateSpectrumText(uint8_t component_count,
                            float f1_khz, float a1_mv,
                            float f2_khz, float a2_mv,
                            float f3_khz, float a3_mv)
{
    if (component_count > TJC_MAX_FREQUENCY_COMPONENTS) {
        component_count = TJC_MAX_FREQUENCY_COMPONENTS;
    }

    if (component_count >= 1U) {
        TJC_SendCmd("txt_f1.txt=\"%.1f kHz\"", f1_khz);
        TJC_SendCmd("txt_a1.txt=\"%.1f mV\"", a1_mv);
    } else {
        TJC_SendCmd("txt_f1.txt=\"--\"");
        TJC_SendCmd("txt_a1.txt=\"--\"");
    }

    if (component_count >= 2U) {
        TJC_SendCmd("txt_f2.txt=\"%.1f kHz\"", f2_khz);
        TJC_SendCmd("txt_a2.txt=\"%.1f mV\"", a2_mv);
    } else {
        TJC_SendCmd("txt_f2.txt=\"--\"");
        TJC_SendCmd("txt_a2.txt=\"--\"");
    }

    if (component_count >= 3U) {
        TJC_SendCmd("txt_f3.txt=\"%.1f kHz\"", f3_khz);
        TJC_SendCmd("txt_a3.txt=\"%.1f mV\"", a3_mv);
    } else {
        TJC_SendCmd("txt_f3.txt=\"--\"");
        TJC_SendCmd("txt_a3.txt=\"--\"");
    }
}

HAL_StatusTypeDef TJC_UpdateTimeDomain(const TJC_TimePoint *points,
                                       uint16_t point_count,
                                       float voltage_full_scale_mv,
                                       float upp_mv,
                                       float rms_mv,
                                       float fundamental_hz)
{
    HAL_StatusTypeDef status;
    float one_period_ms;
    float required_span_ms;
    float available_span_ms;
    uint16_t i;

    if ((points == NULL) || (point_count < 2U)
        || (fundamental_hz <= 0.0f)
        || !TJC_TimeIsMonotonic(points, point_count)) {
        return HAL_ERROR;
    }

    one_period_ms = 1000.0f / fundamental_hz;
    required_span_ms = one_period_ms * TJC_TIME_LONG_WINDOW_CYCLES;
    available_span_ms = points[point_count - 1U].time_ms - points[0].time_ms;
    if ((available_span_ms + (one_period_ms * 0.001f)) < required_span_ms) {
        return HAL_ERROR;
    }

    if (voltage_full_scale_mv <= 0.0f) {
        for (i = 0U; i < point_count; ++i) {
            float magnitude = TJC_AbsFloat(points[i].voltage_mv);
            if (magnitude > voltage_full_scale_mv) {
                voltage_full_scale_mv = magnitude;
            }
        }
        if (voltage_full_scale_mv <= 0.0f) {
            voltage_full_scale_mv = 1.0f;
        }
    }

    TJC_BuildTimePixels(points,
                        point_count,
                        voltage_full_scale_mv,
                        one_period_ms,
                        s_time_pixels_one);
    TJC_BuildTimePixels(points,
                        point_count,
                        voltage_full_scale_mv,
                        required_span_ms,
                        s_time_pixels_three);
    s_time_data_valid = 1U;

    status = TJC_RenderCachedTimeWaveform();
    if (status != HAL_OK) {
        return status;
    }

    TJC_UpdateTimeText(upp_mv, rms_mv, fundamental_hz);
    return HAL_OK;
}

HAL_StatusTypeDef TJC_SetTimeDisplayCycles(uint8_t cycle_count)
{
    if ((cycle_count != TJC_TIME_CYCLES_ONE)
        && (cycle_count != TJC_TIME_CYCLES_THREE)) {
        return HAL_ERROR;
    }

    s_time_display_cycles = cycle_count;
    if (s_time_data_valid == 0U) {
        return HAL_OK;
    }

    return TJC_RenderCachedTimeWaveform();
}

HAL_StatusTypeDef TJC_ToggleTimeDisplayCycles(void)
{
    uint8_t next_cycle_count;

    next_cycle_count = (s_time_display_cycles == TJC_TIME_CYCLES_ONE)
                     ? TJC_TIME_CYCLES_THREE
                     : TJC_TIME_CYCLES_ONE;
    return TJC_SetTimeDisplayCycles(next_cycle_count);
}

uint8_t TJC_GetTimeDisplayCycles(void)
{
    return s_time_display_cycles;
}

HAL_StatusTypeDef TJC_UpdateFrequencyDomain(const TJC_FrequencyPoint *components,
                                            uint8_t component_count,
                                            float display_max_frequency_khz,
                                            float amplitude_full_scale_mv)
{
    HAL_StatusTypeDef status;
    float frequencies[TJC_MAX_FREQUENCY_COMPONENTS] = {0.0f, 0.0f, 0.0f};
    float amplitudes[TJC_MAX_FREQUENCY_COMPONENTS] = {0.0f, 0.0f, 0.0f};
    bool auto_frequency_range;
    bool auto_amplitude_range;
    uint8_t i;

    if ((components == NULL) || (component_count == 0U)) {
        return HAL_ERROR;
    }
    if (component_count > TJC_MAX_FREQUENCY_COMPONENTS) {
        component_count = TJC_MAX_FREQUENCY_COMPONENTS;
    }

    auto_frequency_range = (display_max_frequency_khz <= 0.0f);
    auto_amplitude_range = (amplitude_full_scale_mv <= 0.0f);
    if (auto_frequency_range) {
        display_max_frequency_khz = 0.0f;
    }
    if (auto_amplitude_range) {
        amplitude_full_scale_mv = 0.0f;
    }

    for (i = 0U; i < component_count; ++i) {
        frequencies[i] = components[i].frequency_khz;
        amplitudes[i] = components[i].amplitude_mv;

        if (auto_frequency_range
            && (components[i].frequency_khz > display_max_frequency_khz)) {
            display_max_frequency_khz = components[i].frequency_khz;
        }
        if (auto_amplitude_range
            && (components[i].amplitude_mv > amplitude_full_scale_mv)) {
            amplitude_full_scale_mv = components[i].amplitude_mv;
        }
    }

    if ((display_max_frequency_khz <= 0.0f)
        || (amplitude_full_scale_mv <= 0.0f)) {
        return HAL_ERROR;
    }

    if (auto_frequency_range) {
        display_max_frequency_khz *= 1.10f;
    }
    if (auto_amplitude_range) {
        amplitude_full_scale_mv *= 1.10f;
    }

    /*
     * Update text first.  Drawing the spectrum last prevents a later
     * component refresh from hiding the newly drawn lines on real hardware.
     */
    TJC_UpdateSpectrumText(component_count,
                           frequencies[0], amplitudes[0],
                           frequencies[1], amplitudes[1],
                           frequencies[2], amplitudes[2]);

    /* Restore the permanent axes and erase the previous spectrum bars. */
    status = TJC_SendCommandChecked("ref exp0");
    if (status != HAL_OK) {
        return status;
    }
    status = TJC_SendCommandChecked("doevents");
    if (status != HAL_OK) {
        return status;
    }

    for (i = 0U; i < component_count; ++i) {
        float x_position;
        float y_position;
        uint16_t x;
        uint16_t y;

        if ((components[i].frequency_khz <= 0.0f)
            || (components[i].amplitude_mv <= 0.0f)) {
            continue;
        }

        x_position = (float)TJC_FREQ_AXIS_X
                   + (components[i].frequency_khz
                   / display_max_frequency_khz)
                   * (float)(TJC_FREQ_PLOT_WIDTH - 2U);
        y_position = (float)TJC_FREQ_AXIS_Y
                   - (components[i].amplitude_mv
                   / amplitude_full_scale_mv)
                   * (float)TJC_FREQ_INTERIOR_H;

        if (x_position < (float)TJC_FREQ_INTERIOR_X) {
            x_position = (float)TJC_FREQ_INTERIOR_X;
        } else if (x_position > 460.0f) {
            x_position = 460.0f;
        }
        if (y_position < (float)TJC_FREQ_INTERIOR_Y) {
            y_position = (float)TJC_FREQ_INTERIOR_Y;
        } else if (y_position > 337.0f) {
            y_position = 337.0f;
        }

        x = (uint16_t)(x_position + 0.5f);
        y = (uint16_t)(y_position + 0.5f);

        /*
         * A three-pixel filled bar is more reliable and visible than a
         * one-pixel line on the physical LCD.  It ends at y=337 so the
         * permanent horizontal axis at y=338 remains visible.
         */
        status = TJC_SendCommandChecked("fill %u,%u,%u,%u,%u",
                                        (unsigned int)(x - 1U),
                                        (unsigned int)y,
                                        (unsigned int)TJC_FREQ_LINE_WIDTH,
                                        (unsigned int)(338U - y),
                                        (unsigned int)TJC_COLOR_SPECTRUM);
        if (status != HAL_OK) {
            return status;
        }
    }

    return TJC_SendCommandChecked("doevents");
}
