#include "FPGA_UART.h"

#include "usart.h"

#include <stddef.h>
#include <string.h>

#define FPGA_UART_HEADER_0               0xAAU
#define FPGA_UART_HEADER_1               0x55U
#define FPGA_UART_DMA_BUFFER_SIZE        512U
#define FPGA_UART_FIXED_PAYLOAD_SIZE     21U
#define FPGA_UART_MAX_PAYLOAD_SIZE       \
    (FPGA_UART_FIXED_PAYLOAD_SIZE + (2U * FPGA_MAX_WAVE_POINTS) \
     + (2U * FPGA_MAX_SPECTRUM_POINTS))
#define FPGA_UART_INTERBYTE_TIMEOUT_MS   50U
#define FPGA_UART_TX_TIMEOUT_MS          100U

#define FPGA_SPECTRUM_MIN_FREQUENCY_HZ   9000UL
#define FPGA_SPECTRUM_MAX_FREQUENCY_HZ   500000UL
#define FPGA_SPECTRUM_MIN_PEAK_001MV     50U
#define FPGA_SPECTRUM_NOISE_MULTIPLIER   4U
#define FPGA_SPECTRUM_RELATIVE_PERCENT   8U
#define FPGA_SPECTRUM_HARMONIC_TOL_HZ    3000UL
#define FPGA_SPECTRUM_HARMONIC_MIN_PERCENT 2U
#define FPGA_SPECTRUM_HARMONIC_NOISE_MULTIPLIER 2U
#define FPGA_SPECTRUM_LOCAL_NOISE_SPAN   12U
#define FPGA_CALIBRATION_AMPLITUDE_COUNT 7U
#define FPGA_CALIBRATION_FREQUENCY_COUNT 30U
#define FPGA_CALIBRATION_ITERATIONS      12U
#define FPGA_CALIBRATION_INITIAL_FACTOR  5.0f
#define FPGA_CALIBRATION_CONVERGENCE_MV  0.005f

typedef enum
{
    FPGA_PARSE_WAIT_AA = 0,
    FPGA_PARSE_WAIT_55,
    FPGA_PARSE_TYPE,
    FPGA_PARSE_SEQUENCE,
    FPGA_PARSE_LENGTH_HIGH,
    FPGA_PARSE_LENGTH_LOW,
    FPGA_PARSE_PAYLOAD,
    FPGA_PARSE_CRC_HIGH,
    FPGA_PARSE_CRC_LOW
} FPGA_ParseState_t;

static uint8_t s_dma_rx_buffer[FPGA_UART_DMA_BUFFER_SIZE];
static volatile uint16_t s_dma_old_position;

static volatile FPGA_ParseState_t s_parser_state;
static uint8_t s_frame_type;
static uint8_t s_frame_sequence;
static uint16_t s_payload_length;
static uint16_t s_payload_index;
static uint16_t s_calculated_crc;
static uint16_t s_received_crc;
static uint8_t s_drop_current_frame;
static uint8_t s_payload[FPGA_UART_MAX_PAYLOAD_SIZE];
static volatile uint8_t s_frame_ready;
static uint8_t s_ready_frame_type;
static uint8_t s_ready_frame_sequence;
static uint16_t s_ready_payload_length;
static volatile uint32_t s_last_rx_tick;

static volatile uint8_t s_dma_restart_pending;
static volatile uint8_t s_resend_pending;
static volatile uint8_t s_resend_sequence;

static uint8_t s_expected_sequence;
static uint8_t s_waiting_for_result;
static volatile uint8_t s_new_measurement;
static uint8_t s_last_accepted_sequence;
static uint8_t s_last_accepted_sequence_valid;

FPGA_MeasureResult_t g_fpga_debug_measurement;
FPGA_UART_Stats_t g_fpga_debug_stats;
volatile FPGA_UART_DebugState_t g_fpga_debug_state;

/*
 * Front-end calibration table.
 *
 * Rows are the true single-tone input amplitude in mV. Columns are frequency
 * in Hz. Each cell is:
 *
 *     true input amplitude / uncorrected FPGA spectrum amplitude
 *
 * The three values re-confirmed after remeasurement are 5.5 at 20 mV/50 kHz,
 * 4.1885 at 40 mV/420 kHz and 5.131 at 80 mV/160 kHz.
 */
static const float s_calibration_amplitudes_mv[
    FPGA_CALIBRATION_AMPLITUDE_COUNT] = {
    5.0f, 20.0f, 40.0f, 60.0f, 80.0f, 100.0f, 125.0f
};

static const uint32_t s_calibration_frequencies_hz[
    FPGA_CALIBRATION_FREQUENCY_COUNT] = {
    10000UL, 20000UL, 30000UL, 40000UL, 50000UL,
    60000UL, 70000UL, 80000UL, 90000UL, 100000UL,
    120000UL, 140000UL, 160000UL, 180000UL, 200000UL,
    220000UL, 240000UL, 260000UL, 280000UL, 300000UL,
    320000UL, 340000UL, 360000UL, 380000UL, 400000UL,
    420000UL, 440000UL, 460000UL, 480000UL, 500000UL
};

