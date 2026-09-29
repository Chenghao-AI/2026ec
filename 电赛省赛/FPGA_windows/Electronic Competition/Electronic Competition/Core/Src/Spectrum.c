#include "Spectrum.h"
#include "AD9959.h"
#include "adc.h"

SpectrumPoint_t g_spectrum_points[SPECTRUM_POINT_COUNT];
uint32_t g_spectrum_scan_time_ms = 0U;

/* OUT3空扫得到的逐频点ADC基底 */
static uint16_t g_spectrum_baseline_adc[SPECTRUM_POINT_COUNT] = {0};
static uint8_t g_spectrum_baseline_valid = 0U;

/**
  * @brief  对当前AD8307输出电压进行多次ADC采样并取平均
  * @param  average_raw 用于返回平均ADC原始值
  * @retval SpectrumStatus_t
  *
  * @note
  * 该函数定义为static，只允许Spectrum.c内部调用。
  */
static SpectrumStatus_t Spectrum_ADC_ReadAverage(uint16_t *average_raw)
{
    uint32_t sum = 0U;
    uint32_t sample_index;
    uint16_t adc_value;

    if (average_raw == NULL)
    {
        return SPECTRUM_ERROR_PARAM;
    }

    for (sample_index = 0U;
         sample_index < SPECTRUM_ADC_SAMPLE_COUNT;
         sample_index++)
    {
        /*
         * 启动一次ADC转换。
         * 当前版本优先保证简单可靠，后续再改成连续转换或DMA。
         */
        if (HAL_ADC_Start(&hadc1) != HAL_OK)
        {
            HAL_ADC_Stop(&hadc1);
            return SPECTRUM_ERROR_ADC;
        }

        /*
         * 等待ADC转换结束。
         * 超时设为1ms，但正常ADC转换远小于1ms。
         */
        if (HAL_ADC_PollForConversion(&hadc1, 1U) != HAL_OK)
        {
            HAL_ADC_Stop(&hadc1);
            return SPECTRUM_ERROR_ADC;
        }

        adc_value = (uint16_t)HAL_ADC_GetValue(&hadc1);
        sum += adc_value;

        HAL_ADC_Stop(&hadc1);
    }

    /*
     * 加上N/2后再除以N，实现整数四舍五入。
     */
    *average_raw =
        (uint16_t)((sum + SPECTRUM_ADC_SAMPLE_COUNT / 2U) /
                   SPECTRUM_ADC_SAMPLE_COUNT);

    return SPECTRUM_OK;
}
static SpectrumStatus_t Spectrum_RunSweepWithAmplitude(
    uint8_t ad9959_channel,
    uint16_t ad9959_amplitude)
{
    uint32_t start_tick;
    uint32_t point_index;
    uint32_t lo_frequency_hz;

    uint16_t adc_average;
    SpectrumStatus_t status;

    if ((ad9959_channel > 3U) ||
        (ad9959_amplitude > 1023U))
    {
        return SPECTRUM_ERROR_PARAM;
    }

    start_tick = HAL_GetTick();

    /*
     * 第一个频点完整配置AD9959：
     * 选择通道、设置单频模式、设置10.7MHz。
     * 改扫频载波幅度
     */
    AD9959_SetChannelFreqAndAmp(
        ad9959_channel,
        (double)SPECTRUM_LO_START_HZ,
        (int)ad9959_amplitude);

    for (point_index = 0U;
         point_index < SPECTRUM_POINT_COUNT;
         point_index++)
    {
        lo_frequency_hz =
            SPECTRUM_LO_START_HZ -
            point_index * SPECTRUM_LO_STEP_HZ;

        /*
         * 第0个频点已在循环前设置。
         * 后续频点只写频率控制字，减少时间。
         */
        if (point_index != 0U)
        {
            AD9959_SetWaveFrequency((double)lo_frequency_hz);
        }

        /*
         * 等待DDS、混频器、中滤、中放和AD8307稳定。
         */
        AD9959_DelayUs(SPECTRUM_SETTLE_US);

        /*
         * 稳定后立刻采集当前频点ADC。
         * ADC采样完成之前绝不进入下一频点。
         */
        status = Spectrum_ADC_ReadAverage(&adc_average);

        if (status != SPECTRUM_OK)
        {
            return status;
        }

        /*
         * 保存本振频率。
         */
        g_spectrum_points[point_index].lo_frequency_hz =
            lo_frequency_hz;

        /*
         * 输入频率 = 10.7MHz - 本振频率。
         */
        if ((SPECTRUM_IF_HZ - lo_frequency_hz) >= 9500UL)
        {
            g_spectrum_points[point_index].input_frequency_hz =
                SPECTRUM_IF_HZ - lo_frequency_hz - 9500UL;
        }
        else
        {
            g_spectrum_points[point_index].input_frequency_hz = 0UL;
        }

        /*
         * 保存ADC平均值。
         */
        g_spectrum_points[point_index].adc_raw =
            adc_average;

        /*
         * 暂按3.3V参考电压、12位ADC换算。
         * 后续需要用万用表实测ADC参考电压进行修正。
         */
        g_spectrum_points[point_index].detector_voltage_v =
            ((float)adc_average * 3.300f) / 4095.0f;

        /*
         * 幅值标定尚未实现，暂时清零。
         */
        g_spectrum_points[point_index].amplitude_mv = 0.0f;
    }

    g_spectrum_scan_time_ms = HAL_GetTick() - start_tick;

    /*
     * 这里只检查同步扫频本身是否过慢。
     */
    if (g_spectrum_scan_time_ms > 1500U)
    {
        return SPECTRUM_ERROR_TIMEOUT;
    }

    return SPECTRUM_OK;
}

