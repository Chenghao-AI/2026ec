#ifndef __SPECTRUM_H
#define __SPECTRUM_H

#include "main.h"
#include <stdint.h>

/* 系统当前暂定有效中频中心 */
#define SPECTRUM_IF_HZ              10700000UL

/* AD9959降频扫描参数 */
#define SPECTRUM_LO_START_HZ        10700000UL
#define SPECTRUM_LO_STOP_HZ         10100000UL
#define SPECTRUM_LO_STEP_HZ         500UL

/* AD9959通道与幅度设置 */
#define SPECTRUM_MEASUREMENT_DDS_CHANNEL      0U
#define SPECTRUM_BASELINE_DDS_CHANNEL         3U
#define SPECTRUM_MEASUREMENT_DDS_AMPLITUDE    91U
/*
 * 幅值线性标定参数
 *
 * amplitude_mv =
 *     (detector_voltage_v - zero_voltage_v) * gain_mv_per_v
 *
 * 下面两个数值目前只是初始占位值，必须通过实际标定修改。
 */
#define SPECTRUM_DETECTOR_ZERO_V       0.300f
#define SPECTRUM_GAIN_MV_PER_V         100.0f

/* 只处理题目规定的10kHz~500kHz频率范围 */
#define SPECTRUM_VALID_FREQ_MIN_HZ      10000UL
#define SPECTRUM_VALID_FREQ_MAX_HZ      500000UL
/* 共1201个频点 */
#define SPECTRUM_POINT_COUNT        \
    (((SPECTRUM_LO_START_HZ - SPECTRUM_LO_STOP_HZ) / \
      SPECTRUM_LO_STEP_HZ) + 1UL)

/* 每个频点ADC平均次数 */
#define SPECTRUM_ADC_SAMPLE_COUNT   8U

/* DDS切换后等待模拟链路稳定，初始先设为400us */
#define SPECTRUM_SETTLE_US          400U
/* 最多保留的候选谱峰数量 */
#define SPECTRUM_MAX_CANDIDATE_PEAKS       12U

/* 有效谱峰最低幅值，后续根据噪声底调整 */
#define SPECTRUM_PEAK_THRESHOLD_MV         3.0f

/* 基波最低10kHz，因此不同频率分量至少相隔10kHz */
#define SPECTRUM_PEAK_MIN_DISTANCE_HZ      10000UL

/* 谐波整数倍关系允许误差：目标整数倍频率左右各3kHz */
#define SPECTRUM_HARMONIC_TOLERANCE_HZ     3000UL

/*
 * 非对称基波峰精修参数：在第一候选峰左侧10kHz内寻找最强上升沿，
 * 再定位“快速上升后出现的第一个峰顶”。点数均以500Hz扫频步进为单位。
 */
#define SPECTRUM_BASE_REFINE_WINDOW_HZ             10000UL
#define SPECTRUM_BASE_RISE_SPAN_POINTS             4U
#define SPECTRUM_BASE_FALL_CONFIRM_POINTS          4U
#define SPECTRUM_BASE_RAW_RADIUS_POINTS            1U
#define SPECTRUM_BASE_MIN_RISE_MV                   1.0f
#define SPECTRUM_BASE_FALL_TOLERANCE_MV             0.20f
#define SPECTRUM_BASE_RAW_PLATEAU_TOLERANCE_MV      0.10f

typedef struct
{
    uint32_t frequency_hz;
    float amplitude_mv;
    uint32_t point_index;
} SpectrumPeak_t;

/*
 * 该结构体可以直接传给屏幕显示函数。
 */
typedef struct
{
    uint8_t component_count;

    float f1_khz;
    float a1_mv;

    float f2_khz;
    float a2_mv;

    float f3_khz;
    float a3_mv;
} SpectrumDisplayResult_t;


typedef struct
{
    uint32_t lo_frequency_hz;       /* AD9959本振频率 */
    uint32_t input_frequency_hz;    /* 映射后的输入信号频率 */

    uint16_t adc_raw;               /* ADC平均原始值 */
    float detector_voltage_v;       /* AD8307输出电压 */
    float amplitude_mv;             /* 后续标定得到的输入幅值 */
} SpectrumPoint_t;

typedef enum
{
    SPECTRUM_OK = 0,
    SPECTRUM_ERROR_PARAM,
    SPECTRUM_ERROR_ADC,
    SPECTRUM_ERROR_TIMEOUT
} SpectrumStatus_t;

/* 扫频结果数组 */
extern SpectrumPoint_t g_spectrum_points[SPECTRUM_POINT_COUNT];

/* 实际同步扫频耗时 */
extern uint32_t g_spectrum_scan_time_ms;

/* 同步扫频并采集ADC */
SpectrumStatus_t Spectrum_RunSynchronousSweep(uint8_t ad9959_channel);

/* 使用指定DDS幅度采集一次空扫基底 */
SpectrumStatus_t Spectrum_CaptureBaseline(
    uint8_t ad9959_channel,
    uint16_t ad9959_amplitude);

/* 每次调用均先用OUT3空扫，再用OUT0正式扫频 */
SpectrumStatus_t Spectrum_RunBaselineCorrectedSweep(
    uint16_t baseline_amplitude);
/**
  * @brief 将所有频点的AD8307输出电压换算为输入信号幅值
  */
void Spectrum_ConvertRawVoltageToAmplitude(void);

/**
  * @brief  从频率-幅值数组中识别基波和1~2个谐波
  * @param  result 返回可直接传给屏幕的参数
  * @retval 识别出的频率分量数量：0~3
  */
uint8_t Spectrum_IdentifyComponents(
    SpectrumDisplayResult_t *result);
#endif