static const float s_calibration_factor
    [FPGA_CALIBRATION_AMPLITUDE_COUNT]
    [FPGA_CALIBRATION_FREQUENCY_COUNT] = {
    {
        7.142857f, 5.555556f, 6.666667f, 5.555556f, 6.250000f,
        5.000000f, 5.000000f, 5.000000f, 5.000000f, 5.555556f,
        6.666667f, 5.000000f, 4.545455f, 5.000000f, 7.142857f,
        6.250000f, 5.000000f, 5.000000f, 5.555556f, 5.555556f,
        4.545455f, 4.347826f, 5.000000f, 5.555556f, 5.000000f,
        4.166667f, 4.545455f, 5.882353f, 4.545455f, 4.000000f
    },
    {
        5.000000f, 4.878049f, 5.555556f, 5.000000f, 5.500000f,
        4.938272f, 5.263158f, 5.063291f, 5.263158f, 5.000000f,
        5.194805f, 5.063291f, 5.128205f, 5.000000f, 5.194805f,
        5.194805f, 5.194805f, 5.128205f, 4.938272f, 4.878049f,
        4.597701f, 4.545455f, 4.255319f, 4.301075f, 4.123711f,
        4.210526f, 4.166667f, 4.301075f, 4.301075f, 4.545455f
    },
    {
        5.714286f, 4.968944f, 5.517241f, 5.000000f, 5.517241f,
        4.968944f, 5.298013f, 4.968944f, 5.194805f, 5.000000f,
        5.063291f, 5.063291f, 5.000000f, 5.000000f, 5.128205f,
        5.161290f, 5.161290f, 5.000000f, 5.000000f, 4.878049f,
        4.878049f, 4.545455f, 4.324324f, 4.301075f, 4.166667f,
        4.188500f, 4.188482f, 4.255319f, 4.278075f, 4.444444f
    },
    {
        5.172414f, 4.918033f, 5.529954f, 4.918033f, 5.429864f,
        4.918033f, 5.309735f, 4.958678f, 5.194805f, 4.938272f,
        4.979253f, 4.979253f, 4.979253f, 5.000000f, 5.106383f,
        5.084746f, 5.172414f, 5.106383f, 4.878049f, 4.761905f,
        4.580153f, 4.460967f, 4.347826f, 4.285714f, 4.225352f,
        4.225352f, 4.225352f, 4.255319f, 4.285714f, 4.379562f
    },
    {
        5.755396f, 4.953560f, 5.594406f, 4.953560f, 5.479452f,
        4.968944f, 5.369128f, 5.000000f, 5.228758f, 5.000000f,
        5.000000f, 5.000000f, 5.131000f, 5.063291f, 5.144695f,
        5.161290f, 5.177994f, 5.095541f, 4.907975f, 4.719764f,
        4.571429f, 4.444444f, 4.371585f, 4.301075f, 4.244032f,
        4.232804f, 4.244032f, 4.289544f, 4.359673f, 4.419890f
    },
    {
        5.291005f, 4.950495f, 5.555556f, 4.975124f, 5.464481f,
        4.975124f, 5.319149f, 4.975124f, 5.208333f, 5.000000f,
        5.000000f, 5.025126f, 5.050505f, 5.076142f, 5.115090f,
        5.141388f, 5.208333f, 5.128205f, 4.950495f, 4.784689f,
        4.629630f, 4.494382f, 4.385965f, 4.319654f, 4.255319f,
        4.255319f, 4.273504f, 4.319654f, 4.385965f, 4.484305f
    },
    {
        5.319149f, 3.984064f, 5.617978f, 4.990020f, 4.980080f,
        4.980080f, 5.353319f, 5.000000f, 5.230126f, 5.000000f,
        5.040323f, 5.040323f, 5.060729f, 5.070994f, 5.122951f,
        5.133470f, 5.208333f, 5.122951f, 4.921260f, 4.743833f,
        5.910165f, 5.681818f, 4.385965f, 4.325260f, 4.280822f,
        4.273504f, 4.288165f, 4.340278f, 4.409171f, 4.496403f
    }
};

#define FPGA_UART_LAYOUT_ASSERT(name, condition) \
    typedef char name[(condition) ? 1 : -1]

FPGA_UART_LAYOUT_ASSERT(
    FPGA_UART_DebugStatusOffsetIsValid,
    offsetof(FPGA_MeasureResult_t, status) == 0U);
FPGA_UART_LAYOUT_ASSERT(
    FPGA_UART_DebugWaveCountOffsetIsValid,
    offsetof(FPGA_MeasureResult_t, wave_point_count) == 2U);
FPGA_UART_LAYOUT_ASSERT(
    FPGA_UART_DebugSampleIntervalOffsetIsValid,
    offsetof(FPGA_MeasureResult_t, sample_interval_ns) == 4U);
FPGA_UART_LAYOUT_ASSERT(
    FPGA_UART_DebugWaveformOffsetIsValid,
    offsetof(FPGA_MeasureResult_t, waveform_001mv) == 8U);
FPGA_UART_LAYOUT_ASSERT(
    FPGA_UART_DebugSpectrumStartOffsetIsValid,
    offsetof(FPGA_MeasureResult_t, spectrum_start_frequency_hz) == 4112U);
FPGA_UART_LAYOUT_ASSERT(
    FPGA_UART_DebugSpectrumOffsetIsValid,
    offsetof(FPGA_MeasureResult_t, spectrum_amplitude_001mv) == 4120U);
FPGA_UART_LAYOUT_ASSERT(
    FPGA_UART_DebugStructureSizeIsValid,
    sizeof(FPGA_MeasureResult_t) == 24124U);

#undef FPGA_UART_LAYOUT_ASSERT

static uint16_t FPGA_UART_CRCUpdate(uint16_t crc, uint8_t byte)
{
    uint8_t bit;

    crc ^= (uint16_t)byte << 8;
    for (bit = 0U; bit < 8U; ++bit) {
        if ((crc & 0x8000U) != 0U) {
            crc = (uint16_t)((crc << 1) ^ 0x1021U);
        } else {
            crc <<= 1;
        }
    }
    return crc;
}

uint16_t FPGA_UART_CRC16_CCITT_FALSE(const uint8_t *data, uint16_t length)
{
    uint16_t crc = 0xFFFFU;
    uint16_t i;

    if ((data == NULL) && (length != 0U)) {
        return 0U;
    }

    for (i = 0U; i < length; ++i) {
        crc = FPGA_UART_CRCUpdate(crc, data[i]);
    }
    return crc;
}

static uint16_t FPGA_UART_ReadU16BE(const uint8_t *data)
{
    return (uint16_t)(((uint16_t)data[0] << 8) | data[1]);
}

static uint32_t FPGA_UART_ReadU32BE(const uint8_t *data)
{
    return ((uint32_t)data[0] << 24)
         | ((uint32_t)data[1] << 16)
         | ((uint32_t)data[2] << 8)
         | (uint32_t)data[3];
}