SpectrumStatus_t Spectrum_RunSynchronousSweep(uint8_t ad9959_channel)
{
    return Spectrum_RunSweepWithAmplitude(
        ad9959_channel,
        SPECTRUM_MEASUREMENT_DDS_AMPLITUDE);
}

SpectrumStatus_t Spectrum_CaptureBaseline(
    uint8_t ad9959_channel,
    uint16_t ad9959_amplitude)
{
    SpectrumStatus_t status;
    uint32_t point_index;

    g_spectrum_baseline_valid = 0U;

    status = Spectrum_RunSweepWithAmplitude(
        ad9959_channel,
        ad9959_amplitude);

    if (status != SPECTRUM_OK)
    {
        return status;
    }

    for (point_index = 0U;
         point_index < SPECTRUM_POINT_COUNT;
         point_index++)
    {
        g_spectrum_baseline_adc[point_index] =
            g_spectrum_points[point_index].adc_raw;
    }

    g_spectrum_baseline_valid = 1U;

    return SPECTRUM_OK;
}

SpectrumStatus_t Spectrum_RunBaselineCorrectedSweep(
    uint16_t baseline_amplitude)
{
//    SpectrumStatus_t status;

    if (baseline_amplitude > 1023U)
    {
        return SPECTRUM_ERROR_PARAM;
    }

    /* 空扫前关闭CH0，避免正式载波同时存在 */
//    AD9959_SetChannelFreqAndAmp(
//        SPECTRUM_MEASUREMENT_DDS_CHANNEL,
//        (double)SPECTRUM_LO_START_HZ,
//        0);

    /* OUT3按指定幅度完成一次空扫并保存基底 */
//    status = Spectrum_CaptureBaseline(
//        SPECTRUM_BASELINE_DDS_CHANNEL,
//        baseline_amplitude);

    /* 空扫结束后立即关闭OUT3 */
//    AD9959_SetChannelFreqAndAmp(
//        SPECTRUM_BASELINE_DDS_CHANNEL,
//        (double)SPECTRUM_LO_START_HZ,
//        0);

//    if (status != SPECTRUM_OK)
//    {
//        return status;
//    }

    /* CH0执行正式扫频 */
    return Spectrum_RunSynchronousSweep(
        SPECTRUM_MEASUREMENT_DDS_CHANNEL);
}
/**
  * @brief  将AD8307输出电压转换为原输入信号频谱幅值
  * @note   当前采用线性标定模型，后续根据实测标定参数进行修正
  */
