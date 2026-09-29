/* Rabi 备用模块：ADC 样本块统计与采样波形测频实现。 */
#include <stdbool.h>
#include "rabi_signal.h"

static uint32_t integer_sqrt_u64(uint64_t value)
{
    /* 逐二进制位开方，无浮点、无 libm；结果先取 floor。 */
    uint64_t remainder = value;
    uint64_t root = 0U;
    uint64_t bit = (uint64_t)1U << 62;

    while (bit > remainder) bit >>= 2;
    while (bit != 0U)
    {
        if (remainder >= root + bit)
        {
            remainder -= root + bit;
            root = (root >> 1) + bit;
        }
        else
        {
            root >>= 1;
        }
        bit >>= 2;
    }

    /* 本模块输入为 uint16_t 样本，实际 root 最大 65535，可安全做最近整数修正。 */
    uint64_t lower_error = value - root * root;
    uint64_t upper = root + 1U;
    uint64_t upper_error = upper * upper - value;
    if (upper_error < lower_error) root = upper;
    return (uint32_t)root;
}

static bool stride_is_valid(size_t selected_count, size_t stride)
{
    if (selected_count == 0U || selected_count > UINT32_MAX || stride == 0U)
    {
        return false;
    }
    return selected_count == 1U ||
        stride <= SIZE_MAX / (selected_count - 1U);
}

rabi_err_t rabi_signal_stats_u16(
    const uint16_t *samples,
    size_t sample_count,
    rabi_signal_stats_u16_t *stats)
{
    return rabi_signal_stats_u16_strided(
        samples, sample_count, 1U, stats);
}

rabi_err_t rabi_signal_stats_u16_strided(
    const uint16_t *samples,
    size_t selected_count,
    size_t stride,
    rabi_signal_stats_u16_t *stats)
{
    if (samples == NULL || stats == NULL ||
        !stride_is_valid(selected_count, stride))
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint16_t minimum = samples[0];
    uint16_t maximum = samples[0];
    uint64_t sum = 0U;
    uint64_t sum_squares = 0U;

    for (size_t i = 0U; i < selected_count; i++)
    {
        uint16_t sample = samples[i * stride];
        if (sample < minimum) minimum = sample;
        if (sample > maximum) maximum = sample;
        sum += sample;
        sum_squares += (uint64_t)sample * sample;
    }

    uint32_t mean = (uint32_t)(
        (sum + selected_count / 2U) / selected_count);
    uint64_t mean_square =
        (sum_squares + selected_count / 2U) / selected_count;

    uint64_t ac_sum_squares = 0U;
    for (size_t i = 0U; i < selected_count; i++)
    {
        int64_t difference =
            (int64_t)samples[i * stride] - (int64_t)mean;
        ac_sum_squares += (uint64_t)(difference * difference);
    }
    uint64_t ac_mean_square =
        (ac_sum_squares + selected_count / 2U) / selected_count;

    *stats = (rabi_signal_stats_u16_t){
        .minimum_raw = minimum,
        .maximum_raw = maximum,
        .mean_raw = (uint16_t)mean,
        .rms_raw = (uint16_t)integer_sqrt_u64(mean_square),
        .ac_rms_raw = (uint16_t)integer_sqrt_u64(ac_mean_square),
        .peak_to_peak_raw = (uint16_t)(maximum - minimum),
    };
    return RABI_ERR_OK;
}

rabi_err_t rabi_signal_measure_frequency_u16(
    const uint16_t *samples,
    size_t selected_count,
    size_t stride,
    uint32_t sample_rate_hz,
    uint16_t center,
    uint16_t hysteresis,
    rabi_signal_frequency_u16_t *frequency)
{
    if (samples == NULL || frequency == NULL || sample_rate_hz == 0U ||
        selected_count < 2U || !stride_is_valid(selected_count, stride))
    {
        return RABI_ERR_INVALID_ARG;
    }

    uint32_t lower = (uint32_t)center;
    uint32_t upper = (uint32_t)center + hysteresis;
    if (hysteresis > center || upper > UINT16_MAX)
    {
        return RABI_ERR_INVALID_ARG;
    }
    lower -= hysteresis;

    bool armed = samples[0] <= lower;
    bool candidate_valid = false;
    uint64_t candidate_q16 = 0U;
    uint64_t first_crossing_q16 = 0U;
    uint64_t last_crossing_q16 = 0U;
    size_t crossing_count = 0U;
    uint16_t previous = samples[0];

    for (size_t i = 1U; i < selected_count; i++)
    {
        uint16_t current = samples[i * stride];

        if ((uint32_t)current <= lower)
        {
            armed = true;
            candidate_valid = false;
        }

        if (armed && !candidate_valid &&
            previous < center && current >= center && current > previous)
        {
            uint32_t fraction_q16 = (uint32_t)(
                ((uint64_t)(center - previous) << 16) /
                (uint32_t)(current - previous));
            candidate_q16 =
                ((uint64_t)(i - 1U) << 16) + fraction_q16;
            candidate_valid = true;
        }

        if (armed && candidate_valid && (uint32_t)current >= upper)
        {
            if (crossing_count == 0U)
            {
                first_crossing_q16 = candidate_q16;
            }
            last_crossing_q16 = candidate_q16;
            crossing_count++;
            armed = false;
            candidate_valid = false;
        }

        previous = current;
    }

    if (crossing_count < 2U ||
        last_crossing_q16 <= first_crossing_q16)
    {
        *frequency = (rabi_signal_frequency_u16_t){0};
        return RABI_ERR_NOT_FOUND;
    }

    uint64_t span_q16 = last_crossing_q16 - first_crossing_q16;
    uint64_t period_q16 =
        (span_q16 + (crossing_count - 1U) / 2U) /
        (crossing_count - 1U);
    if (period_q16 == 0U)
    {
        *frequency = (rabi_signal_frequency_u16_t){0};
        return RABI_ERR_FAIL;
    }

    uint64_t frequency_millihz =
        ((uint64_t)sample_rate_hz * 1000U * 65536U +
         period_q16 / 2U) / period_q16;
    if (frequency_millihz > UINT32_MAX)
    {
        frequency_millihz = UINT32_MAX;
    }

    *frequency = (rabi_signal_frequency_u16_t){
        .frequency_millihz = (uint32_t)frequency_millihz,
        .period_samples_q16 = period_q16,
        .rising_crossings = crossing_count,
    };
    return RABI_ERR_OK;
}