static uint32_t FPGA_UART_SpectrumFrequencyHz(
    const FPGA_MeasureResult_t *measurement,
    uint16_t index)
{
    uint64_t frequency_hz;

    frequency_hz =
        (uint64_t)measurement->spectrum_start_frequency_hz
        + ((uint64_t)index
           * measurement->spectrum_bin_spacing_hz);
    return (frequency_hz > UINT32_MAX)
         ? UINT32_MAX
         : (uint32_t)frequency_hz;
}

static uint16_t FPGA_UART_MaxU16(uint16_t a, uint16_t b)
{
    return (a > b) ? a : b;
}

static void FPGA_UART_FindFrequencyBounds(
    uint32_t frequency_hz,
    uint8_t *lower_index,
    uint8_t *upper_index,
    float *weight)
{
    uint8_t index;

    if (frequency_hz <= s_calibration_frequencies_hz[0]) {
        *lower_index = 0U;
        *upper_index = 0U;
        *weight = 0.0f;
        return;
    }
    if (frequency_hz >=
        s_calibration_frequencies_hz[
            FPGA_CALIBRATION_FREQUENCY_COUNT - 1U]) {
        *lower_index = FPGA_CALIBRATION_FREQUENCY_COUNT - 1U;
        *upper_index = FPGA_CALIBRATION_FREQUENCY_COUNT - 1U;
        *weight = 0.0f;
        return;
    }

    for (index = 1U;
         index < FPGA_CALIBRATION_FREQUENCY_COUNT;
         ++index) {
        if (frequency_hz <= s_calibration_frequencies_hz[index]) {
            uint32_t lower_frequency =
                s_calibration_frequencies_hz[index - 1U];
            uint32_t upper_frequency =
                s_calibration_frequencies_hz[index];

            *lower_index = index - 1U;
            *upper_index = index;
            *weight =
                (float)(frequency_hz - lower_frequency)
                / (float)(upper_frequency - lower_frequency);
            return;
        }
    }

    *lower_index = FPGA_CALIBRATION_FREQUENCY_COUNT - 1U;
    *upper_index = FPGA_CALIBRATION_FREQUENCY_COUNT - 1U;
    *weight = 0.0f;
}

static void FPGA_UART_FindAmplitudeBounds(
    float amplitude_mv,
    uint8_t *lower_index,
    uint8_t *upper_index,
    float *weight)
{
    uint8_t index;

    if (amplitude_mv <= s_calibration_amplitudes_mv[0]) {
        *lower_index = 0U;
        *upper_index = 0U;
        *weight = 0.0f;
        return;
    }
    if (amplitude_mv >=
        s_calibration_amplitudes_mv[
            FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U]) {
        *lower_index = FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U;
        *upper_index = FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U;
        *weight = 0.0f;
        return;
    }

    for (index = 1U;
         index < FPGA_CALIBRATION_AMPLITUDE_COUNT;
         ++index) {
        if (amplitude_mv <= s_calibration_amplitudes_mv[index]) {
            float lower_amplitude =
                s_calibration_amplitudes_mv[index - 1U];
            float upper_amplitude =
                s_calibration_amplitudes_mv[index];

            *lower_index = index - 1U;
            *upper_index = index;
            *weight =
                (amplitude_mv - lower_amplitude)
                / (upper_amplitude - lower_amplitude);
            return;
        }
    }

    *lower_index = FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U;
    *upper_index = FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U;
    *weight = 0.0f;
}

static float FPGA_UART_InterpolateCalibrationFactor(
    uint32_t frequency_hz,
    float estimated_true_amplitude_mv)
{
    uint8_t frequency_low;
    uint8_t frequency_high;
    uint8_t amplitude_low;
    uint8_t amplitude_high;
    float frequency_weight;
    float amplitude_weight;
    float factor_at_lower_amplitude;
    float factor_at_upper_amplitude;

    FPGA_UART_FindFrequencyBounds(
        frequency_hz,
        &frequency_low,
        &frequency_high,
        &frequency_weight);
    FPGA_UART_FindAmplitudeBounds(
        estimated_true_amplitude_mv,
        &amplitude_low,
        &amplitude_high,
        &amplitude_weight);

    factor_at_lower_amplitude =
        s_calibration_factor[amplitude_low][frequency_low]
        + frequency_weight
          * (s_calibration_factor[amplitude_low][frequency_high]
             - s_calibration_factor[amplitude_low][frequency_low]);
    factor_at_upper_amplitude =
        s_calibration_factor[amplitude_high][frequency_low]
        + frequency_weight
          * (s_calibration_factor[amplitude_high][frequency_high]
             - s_calibration_factor[amplitude_high][frequency_low]);

    return factor_at_lower_amplitude
         + amplitude_weight
           * (factor_at_upper_amplitude
              - factor_at_lower_amplitude);
}