void Spectrum_ConvertRawVoltageToAmplitude(void)
{
    uint32_t point_index;
    float corrected_voltage_v;
    float amplitude_mv;

    for (point_index = 0U;
         point_index < SPECTRUM_POINT_COUNT;
         point_index++)
    {
        /*
         * 扫频范围实际覆盖约9kHz~600kHz，
         * 但题目有效信号范围为10kHz~500kHz。
         * 范围之外的数据不参与后续峰值识别。
         */
        if ((g_spectrum_points[point_index].input_frequency_hz <
             SPECTRUM_VALID_FREQ_MIN_HZ) ||
            (g_spectrum_points[point_index].input_frequency_hz >
             SPECTRUM_VALID_FREQ_MAX_HZ))
        {
            g_spectrum_points[point_index].amplitude_mv = 0.0f;
            continue;
        }

        /*
         * 去除无输入信号时，模拟链路和AD8307产生的基准输出。
         */
        if (g_spectrum_baseline_valid != 0U)
        {
            float baseline_voltage_v;

            baseline_voltage_v =
                ((float)g_spectrum_baseline_adc[point_index] *
                 3.300f) / 4095.0f;

            corrected_voltage_v =
                g_spectrum_points[point_index].detector_voltage_v -
                baseline_voltage_v;
        }
        else
        {
            corrected_voltage_v =
                g_spectrum_points[point_index].detector_voltage_v -
                SPECTRUM_DETECTOR_ZERO_V;
        }

        /*
         * 检波电压低于基准时，认为当前频率不存在有效信号，
         * 防止得到负幅值。
         */
        if (corrected_voltage_v <= 0.0f)
        {
            g_spectrum_points[point_index].amplitude_mv = 0.0f;
            continue;
        }

        /*
         * 当前使用简单线性换算。
         * 后续可替换为分段线性插值或查表标定。
         */
        amplitude_mv =
            corrected_voltage_v * SPECTRUM_GAIN_MV_PER_V;

        /*
         * 防止异常ADC数据产生过大的幅值结果。
         * 题目信号总峰峰值最大250mV，这里适当留出余量。
         */
        if (amplitude_mv > 500.0f)
        {
            amplitude_mv = 500.0f;
        }

        g_spectrum_points[point_index].amplitude_mv =
            amplitude_mv;
    }
}

/**
  * @brief  获取当前频点的3点平滑幅值
  * @note   不额外申请1183点数组，减少RAM占用
  */
static float Spectrum_GetSmoothedAmplitude(uint32_t point_index)
{
    if ((point_index == 0U) ||
        (point_index >= (SPECTRUM_POINT_COUNT - 1U)))
    {
        return g_spectrum_points[point_index].amplitude_mv;
    }

    return (g_spectrum_points[point_index - 1U].amplitude_mv +
            g_spectrum_points[point_index].amplitude_mv +
            g_spectrum_points[point_index + 1U].amplitude_mv) /
           3.0f;
}

/**
  * @brief  计算两个无符号频率值的差值绝对值
  */
static uint32_t Spectrum_FrequencyDifference(uint32_t f1_hz,
                                             uint32_t f2_hz)
{
    if (f1_hz >= f2_hz)
    {
        return f1_hz - f2_hz;
    }

    return f2_hz - f1_hz;
}

/**
  * @brief  将候选峰按照幅值从大到小插入数组
  */
static void Spectrum_InsertPeakByAmplitude(
    SpectrumPeak_t peaks[],
    uint8_t *peak_count,
    SpectrumPeak_t new_peak)
{
    uint8_t insert_index;
    uint8_t move_index;

    if ((peaks == NULL) || (peak_count == NULL))
    {
        return;
    }

    insert_index = *peak_count;

    for (uint8_t i = 0U; i < *peak_count; i++)
    {
        if (new_peak.amplitude_mv > peaks[i].amplitude_mv)
        {
            insert_index = i;
            break;
        }
    }

    /*
     * 数组已满，并且新峰小于已有所有峰。
     */
    if ((*peak_count >= SPECTRUM_MAX_CANDIDATE_PEAKS) &&
        (insert_index >= SPECTRUM_MAX_CANDIDATE_PEAKS))
    {
        return;
    }

    if (*peak_count < SPECTRUM_MAX_CANDIDATE_PEAKS)
    {
        (*peak_count)++;
    }

    move_index = *peak_count - 1U;

    while (move_index > insert_index)
    {
        peaks[move_index] = peaks[move_index - 1U];
        move_index--;
    }

    peaks[insert_index] = new_peak;
}

/**
  * @brief  在完整频率-幅值数组中寻找独立候选谱峰
  * @note
  * 1. 只分析10kHz~500kHz；
  * 2. 使用3点平滑判断局部峰值；
  * 3. 两个独立峰至少相隔10kHz；
  * 4. 同一个峰簇只保留幅值最大点。
  */
