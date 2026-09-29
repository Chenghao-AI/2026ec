/* Rabi 备用模块：常用轻量数字滤波和迟滞工具实现。 */
#include <float.h>
#include "rabi_filter.h"

static bool float_is_valid(float value)
{
    /* NaN 是唯一不等于自身的 float。基础模块拒绝 NaN，避免状态被永久污染。 */
    return value == value && value <= FLT_MAX && value >= -FLT_MAX;
}

rabi_err_t rabi_moving_average_u16_init(
    rabi_moving_average_u16_t *filter,
    uint16_t *storage,
    size_t window_size)
{
    if (filter == NULL || storage == NULL || window_size == 0U ||
        window_size > UINT16_MAX)
    {
        return RABI_ERR_INVALID_ARG;
    }

    *filter = (rabi_moving_average_u16_t){
        .storage = storage,
        .window_size = window_size,
        .count = 0U,
        .index = 0U,
        .sum = 0U,
        .initialized = true,
    };
    return RABI_ERR_OK;
}

rabi_err_t rabi_moving_average_u16_reset(
    rabi_moving_average_u16_t *filter)
{
    if (filter == NULL || !filter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    filter->count = 0U;
    filter->index = 0U;
    filter->sum = 0U;
    return RABI_ERR_OK;
}

rabi_err_t rabi_moving_average_u16_push(
    rabi_moving_average_u16_t *filter,
    uint16_t sample,
    uint16_t *output)
{
    if (output == NULL) return RABI_ERR_INVALID_ARG;
    if (filter == NULL || !filter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (filter->count < filter->window_size)
    {
        filter->storage[filter->index] = sample;
        filter->sum += sample;
        filter->count++;
    }
    else
    {
        filter->sum -= filter->storage[filter->index];
        filter->storage[filter->index] = sample;
        filter->sum += sample;
    }

    filter->index++;
    if (filter->index >= filter->window_size) filter->index = 0U;

    *output = (uint16_t)(
        (filter->sum + (uint32_t)(filter->count / 2U)) /
        (uint32_t)filter->count);
    return RABI_ERR_OK;
}

rabi_err_t rabi_ema_f32_init(
    rabi_ema_f32_t *filter, float alpha)
{
    if (filter == NULL || !float_is_valid(alpha) ||
        alpha <= 0.0f || alpha > 1.0f)
    {
        return RABI_ERR_INVALID_ARG;
    }

    *filter = (rabi_ema_f32_t){
        .alpha = alpha,
        .value = 0.0f,
        .has_value = false,
        .initialized = true,
    };
    return RABI_ERR_OK;
}

rabi_err_t rabi_ema_f32_reset(
    rabi_ema_f32_t *filter, float value)
{
    if (!float_is_valid(value)) return RABI_ERR_INVALID_ARG;
    if (filter == NULL || !filter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    filter->value = value;
    filter->has_value = true;
    return RABI_ERR_OK;
}

rabi_err_t rabi_ema_f32_push(
    rabi_ema_f32_t *filter, float sample, float *output)
{
    if (output == NULL || !float_is_valid(sample))
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (filter == NULL || !filter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (!filter->has_value)
    {
        filter->value = sample;
        filter->has_value = true;
    }
    else
    {
        filter->value += filter->alpha * (sample - filter->value);
    }

    *output = filter->value;
    return RABI_ERR_OK;
}

rabi_err_t rabi_median_u16_init(
    rabi_median_u16_t *filter, uint8_t window_size)
{
    if (filter == NULL || window_size < 3U ||
        window_size > RABI_MEDIAN_U16_MAX_WINDOW ||
        (window_size & 1U) == 0U)
    {
        return RABI_ERR_INVALID_ARG;
    }

    *filter = (rabi_median_u16_t){
        .samples = {0U},
        .window_size = window_size,
        .count = 0U,
        .index = 0U,
        .initialized = true,
    };
    return RABI_ERR_OK;
}

rabi_err_t rabi_median_u16_reset(rabi_median_u16_t *filter)
{
    if (filter == NULL || !filter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    filter->count = 0U;
    filter->index = 0U;
    return RABI_ERR_OK;
}

rabi_err_t rabi_median_u16_push(
    rabi_median_u16_t *filter,
    uint16_t sample,
    uint16_t *output)
{
    if (output == NULL) return RABI_ERR_INVALID_ARG;
    if (filter == NULL || !filter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    filter->samples[filter->index] = sample;
    filter->index++;
    if (filter->index >= filter->window_size) filter->index = 0U;
    if (filter->count < filter->window_size) filter->count++;

    uint16_t sorted[RABI_MEDIAN_U16_MAX_WINDOW];
    for (uint8_t i = 0U; i < filter->count; i++)
    {
        sorted[i] = filter->samples[i];
    }

    /* 最大只有 9 点，插入排序比引入通用 qsort 更小、更可预测。 */
    for (uint8_t i = 1U; i < filter->count; i++)
    {
        uint16_t value = sorted[i];
        uint8_t j = i;
        while (j > 0U && sorted[j - 1U] > value)
        {
            sorted[j] = sorted[j - 1U];
            j--;
        }
        sorted[j] = value;
    }

    uint8_t middle = filter->count / 2U;
    if ((filter->count & 1U) != 0U)
    {
        *output = sorted[middle];
    }
    else
    {
        *output = (uint16_t)(((uint32_t)sorted[middle - 1U] +
                             sorted[middle] + 1U) / 2U);
    }
    return RABI_ERR_OK;
}

rabi_err_t rabi_slew_limiter_f32_init(
    rabi_slew_limiter_f32_t *limiter,
    float rise_per_step,
    float fall_per_step)
{
    if (limiter == NULL || !float_is_valid(rise_per_step) ||
        !float_is_valid(fall_per_step) ||
        rise_per_step <= 0.0f || fall_per_step <= 0.0f)
    {
        return RABI_ERR_INVALID_ARG;
    }

    *limiter = (rabi_slew_limiter_f32_t){
        .rise_per_step = rise_per_step,
        .fall_per_step = fall_per_step,
        .value = 0.0f,
        .has_value = false,
        .initialized = true,
    };
    return RABI_ERR_OK;
}

rabi_err_t rabi_slew_limiter_f32_reset(
    rabi_slew_limiter_f32_t *limiter, float value)
{
    if (!float_is_valid(value)) return RABI_ERR_INVALID_ARG;
    if (limiter == NULL || !limiter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    limiter->value = value;
    limiter->has_value = true;
    return RABI_ERR_OK;
}

rabi_err_t rabi_slew_limiter_f32_update(
    rabi_slew_limiter_f32_t *limiter,
    float target,
    float *output)
{
    if (output == NULL || !float_is_valid(target))
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (limiter == NULL || !limiter->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (!limiter->has_value)
    {
        limiter->value = target;
        limiter->has_value = true;
    }
    else if (target > limiter->value + limiter->rise_per_step)
    {
        limiter->value += limiter->rise_per_step;
    }
    else if (target < limiter->value - limiter->fall_per_step)
    {
        limiter->value -= limiter->fall_per_step;
    }
    else
    {
        limiter->value = target;
    }

    *output = limiter->value;
    return RABI_ERR_OK;
}

rabi_err_t rabi_hysteresis_f32_init(
    rabi_hysteresis_f32_t *hysteresis,
    float low_threshold,
    float high_threshold,
    bool initial_state)
{
    if (hysteresis == NULL || !float_is_valid(low_threshold) ||
        !float_is_valid(high_threshold) || low_threshold >= high_threshold)
    {
        return RABI_ERR_INVALID_ARG;
    }

    *hysteresis = (rabi_hysteresis_f32_t){
        .low_threshold = low_threshold,
        .high_threshold = high_threshold,
        .state = initial_state,
        .initialized = true,
    };
    return RABI_ERR_OK;
}

rabi_err_t rabi_hysteresis_f32_reset(
    rabi_hysteresis_f32_t *hysteresis, bool state)
{
    if (hysteresis == NULL || !hysteresis->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    hysteresis->state = state;
    return RABI_ERR_OK;
}

rabi_err_t rabi_hysteresis_f32_update(
    rabi_hysteresis_f32_t *hysteresis,
    float input,
    bool *state)
{
    if (state == NULL || !float_is_valid(input))
    {
        return RABI_ERR_INVALID_ARG;
    }
    if (hysteresis == NULL || !hysteresis->initialized)
    {
        return RABI_ERR_INVALID_STATE;
    }

    if (!hysteresis->state && input >= hysteresis->high_threshold)
    {
        hysteresis->state = true;
    }
    else if (hysteresis->state && input <= hysteresis->low_threshold)
    {
        hysteresis->state = false;
    }

    *state = hysteresis->state;
    return RABI_ERR_OK;
}