static float FPGA_UART_SolveCalibrationAmplitudeMv(
    uint32_t frequency_hz,
    float uncorrected_amplitude_mv,
    float reference_amplitude_mv)
{
    float best_amplitude_mv = s_calibration_amplitudes_mv[0];
    float best_difference = 0.0f;
    uint8_t candidate_found = 0U;
    uint8_t index;

    if (reference_amplitude_mv <= s_calibration_amplitudes_mv[0]) {
        return uncorrected_amplitude_mv
             * FPGA_UART_InterpolateCalibrationFactor(
                   frequency_hz,
                   s_calibration_amplitudes_mv[0]);
    }
    if (reference_amplitude_mv >=
        s_calibration_amplitudes_mv[
            FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U]) {
        return uncorrected_amplitude_mv
             * FPGA_UART_InterpolateCalibrationFactor(
                   frequency_hz,
                   s_calibration_amplitudes_mv[
                       FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U]);
    }

    /*
     * First preserve every measured calibration node. This also resolves the
     * two locally non-monotonic high-amplitude columns when the received
     * value matches one of their measured points within half of a 0.01 mV
     * spectrum LSB.
     */
    for (index = 0U;
         index < FPGA_CALIBRATION_AMPLITUDE_COUNT;
         ++index) {
        float true_amplitude_mv =
            s_calibration_amplitudes_mv[index];
        float factor = FPGA_UART_InterpolateCalibrationFactor(
            frequency_hz,
            true_amplitude_mv);
        float expected_uncorrected_mv =
            true_amplitude_mv / factor;
        float difference =
            (expected_uncorrected_mv >= uncorrected_amplitude_mv)
          ? expected_uncorrected_mv - uncorrected_amplitude_mv
          : uncorrected_amplitude_mv - expected_uncorrected_mv;

        if (difference <= FPGA_CALIBRATION_CONVERGENCE_MV) {
            return true_amplitude_mv;
        }
        if ((index == 0U) || (difference < best_difference)) {
            best_difference = difference;
            best_amplitude_mv = true_amplitude_mv;
        }
    }

    /*
     * Inside one amplitude interval the bilinearly interpolated correction
     * factor is linear in true amplitude:
     *
     *     factor(A) = slope * A + intercept
     *
     * Therefore A = raw * factor(A) has the exact solution below. If noisy
     * table data yields more than one solution, retain the solution closest
     * to the damped fixed-point estimate.
     */
    for (index = 0U;
         index < (FPGA_CALIBRATION_AMPLITUDE_COUNT - 1U);
         ++index) {
        float lower_amplitude =
            s_calibration_amplitudes_mv[index];
        float upper_amplitude =
            s_calibration_amplitudes_mv[index + 1U];
        float lower_factor =
            FPGA_UART_InterpolateCalibrationFactor(
                frequency_hz, lower_amplitude);
        float upper_factor =
            FPGA_UART_InterpolateCalibrationFactor(
                frequency_hz, upper_amplitude);
        float slope =
            (upper_factor - lower_factor)
            / (upper_amplitude - lower_amplitude);
        float intercept = lower_factor - slope * lower_amplitude;
        float denominator = 1.0f - uncorrected_amplitude_mv * slope;
        float denominator_abs =
            (denominator >= 0.0f) ? denominator : -denominator;
        float candidate;
        float difference;

        if (denominator_abs < 0.000001f) {
            continue;
        }
        candidate =
            uncorrected_amplitude_mv * intercept / denominator;
        if ((candidate < lower_amplitude)
            || (candidate > upper_amplitude)) {
            continue;
        }

        difference = (candidate >= reference_amplitude_mv)
                   ? candidate - reference_amplitude_mv
                   : reference_amplitude_mv - candidate;
        if ((candidate_found == 0U) || (difference < best_difference)) {
            candidate_found = 1U;
            best_difference = difference;
            best_amplitude_mv = candidate;
        }
    }

    return best_amplitude_mv;
}

static uint16_t FPGA_UART_CorrectSpectrumAmplitude001mV(
    uint32_t frequency_hz,
    uint16_t uncorrected_amplitude_001mv)
{
    float uncorrected_amplitude_mv;
    float estimated_true_amplitude_mv;
    float corrected_amplitude_mv;
    float correction_factor;
    uint32_t corrected_amplitude_001mv;
    uint8_t iteration;
    uint8_t converged = 0U;

    if (uncorrected_amplitude_001mv == 0U) {
        return 0U;
    }

    uncorrected_amplitude_mv =
        (float)uncorrected_amplitude_001mv * 0.01f;
    estimated_true_amplitude_mv =
        uncorrected_amplitude_mv
        * FPGA_CALIBRATION_INITIAL_FACTOR;

    /*
     * The table is indexed by true input amplitude, but only the uncorrected
     * amplitude is initially known. Solve
     *
     *   true = uncorrected * factor(frequency, true)
     *
     * by a short damped fixed-point iteration. The lookup coordinate is
     * clamped at the table edges, while the corrected result itself is not
     * clamped to 5..125 mV.
     */
    for (iteration = 0U;
         iteration < FPGA_CALIBRATION_ITERATIONS;
         ++iteration) {
        float next_estimate;
        float difference;

        correction_factor = FPGA_UART_InterpolateCalibrationFactor(
            frequency_hz,
            estimated_true_amplitude_mv);
        next_estimate =
            uncorrected_amplitude_mv * correction_factor;
        difference = (next_estimate >= estimated_true_amplitude_mv)
                   ? next_estimate - estimated_true_amplitude_mv
                   : estimated_true_amplitude_mv - next_estimate;
        if (difference <= FPGA_CALIBRATION_CONVERGENCE_MV) {
            estimated_true_amplitude_mv = next_estimate;
            converged = 1U;
            break;
        }

        estimated_true_amplitude_mv =
            0.5f * (estimated_true_amplitude_mv + next_estimate);
    }

    if (converged != 0U) {
        correction_factor = FPGA_UART_InterpolateCalibrationFactor(
            frequency_hz,
            estimated_true_amplitude_mv);
        corrected_amplitude_mv =
            uncorrected_amplitude_mv * correction_factor;
    } else {
        /*
         * A few measured columns are locally non-monotonic in amplitude, so
         * the inverse can have more than one mathematical solution. Avoid an
         * oscillating result by selecting the closest measured calibration
         * amplitude only when the fixed-point solver cannot converge.
         */
        corrected_amplitude_mv =
            FPGA_UART_SolveCalibrationAmplitudeMv(
                frequency_hz,
                uncorrected_amplitude_mv,
                estimated_true_amplitude_mv);
    }
    corrected_amplitude_001mv =
        (uint32_t)(corrected_amplitude_mv * 100.0f + 0.5f);

    return (corrected_amplitude_001mv > UINT16_MAX)
         ? UINT16_MAX
         : (uint16_t)corrected_amplitude_001mv;
}

static bool FPGA_UART_IsLocalPeak(const uint16_t *amplitudes,
                                  uint16_t index)
{
    return ((amplitudes[index] >= amplitudes[index - 1U])
            && (amplitudes[index] > amplitudes[index + 1U]));
}