static uint8_t Spectrum_FindCandidatePeaks(
    SpectrumPeak_t candidate_peaks[])
{
    SpectrumPeak_t new_peak;
    uint8_t peak_count = 0U;

    if (candidate_peaks == NULL)
    {
        return 0U;
    }

    for (uint32_t point_index = 1U;
         point_index < (SPECTRUM_POINT_COUNT - 1U);
         point_index++)
    {
        uint32_t frequency_hz;
        float previous_amplitude;
        float current_amplitude;
        float next_amplitude;
        uint8_t merged = 0U;

        frequency_hz =
            g_spectrum_points[point_index].input_frequency_hz;

        if ((frequency_hz < SPECTRUM_VALID_FREQ_MIN_HZ) ||
            (frequency_hz > SPECTRUM_VALID_FREQ_MAX_HZ))
        {
            continue;
        }

        previous_amplitude =
            Spectrum_GetSmoothedAmplitude(point_index - 1U);

        current_amplitude =
            Spectrum_GetSmoothedAmplitude(point_index);

        next_amplitude =
            Spectrum_GetSmoothedAmplitude(point_index + 1U);

        /*
         * 判断局部极大值。
         * 左边严格小于当前点，右边允许与当前点相等，
         * 可以避免平顶峰被完全漏掉。
         */
        if (!((current_amplitude > previous_amplitude) &&
              (current_amplitude >= next_amplitude)))
        {
            continue;
        }

        if (current_amplitude < SPECTRUM_PEAK_THRESHOLD_MV)
        {
            continue;
        }

        new_peak.frequency_hz = frequency_hz;

        /*
         * 输出幅值使用原始中心点幅值，不使用3点平均值，
         * 避免平滑导致谱线幅值下降。
         */
        new_peak.amplitude_mv =
            g_spectrum_points[point_index].amplitude_mv;

        new_peak.point_index = point_index;

        /*
         * 检查新峰是否属于已存在峰的同一峰簇。
         */
        for (uint8_t peak_index = 0U;
             peak_index < peak_count;
             peak_index++)
        {
            uint32_t frequency_difference =
                Spectrum_FrequencyDifference(
                    new_peak.frequency_hz,
                    candidate_peaks[peak_index].frequency_hz);

            if (frequency_difference <
                SPECTRUM_PEAK_MIN_DISTANCE_HZ)
            {
                /*
                 * 两者间隔小于10kHz，认为属于同一条谱线，
                 * 仅保留幅值较大的点。
                 */
                if (new_peak.amplitude_mv >
                    candidate_peaks[peak_index].amplitude_mv)
                {
                    candidate_peaks[peak_index] = new_peak;
                }

                merged = 1U;
                break;
            }
        }

        if (merged == 0U)
        {
            Spectrum_InsertPeakByAmplitude(
                candidate_peaks,
                &peak_count,
                new_peak);
        }
    }

    return peak_count;
}

/**
  * @brief  判断candidate_hz是否为fundamental_hz的整数倍谐波
  * @retval 0表示不是谐波，2及以上表示谐波次数
  */
static uint16_t Spectrum_GetHarmonicOrder(
    uint32_t fundamental_hz,
    uint32_t candidate_hz)
{
    uint32_t harmonic_order;
    uint32_t expected_frequency_hz;
    uint32_t error_hz;

    if ((fundamental_hz < 10000UL) ||
        (candidate_hz <= fundamental_hz))
    {
        return 0U;
    }

    /*
     * 通过整数四舍五入估算谐波次数。
     */
    harmonic_order =
        (candidate_hz + fundamental_hz / 2U) /
        fundamental_hz;

    if (harmonic_order < 2U)
    {
        return 0U;
    }

    /*
     * 当前最高频率500kHz，乘法不存在uint32_t溢出风险。
     */
    expected_frequency_hz =
        harmonic_order * fundamental_hz;

    error_hz =
        Spectrum_FrequencyDifference(
            candidate_hz,
            expected_frequency_hz);

    if (error_hz <= SPECTRUM_HARMONIC_TOLERANCE_HZ)
    {
        return (uint16_t)harmonic_order;
    }

    return 0U;
}

/**
  * @brief  按频率从低到高交换排序
  */
static void Spectrum_SortPeaksByFrequency(
    SpectrumPeak_t peaks[],
    uint8_t peak_count)
{
    SpectrumPeak_t temporary_peak;

    for (uint8_t i = 0U; i < peak_count; i++)
    {
        for (uint8_t j = i + 1U; j < peak_count; j++)
        {
            if (peaks[j].frequency_hz <
                peaks[i].frequency_hz)
            {
                temporary_peak = peaks[i];
                peaks[i] = peaks[j];
                peaks[j] = temporary_peak;
            }
        }
    }
}

