/* Rabi 核心模块：公共工具宏。 */
#pragma once

#if defined(__cplusplus)
extern "C"
{
#endif

static inline float rabi_utils_clamp_int(int value, int min, int max)
{
    return value > min ? (value < max ? value : max) : min;
}

static inline float rabi_utils_clamp_float(float value, float min, float max)
{
    return value > min ? (value < max ? value : max) : min;
}

#if defined(__cplusplus)
}
#endif