static uint16_t FPGA_UART_LocalNoiseMean(
    const FPGA_MeasureResult_t *measurement,
    uint16_t center_index,
    uint16_t first_index,
    uint16_t last_index)
{
    uint16_t left_index;
    uint16_t right_index;
    uint16_t i;
    uint32_t sum = 0U;
    uint16_t count = 0U;

    left_index = (center_index > FPGA_SPECTRUM_LOCAL_NOISE_SPAN)
               ? (uint16_t)(center_index
                            - FPGA_SPECTRUM_LOCAL_NOISE_SPAN)
               : first_index;
    if (left_index < first_index) {
        left_index = first_index;
    }

    right_index = (uint16_t)(center_index
                  + FPGA_SPECTRUM_LOCAL_NOISE_SPAN);
    if ((right_index < center_index) || (right_index > last_index)) {
        right_index = last_index;
    }

    for (i = left_index; i <= right_index; ++i) {
        uint16_t distance = (i > center_index)
                          ? (uint16_t)(i - center_index)
                          : (uint16_t)(center_index - i);

        /* Exclude the peak and its two adjacent FFT bins. */
        if (distance <= 2U) {
            continue;
        }
        sum += measurement->spectrum_amplitude_001mv[i];
        ++count;
    }

    return (count == 0U) ? 0U : (uint16_t)(sum / count);
}

static void FPGA_UART_ResetParser(void)
{
    s_parser_state = FPGA_PARSE_WAIT_AA;
    s_payload_length = 0U;
    s_payload_index = 0U;
    s_calculated_crc = 0xFFFFU;
    s_received_crc = 0U;
    s_drop_current_frame = 0U;
}

static void FPGA_UART_ResetParserWithByte(uint8_t byte)
{
    FPGA_UART_ResetParser();
    if (byte == FPGA_UART_HEADER_0) {
        s_parser_state = FPGA_PARSE_WAIT_55;
    }
}

static void FPGA_UART_ConsumeByte(uint8_t byte)
{
    s_last_rx_tick = HAL_GetTick();

    switch (s_parser_state) {
    case FPGA_PARSE_WAIT_AA:
        if (byte == FPGA_UART_HEADER_0) {
            s_parser_state = FPGA_PARSE_WAIT_55;
        }
        break;

    case FPGA_PARSE_WAIT_55:
        if (byte == FPGA_UART_HEADER_1) {
            s_parser_state = FPGA_PARSE_TYPE;
            s_drop_current_frame = (s_frame_ready != 0U) ? 1U : 0U;
        } else if (byte != FPGA_UART_HEADER_0) {
            s_parser_state = FPGA_PARSE_WAIT_AA;
        }
        break;

    case FPGA_PARSE_TYPE:
        s_frame_type = byte;
        s_calculated_crc = FPGA_UART_CRCUpdate(0xFFFFU, byte);
        s_parser_state = FPGA_PARSE_SEQUENCE;
        break;

    case FPGA_PARSE_SEQUENCE:
        s_frame_sequence = byte;
        s_calculated_crc = FPGA_UART_CRCUpdate(s_calculated_crc, byte);
        s_parser_state = FPGA_PARSE_LENGTH_HIGH;
        break;

    case FPGA_PARSE_LENGTH_HIGH:
        s_payload_length = (uint16_t)byte << 8;
        s_calculated_crc = FPGA_UART_CRCUpdate(s_calculated_crc, byte);
        s_parser_state = FPGA_PARSE_LENGTH_LOW;
        break;

    case FPGA_PARSE_LENGTH_LOW:
        s_payload_length |= byte;
        s_calculated_crc = FPGA_UART_CRCUpdate(s_calculated_crc, byte);
        s_payload_index = 0U;
        if (s_payload_length > FPGA_UART_MAX_PAYLOAD_SIZE) {
            ++g_fpga_debug_stats.length_errors;
            FPGA_UART_ResetParserWithByte(byte);
        } else if (s_payload_length == 0U) {
            s_parser_state = FPGA_PARSE_CRC_HIGH;
        } else {
            s_parser_state = FPGA_PARSE_PAYLOAD;
        }
        break;

    case FPGA_PARSE_PAYLOAD:
        if (s_drop_current_frame == 0U) {
            s_payload[s_payload_index] = byte;
        }
        ++s_payload_index;
        s_calculated_crc = FPGA_UART_CRCUpdate(s_calculated_crc, byte);
        if (s_payload_index >= s_payload_length) {
            s_parser_state = FPGA_PARSE_CRC_HIGH;
        }
        break;

    case FPGA_PARSE_CRC_HIGH:
        s_received_crc = (uint16_t)byte << 8;
        s_parser_state = FPGA_PARSE_CRC_LOW;
        break;

    case FPGA_PARSE_CRC_LOW:
        s_received_crc |= byte;
        if (s_received_crc == s_calculated_crc) {
            if (s_drop_current_frame == 0U) {
                s_ready_frame_type = s_frame_type;
                s_ready_frame_sequence = s_frame_sequence;
                s_ready_payload_length = s_payload_length;
                s_frame_ready = 1U;
                ++g_fpga_debug_stats.valid_frames;
            } else {
                ++g_fpga_debug_stats.dropped_frames;
            }
        } else {
            ++g_fpga_debug_stats.crc_errors;
            if (s_frame_type == FPGA_UART_FRAME_MEASURE_RESULT) {
                s_resend_sequence = s_frame_sequence;
                s_resend_pending = 1U;
            }
        }
        FPGA_UART_ResetParserWithByte(byte);
        break;

    default:
        FPGA_UART_ResetParserWithByte(byte);
        break;
    }
}