/**
  * @brief  根据“快速上升、峰顶、缓慢下降”的非对称峰形精修基波
  * @note
  * 1. 只处理已经筛出的最左候选峰，不改变其他候选峰；
  * 2. 在候选峰左侧窗口内寻找2kHz累计上升量最大的区段；
  * 3. 从该上升区段向右取第一个得到下降确认的平滑峰顶；
  * 4. 最后在峰顶相邻点中选原始幅值最大点，频率仍落在500Hz网格。
  */
static SpectrumPeak_t Spectrum_RefineAsymmetricFundamental(
    SpectrumPeak_t seed_peak)
{
    SpectrumPeak_t refined_peak = seed_peak;
    uint32_t window_points;
    uint32_t left_index;
    uint32_t rise_search_start;
    uint32_t rise_search_end;
    uint32_t rise_index = 0U;
    uint32_t crest_index = 0U;
    uint32_t raw_start_index;
    uint32_t raw_end_index;
    uint32_t refined_index;
    float best_rise = 0.0f;
    float raw_max_amplitude;
    uint8_t rise_found = 0U;
    uint8_t crest_found = 0U;

    if ((seed_peak.point_index == 0U) ||
        (seed_peak.point_index >= SPECTRUM_POINT_COUNT) ||
        (SPECTRUM_LO_STEP_HZ == 0U) ||
        (SPECTRUM_POINT_COUNT <=
         (SPECTRUM_BASE_FALL_CONFIRM_POINTS + 1U)))
    {
        return refined_peak;
    }

    window_points =
        SPECTRUM_BASE_REFINE_WINDOW_HZ /
        SPECTRUM_LO_STEP_HZ;

    if ((window_points <= SPECTRUM_BASE_RISE_SPAN_POINTS) ||
        (seed_peak.point_index <=
         SPECTRUM_BASE_RISE_SPAN_POINTS))
    {
        return refined_peak;
    }

    if (seed_peak.point_index > window_points)
    {
        left_index = seed_peak.point_index - window_points;
    }
    else
    {
        left_index = 1U;
    }

    rise_search_start =
        left_index + SPECTRUM_BASE_RISE_SPAN_POINTS;

    rise_search_end = seed_peak.point_index;

    if (rise_search_end >
        (SPECTRUM_POINT_COUNT - 1U -
         SPECTRUM_BASE_FALL_CONFIRM_POINTS))
    {
        rise_search_end =
            SPECTRUM_POINT_COUNT - 1U -
            SPECTRUM_BASE_FALL_CONFIRM_POINTS;
    }

    if (rise_search_start > rise_search_end)
    {
        return refined_peak;
    }

    for (uint32_t point_index = rise_search_start;
         point_index <= rise_search_end;
         point_index++)
    {
        float rise =
            Spectrum_GetSmoothedAmplitude(point_index) -
            Spectrum_GetSmoothedAmplitude(
                point_index -
                SPECTRUM_BASE_RISE_SPAN_POINTS);

        if (rise > best_rise)
        {
            best_rise = rise;
            rise_index = point_index;
            rise_found = 1U;
        }
    }

    if ((rise_found == 0U) ||
        (best_rise < SPECTRUM_BASE_MIN_RISE_MV))
    {
        return refined_peak;
    }

    for (uint32_t point_index = rise_index;
         point_index <= rise_search_end;
         point_index++)
    {
        float previous_amplitude =
            Spectrum_GetSmoothedAmplitude(point_index - 1U);

        float current_amplitude =
            Spectrum_GetSmoothedAmplitude(point_index);

        float next_amplitude =
            Spectrum_GetSmoothedAmplitude(point_index + 1U);

        float confirmed_amplitude =
            Spectrum_GetSmoothedAmplitude(
                point_index +
                SPECTRUM_BASE_FALL_CONFIRM_POINTS);

        if ((current_amplitude > previous_amplitude) &&
            (current_amplitude >= next_amplitude) &&
            (confirmed_amplitude <=
             current_amplitude +
             SPECTRUM_BASE_FALL_TOLERANCE_MV))
        {
            crest_index = point_index;
            crest_found = 1U;
            break;
        }
    }

    if (crest_found == 0U)
    {
        return refined_peak;
    }

    if (crest_index > SPECTRUM_BASE_RAW_RADIUS_POINTS)
    {
        raw_start_index =
            crest_index - SPECTRUM_BASE_RAW_RADIUS_POINTS;
    }
    else
    {
        raw_start_index = 0U;
    }

    raw_end_index =
        crest_index + SPECTRUM_BASE_RAW_RADIUS_POINTS;

    if (raw_end_index >= SPECTRUM_POINT_COUNT)
    {
        raw_end_index = SPECTRUM_POINT_COUNT - 1U;
    }

    raw_max_amplitude =
        g_spectrum_points[raw_start_index].amplitude_mv;

    for (uint32_t point_index = raw_start_index + 1U;
         point_index <= raw_end_index;
         point_index++)
    {
        if (g_spectrum_points[point_index].amplitude_mv >
            raw_max_amplitude)
        {
            raw_max_amplitude =
                g_spectrum_points[point_index].amplitude_mv;
        }
    }

    /*
     * 平台内多个点幅值接近时优先取最左点，避免慢降尾部的
     * 一两个ADC码抖动把基频继续推向高频。
     */
    refined_index = raw_start_index;

    for (uint32_t point_index = raw_start_index;
         point_index <= raw_end_index;
         point_index++)
    {
        if (g_spectrum_points[point_index].amplitude_mv >=
            (raw_max_amplitude -
             SPECTRUM_BASE_RAW_PLATEAU_TOLERANCE_MV))
        {
            refined_index = point_index;
            break;
        }
    }

    refined_peak.frequency_hz =
        g_spectrum_points[refined_index].input_frequency_hz;

    refined_peak.amplitude_mv =
        g_spectrum_points[refined_index].amplitude_mv;

    refined_peak.point_index = refined_index;

    return refined_peak;
}

/**
  * @brief  从完整频谱中识别基波及1~2个谐波
  */
uint8_t Spectrum_IdentifyComponents(
    SpectrumDisplayResult_t *result)
{
    SpectrumPeak_t candidate_peaks[
        SPECTRUM_MAX_CANDIDATE_PEAKS];

    SpectrumPeak_t selected_peaks[3];

    uint8_t candidate_count;
    uint8_t selected_count = 0U;

    if (result == NULL)
    {
        return 0U;
    }

    /*
     * 先清空输出，识别失败时屏幕不会收到旧数据。
     */
    result->component_count = 0U;

    result->f1_khz = 0.0f;
    result->a1_mv = 0.0f;

    result->f2_khz = 0.0f;
    result->a2_mv = 0.0f;

    result->f3_khz = 0.0f;
    result->a3_mv = 0.0f;

    candidate_count =
        Spectrum_FindCandidatePeaks(candidate_peaks);

    if (candidate_count == 0U)
    {
        return 0U;
    }

    /*
     * 候选峰原本按幅值保存；先改为从低频到高频排列。
     * 用户规则规定：从左往右的第一个候选峰固定作为基波。
     */
    Spectrum_SortPeaksByFrequency(
        candidate_peaks,
        candidate_count);

    selected_peaks[0] =
        Spectrum_RefineAsymmetricFundamental(
            candidate_peaks[0]);
    selected_count = 1U;

    /*
     * 只考察基波任意整数倍频率左右3kHz内的候选峰。
     * 候选峰已经按频率升序排列，因此取到的也是从左到右
     * 最先出现的两个合格谐波。
     */
    for (uint8_t peak_index = 1U;
         peak_index < candidate_count;
         peak_index++)
    {
        if (Spectrum_GetHarmonicOrder(
                selected_peaks[0].frequency_hz,
                candidate_peaks[peak_index].frequency_hz) == 0U)
        {
            continue;
        }

        if (selected_count < 3U)
        {
            selected_peaks[selected_count] =
                candidate_peaks[peak_index];

            selected_count++;
        }

        if (selected_count >= 3U)
        {
            break;
        }
    }

    result->component_count = selected_count;

    result->f1_khz =
        selected_peaks[0].frequency_hz / 1000.0f;

    result->a1_mv =
        selected_peaks[0].amplitude_mv;

    if (selected_count >= 2U)
    {
        result->f2_khz =
            selected_peaks[1].frequency_hz / 1000.0f;

        result->a2_mv =
            selected_peaks[1].amplitude_mv;
    }

    if (selected_count >= 3U)
    {
        result->f3_khz =
            selected_peaks[2].frequency_hz / 1000.0f;

        result->a3_mv =
            selected_peaks[2].amplitude_mv;
    }

    return result->component_count;
}