static HAL_StatusTypeDef FPGA_UART_SendFrame(uint8_t type,
                                              uint8_t sequence,
                                              const uint8_t *payload,
                                              uint16_t payload_length)
{
    uint8_t header[6];
    uint8_t crc_bytes[2];
    uint16_t crc = 0xFFFFU;
    uint16_t i;
    HAL_StatusTypeDef status;

    if ((payload == NULL) && (payload_length != 0U)) {
        return HAL_ERROR;
    }

    header[0] = FPGA_UART_HEADER_0;
    header[1] = FPGA_UART_HEADER_1;
    header[2] = type;
    header[3] = sequence;
    header[4] = (uint8_t)(payload_length >> 8);
    header[5] = (uint8_t)payload_length;

    for (i = 2U; i < sizeof(header); ++i) {
        crc = FPGA_UART_CRCUpdate(crc, header[i]);
    }
    for (i = 0U; i < payload_length; ++i) {
        crc = FPGA_UART_CRCUpdate(crc, payload[i]);
    }
    crc_bytes[0] = (uint8_t)(crc >> 8);
    crc_bytes[1] = (uint8_t)crc;

    status = HAL_UART_Transmit(&huart2, header, sizeof(header),
                               FPGA_UART_TX_TIMEOUT_MS);
    if ((status == HAL_OK) && (payload_length != 0U)) {
        status = HAL_UART_Transmit(&huart2, (uint8_t *)payload,
                                   payload_length,
                                   FPGA_UART_TX_TIMEOUT_MS);
    }
    if (status == HAL_OK) {
        status = HAL_UART_Transmit(&huart2, crc_bytes, sizeof(crc_bytes),
                                   FPGA_UART_TX_TIMEOUT_MS);
    }
    return status;
}

static bool FPGA_UART_ParseMeasurement(void)
{
    uint16_t offset = 0U;
    uint16_t point_count;
    uint16_t spectrum_point_count;
    uint32_t expected_length;
    uint16_t i;

    if (s_ready_payload_length < FPGA_UART_FIXED_PAYLOAD_SIZE) {
        return false;
    }

    g_fpga_debug_measurement.status = s_payload[offset++];
    point_count = FPGA_UART_ReadU16BE(&s_payload[offset]);
    offset += 2U;
    g_fpga_debug_measurement.sample_interval_ns =
        FPGA_UART_ReadU32BE(&s_payload[offset]);
    offset += 4U;

    if ((point_count < 2U) || (point_count > FPGA_MAX_WAVE_POINTS)
        || (g_fpga_debug_measurement.sample_interval_ns == 0U)) {
        return false;
    }

    if (((uint32_t)offset + (2UL * point_count) + 5UL)
        > s_ready_payload_length) {
        return false;
    }

    for (i = 0U; i < point_count; ++i) {
        g_fpga_debug_measurement.waveform_001mv[i] =
            (int16_t)FPGA_UART_ReadU16BE(&s_payload[offset]);
        offset += 2U;
    }

    g_fpga_debug_measurement.vpp_001mv =
        FPGA_UART_ReadU16BE(&s_payload[offset]);
    offset += 2U;
    g_fpga_debug_measurement.vrms_001mv =
        FPGA_UART_ReadU16BE(&s_payload[offset]);
    offset += 2U;
    spectrum_point_count = FPGA_UART_ReadU16BE(&s_payload[offset]);
    offset += 2U;
    g_fpga_debug_measurement.spectrum_start_frequency_hz =
        FPGA_UART_ReadU32BE(&s_payload[offset]);
    offset += 4U;
    g_fpga_debug_measurement.spectrum_bin_spacing_hz =
        FPGA_UART_ReadU32BE(&s_payload[offset]);
    offset += 4U;

    if ((spectrum_point_count < 3U)
        || (spectrum_point_count > FPGA_MAX_SPECTRUM_POINTS)
        || (g_fpga_debug_measurement.spectrum_bin_spacing_hz == 0U)) {
        return false;
    }

    expected_length = FPGA_UART_FIXED_PAYLOAD_SIZE
                    + (2UL * point_count)
                    + (2UL * spectrum_point_count);
    if (expected_length != s_ready_payload_length) {
        return false;
    }

    for (i = 0U; i < spectrum_point_count; ++i) {
        g_fpga_debug_measurement.spectrum_amplitude_001mv[i] =
            FPGA_UART_ReadU16BE(&s_payload[offset]);
        offset += 2U;
    }

    if (offset != s_ready_payload_length) {
        return false;
    }

    g_fpga_debug_measurement.wave_point_count = point_count;
    g_fpga_debug_measurement.spectrum_point_count = spectrum_point_count;
    g_fpga_debug_measurement.sequence = s_ready_frame_sequence;
    g_fpga_debug_measurement.valid = 1U;
    return true;
}

bool FPGA_UART_ExtractSpectrumFeatures(
    const FPGA_MeasureResult_t *measurement,
    FPGA_SpectrumFeatures_t *features)
{
    uint16_t first_index = 0U;
    uint16_t last_index;
    uint16_t global_max = 0U;
    uint16_t noise_mean;
    uint16_t threshold;
    uint16_t fundamental_index = 0U;
    uint64_t amplitude_sum = 0ULL;
    uint32_t valid_count = 0U;
    uint16_t i;
    uint16_t harmonic_order;

    if ((measurement == NULL) || (features == NULL)
        || (measurement->valid == 0U)
        || (measurement->spectrum_point_count < 3U)
        || (measurement->spectrum_point_count
            > FPGA_MAX_SPECTRUM_POINTS)
        || (measurement->spectrum_bin_spacing_hz == 0U)) {
        return false;
    }

    memset(features, 0, sizeof(*features));
    last_index = (uint16_t)(measurement->spectrum_point_count - 1U);

    while ((first_index < last_index)
           && (FPGA_UART_SpectrumFrequencyHz(measurement, first_index)
               < FPGA_SPECTRUM_MIN_FREQUENCY_HZ)) {
        ++first_index;
    }
    while ((last_index > first_index)
           && (FPGA_UART_SpectrumFrequencyHz(measurement, last_index)
               > FPGA_SPECTRUM_MAX_FREQUENCY_HZ)) {
        --last_index;
    }
    if ((last_index <= first_index)
        || ((uint16_t)(last_index - first_index) < 2U)) {
        return false;
    }

    for (i = first_index; i <= last_index; ++i) {
        uint16_t amplitude =
            measurement->spectrum_amplitude_001mv[i];
        amplitude_sum += amplitude;
        ++valid_count;
        if (amplitude > global_max) {
            global_max = amplitude;
        }
    }
    if ((valid_count == 0U) || (global_max == 0U)) {
        return false;
    }

    noise_mean = (uint16_t)(amplitude_sum / valid_count);
    threshold = FPGA_UART_MaxU16(
        FPGA_SPECTRUM_MIN_PEAK_001MV,
        (uint16_t)(((uint32_t)global_max
                    * FPGA_SPECTRUM_RELATIVE_PERCENT) / 100U));
    if (((uint32_t)noise_mean * FPGA_SPECTRUM_NOISE_MULTIPLIER)
        > threshold) {
        uint32_t noise_threshold =
            (uint32_t)noise_mean * FPGA_SPECTRUM_NOISE_MULTIPLIER;
        threshold = (noise_threshold > UINT16_MAX)
                  ? UINT16_MAX
                  : (uint16_t)noise_threshold;
    }

    if (first_index == 0U) {
        first_index = 1U;
    }
    if (last_index >= (measurement->spectrum_point_count - 1U)) {
        last_index =
            (uint16_t)(measurement->spectrum_point_count - 2U);
    }

    for (i = first_index; i <= last_index; ++i) {
        if ((measurement->spectrum_amplitude_001mv[i] >= threshold)
            && FPGA_UART_IsLocalPeak(
                measurement->spectrum_amplitude_001mv, i)) {
            fundamental_index = i;
            break;
        }
    }
    if (fundamental_index == 0U) {
        return false;
    }

    features->component_count = 1U;
    features->frequency_hz[0] =
        FPGA_UART_SpectrumFrequencyHz(measurement, fundamental_index);
    features->amplitude_001mv[0] =
        measurement->spectrum_amplitude_001mv[fundamental_index];

    /*
     * Search every integer multiple up to 500 kHz.  The previous algorithm
     * checked only orders 2 and 3, so a fifth harmonic such as
     * 20 kHz -> 100 kHz could never be reported.
     */
    for (harmonic_order = 2U;
         (features->component_count < FPGA_MAX_COMPONENTS)
         && (((uint64_t)features->frequency_hz[0] * harmonic_order)
             <= FPGA_SPECTRUM_MAX_FREQUENCY_HZ);
         ++harmonic_order) {
        uint32_t target_hz =
            features->frequency_hz[0] * harmonic_order;
        uint32_t lower_hz;
        uint32_t upper_hz;
        uint16_t best_index = 0U;
        uint16_t best_amplitude = 0U;
        uint16_t local_noise;
        uint16_t harmonic_threshold;
        uint32_t local_noise_threshold;
        lower_hz = (target_hz > FPGA_SPECTRUM_HARMONIC_TOL_HZ)
                 ? target_hz - FPGA_SPECTRUM_HARMONIC_TOL_HZ
                 : 0U;
        upper_hz = target_hz + FPGA_SPECTRUM_HARMONIC_TOL_HZ;

        for (i = first_index; i <= last_index; ++i) {
            uint32_t frequency_hz =
                FPGA_UART_SpectrumFrequencyHz(measurement, i);
            uint16_t amplitude;

            if (frequency_hz < lower_hz) {
                continue;
            }
            if (frequency_hz > upper_hz) {
                break;
            }
            amplitude = measurement->spectrum_amplitude_001mv[i];
            if (amplitude > best_amplitude) {
                best_amplitude = amplitude;
                best_index = i;
            }
        }

        if (best_index == 0U) {
            continue;
        }

        local_noise = FPGA_UART_LocalNoiseMean(
            measurement, best_index, first_index, last_index);
        harmonic_threshold = FPGA_UART_MaxU16(
            FPGA_SPECTRUM_MIN_PEAK_001MV,
            (uint16_t)(((uint32_t)features->amplitude_001mv[0]
                        * FPGA_SPECTRUM_HARMONIC_MIN_PERCENT) / 100U));
        local_noise_threshold =
            (uint32_t)local_noise
            * FPGA_SPECTRUM_HARMONIC_NOISE_MULTIPLIER;
        harmonic_threshold = FPGA_UART_MaxU16(
            harmonic_threshold,
            (local_noise_threshold > UINT16_MAX)
          ? UINT16_MAX
          : (uint16_t)local_noise_threshold);

        if ((best_amplitude >= harmonic_threshold)
            && FPGA_UART_IsLocalPeak(
                measurement->spectrum_amplitude_001mv, best_index)) {
            uint8_t output_index = features->component_count;
            features->frequency_hz[output_index] =
                FPGA_UART_SpectrumFrequencyHz(measurement, best_index);
            features->amplitude_001mv[output_index] = best_amplitude;
            ++features->component_count;
        }
    }

    /*
     * Keep all peak/noise decisions in the FPGA's original amplitude scale.
     * Apply the front-end attenuation correction only after the fundamental
     * and harmonic components have been accepted.
     */
    for (i = 0U; i < features->component_count; ++i) {
        features->amplitude_001mv[i] =
            FPGA_UART_CorrectSpectrumAmplitude001mV(
                features->frequency_hz[i],
                features->amplitude_001mv[i]);
    }

    return true;
}

HAL_StatusTypeDef FPGA_UART_Init(void)
{
    memset(&g_fpga_debug_measurement, 0,
           sizeof(g_fpga_debug_measurement));
    memset(&g_fpga_debug_stats, 0, sizeof(g_fpga_debug_stats));
    memset((void *)&g_fpga_debug_state, 0,
           sizeof(g_fpga_debug_state));
    s_dma_old_position = 0U;
    s_frame_ready = 0U;
    s_dma_restart_pending = 0U;
    s_resend_pending = 0U;
    s_expected_sequence = 0U;
    s_waiting_for_result = 0U;
    s_new_measurement = 0U;
    s_last_accepted_sequence = 0U;
    s_last_accepted_sequence_valid = 0U;
    FPGA_UART_ResetParser();

    return HAL_UARTEx_ReceiveToIdle_DMA(&huart2,
                                        s_dma_rx_buffer,
                                        FPGA_UART_DMA_BUFFER_SIZE);
}

HAL_StatusTypeDef FPGA_UART_RequestMeasurement(uint8_t mode)
{
    HAL_StatusTypeDef status;

    ++s_expected_sequence;
    g_fpga_debug_state.expected_sequence = s_expected_sequence;
    status = FPGA_UART_SendFrame(FPGA_UART_FRAME_CMD_START,
                                 s_expected_sequence,
                                 &mode,
                                 1U);
    if (status == HAL_OK) {
        s_waiting_for_result = 1U;
        g_fpga_debug_state.waiting_for_result = 1U;
    }
    return status;
}

HAL_StatusTypeDef FPGA_UART_SendStop(void)
{
    return FPGA_UART_SendFrame(FPGA_UART_FRAME_CMD_STOP,
                               s_expected_sequence,
                               NULL,
                               0U);
}

void FPGA_UART_Process(void)
{
    uint32_t primask;
    uint8_t frame_ready;

    if (s_dma_restart_pending != 0U) {
        s_dma_restart_pending = 0U;
        (void)HAL_UART_AbortReceive(&huart2);
        s_dma_old_position = 0U;
        FPGA_UART_ResetParser();
        (void)HAL_UARTEx_ReceiveToIdle_DMA(&huart2,
                                           s_dma_rx_buffer,
                                           FPGA_UART_DMA_BUFFER_SIZE);
    }

    if ((s_parser_state != FPGA_PARSE_WAIT_AA)
        && ((HAL_GetTick() - s_last_rx_tick)
            > FPGA_UART_INTERBYTE_TIMEOUT_MS)) {
        primask = __get_PRIMASK();
        __disable_irq();
        if ((s_parser_state != FPGA_PARSE_WAIT_AA)
            && ((HAL_GetTick() - s_last_rx_tick)
                > FPGA_UART_INTERBYTE_TIMEOUT_MS)) {
            FPGA_UART_ResetParser();
            ++g_fpga_debug_stats.parser_timeouts;
        }
        if (primask == 0U) {
            __enable_irq();
        }
    }

    if (s_resend_pending != 0U) {
        uint8_t sequence = s_resend_sequence;
        s_resend_pending = 0U;
        (void)FPGA_UART_SendFrame(FPGA_UART_FRAME_CMD_RESEND,
                                  sequence,
                                  NULL,
                                  0U);
    }

    frame_ready = s_frame_ready;
    if (frame_ready == 0U) {
        return;
    }

    if (s_ready_frame_type == FPGA_UART_FRAME_MEASURE_RESULT) {
        if ((s_waiting_for_result == 0U)
            && (s_last_accepted_sequence_valid != 0U)
            && (s_ready_frame_sequence == s_last_accepted_sequence)) {
            /*
             * The FPGA may resend the last result when its ACK was lost.
             * ACK the duplicate again, but do not publish or redraw it twice.
             */
            g_fpga_debug_state.last_ack_hal_status =
                (uint8_t)FPGA_UART_SendFrame(FPGA_UART_FRAME_ACK,
                                             s_ready_frame_sequence,
                                             NULL,
                                             0U);
        } else if ((s_waiting_for_result != 0U)
            && (s_ready_frame_sequence != s_expected_sequence)) {
            ++g_fpga_debug_stats.sequence_errors;
        } else if (FPGA_UART_ParseMeasurement()) {
            s_new_measurement = 1U;
            s_waiting_for_result = 0U;
            g_fpga_debug_state.waiting_for_result = 0U;
            g_fpga_debug_state.last_result_sequence =
                s_ready_frame_sequence;
            s_last_accepted_sequence = s_ready_frame_sequence;
            s_last_accepted_sequence_valid = 1U;
            g_fpga_debug_state.last_ack_hal_status =
                (uint8_t)FPGA_UART_SendFrame(FPGA_UART_FRAME_ACK,
                                             s_ready_frame_sequence,
                                             NULL,
                                             0U);
            ++g_fpga_debug_state.snapshot_counter;
            FPGA_UART_DebugMeasurementReadyHook();
        } else {
            ++g_fpga_debug_stats.format_errors;
            (void)FPGA_UART_SendFrame(FPGA_UART_FRAME_CMD_RESEND,
                                      s_ready_frame_sequence,
                                      NULL,
                                      0U);
        }
    }

    s_frame_ready = 0U;
}

bool FPGA_UART_HasNewMeasurement(void)
{
    return (s_new_measurement != 0U);
}

const FPGA_MeasureResult_t *FPGA_UART_GetMeasurement(void)
{
    return (g_fpga_debug_measurement.valid != 0U)
         ? &g_fpga_debug_measurement
         : NULL;
}

void FPGA_UART_ClearNewMeasurement(void)
{
    s_new_measurement = 0U;
}

const FPGA_UART_Stats_t *FPGA_UART_GetStats(void)
{
    return &g_fpga_debug_stats;
}

void FPGA_UART_HandleError(UART_HandleTypeDef *huart)
{
    if ((huart != NULL) && (huart->Instance == USART2)) {
        __HAL_UART_CLEAR_OREFLAG(huart);
        __HAL_UART_CLEAR_NEFLAG(huart);
        __HAL_UART_CLEAR_FEFLAG(huart);
        ++g_fpga_debug_stats.uart_errors;
        s_dma_restart_pending = 1U;
    }
}

__attribute__((noinline)) void FPGA_UART_DebugMeasurementReadyHook(void)
{
    __NOP();
}

void HAL_UARTEx_RxEventCallback(UART_HandleTypeDef *huart, uint16_t size)
{
    uint16_t i;

    if ((huart == NULL) || (huart->Instance != USART2)
        || (size > FPGA_UART_DMA_BUFFER_SIZE)) {
        return;
    }

    if (size > s_dma_old_position) {
        for (i = s_dma_old_position; i < size; ++i) {
            FPGA_UART_ConsumeByte(s_dma_rx_buffer[i]);
        }
    } else if (size < s_dma_old_position) {
        for (i = s_dma_old_position; i < FPGA_UART_DMA_BUFFER_SIZE; ++i) {
            FPGA_UART_ConsumeByte(s_dma_rx_buffer[i]);
        }
        for (i = 0U; i < size; ++i) {
            FPGA_UART_ConsumeByte(s_dma_rx_buffer[i]);
        }
    }

    s_dma_old_position = (size == FPGA_UART_DMA_BUFFER_SIZE) ? 0U : size;
}
