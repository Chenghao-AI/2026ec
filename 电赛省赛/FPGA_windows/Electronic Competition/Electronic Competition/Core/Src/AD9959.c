#include "AD9959.h"
#include <math.h>

#define system_clk 500000000.0  // 设定系统工作频率为 500MHz

// F407专用的微秒级粗略软件延时，防止时序过快芯片反应不过来
void AD9959_DelayUs(uint32_t us)
{
    volatile uint32_t delay = us * 20;
    while(delay--);
}

void AD9959_Init(void)
{
    uchar csr_all[1] = {0xF0};
    uchar fr1_init[3] = {0xD0, 0x00, 0x00};

    CS_1();
    SCLK_0();
    IO_UPDATE_0();

    PS0_0();
    PS1_0();
    PS2_0();
    PS3_0();

    SDIO0_0();
    PWR_0();

    RESET_0();
    HAL_Delay(5);
    RESET_1();
    HAL_Delay(10);
    RESET_0();
    HAL_Delay(10);

    WriteToAD9959ViaSpi(CSR, 1, csr_all, 0);
    WriteToAD9959ViaSpi(FR1, 3, fr1_init, 1);

    HAL_Delay(15);
}

// 2. 触发数据同步更新
void IO_update(void)
{
    IO_UPDATE_0();
    AD9959_DelayUs(2);
    IO_UPDATE_1();
    AD9959_DelayUs(4);
    IO_UPDATE_0();
}

// 3. 核心GPIO模拟SPI总线写入函数
void WriteToAD9959ViaSpi(uchar RegisterAddress, uchar NumberofRegisters, uchar *RegisterData, uchar temp)
{
    uchar ControlValue = RegisterAddress;
    uchar ValueToWrite = 0;
    uchar RegisterIndex = 0;
    uchar i = 0;

    SCLK_0();
    AD9959_DelayUs(1); // 刹车：等待时钟线稳在低电平
    CS_0();
    AD9959_DelayUs(1); // 刹车：等待片选稳定

    // 1. 写入控制字（寄存器地址）
    for(i = 0; i < 8; i++)
    {
        SCLK_0();
        AD9959_DelayUs(1); // 关键刹车：给数据线留出充放电时间

        if(0x80 == (ControlValue & 0x80)) SDIO0_1();
        else                              SDIO0_0();

        AD9959_DelayUs(1); // 关键刹车：确保数据电平已经稳稳建立
        SCLK_1();          // 拉高时钟，让AD9959在稳定的高电平截获数据
        AD9959_DelayUs(1); // 关键刹车：保持高电平脉冲宽度

        ControlValue <<= 1;
    }
    SCLK_0();
    AD9959_DelayUs(1);

    // 2. 写入寄存器数据内容
    for (RegisterIndex = 0; RegisterIndex < NumberofRegisters; RegisterIndex++)
    {
        ValueToWrite = RegisterData[RegisterIndex];
        for (i = 0; i < 8; i++)
        {
            SCLK_0();
            AD9959_DelayUs(1); // 关键刹车

            if(0x80 == (ValueToWrite & 0x80)) SDIO0_1();
            else                              SDIO0_0();

            AD9959_DelayUs(1); // 关键刹车
            SCLK_1();
            AD9959_DelayUs(1); // 关键刹车

            ValueToWrite <<= 1;
        }
        SCLK_0();
        AD9959_DelayUs(1);
    }

    if(temp == 1)
    {
        IO_update();
    }
    CS_1();
    AD9959_DelayUs(1);
}

// 4. 转换频率控制字 (32位)
void WrFrequencyTuningWorddata(double f, uchar *ChannelFrequencyTuningWorddata)
{
    long int y;
    double x = 4294967296.0 / system_clk;
    f = f * x;
    y = (long int)f;

    ChannelFrequencyTuningWorddata[0] = (uchar)(y >> 24);
    ChannelFrequencyTuningWorddata[1] = (uchar)(y >> 16);
    ChannelFrequencyTuningWorddata[2] = (uchar)(y >> 8);
    ChannelFrequencyTuningWorddata[3] = (uchar)(y >> 0);
}

// 5. 转换相位控制字 (14位)
void WrPhaseOffsetTuningWorddata(double f, uchar *ChannelPhaseOffsetTuningWorddata)
{
    long int y;
    double x = 16384.0 / 360.0;
    f = f * x;
    y = (long int)f;

    ChannelPhaseOffsetTuningWorddata[0] = (uchar)(y >> 8);
    ChannelPhaseOffsetTuningWorddata[1] = (uchar)(y >> 0);
}

// 转换幅度控制字 (用于 Profile 寄存器 4ASK 阶梯以及扫幅步进)
void WrAmplitudeTuningWorddata(double f, uchar *ChannelAmplitudeTuningWorddata)
{
    unsigned int y;

    // 安全限幅：先判断 double，再转换成无符号数，避免负数转换后变成大正数。
    if(f <= 0.0) y = 0U;
    else if(f >= 1023.0) y = 1023U;
    else y = (unsigned int)f;

    // AD9959 的 Profile 幅度控制字在 4 字节数据中的排布逻辑
    // 最高 8 位在 Byte0，最低 2 位在 Byte1 的高两位
    ChannelAmplitudeTuningWorddata[0] = (uchar)(y >> 2);
    ChannelAmplitudeTuningWorddata[1] = (uchar)(y << 6) & 0xC0;
    ChannelAmplitudeTuningWorddata[2] = 0x00;
    ChannelAmplitudeTuningWorddata[3] = 0x00;
}
// 6. 转换手动调幅控制字 (纯净重构版，彻底杜绝寄存器溢出)
void WrAmplitudeTuningWorddata1(double f, uchar *ChannelAmplitudeTuningWorddata, uchar *ASRAmplituteWordata)
{
    unsigned int y;

    // 先判断 double，再转换成无符号数，避免负数转换后变成大正数。
    if(f <= 0.0) y = 0U;
    else if(f >= 1023.0) y = 1023U;
    else y = (unsigned int)f;

    ASRAmplituteWordata[0] = ChannelAmplitudeTuningWorddata[0];

    // 屏蔽掉原始数据低两位 (保留 0x14，确保开启乘法器且严格关闭 RU/RD)
    ChannelAmplitudeTuningWorddata[1] = (ChannelAmplitudeTuningWorddata[1] & 0xfc);

    // 将 10 位幅度的最高两位 (bit9, bit8) 填入 Byte1 的最低两位
    ASRAmplituteWordata[1] = (ChannelAmplitudeTuningWorddata[1] | (uchar)(y >> 8));

    // 将 10 位幅度的低八位 (bit7~bit0) 填入 Byte2
    ASRAmplituteWordata[2] = (uchar)(y & 0xff);
}

/* ========================================================================
   ==================== 模拟赛道高频核心应用层接口 ====================
   ======================================================================== */

// 7. 通道选择函数：0/1/2/3 或 4(代表全选)
void AD9959_SelectChannel(uchar Channel)
{
    uchar csr_data[1];
    switch(Channel)
    {
        case 0:  csr_data[0] = 0x10; break; // 仅选通道0
        case 1:  csr_data[0] = 0x20; break; // 仅选通道1
        case 2:  csr_data[0] = 0x40; break; // 仅选通道2
        case 3:  csr_data[0] = 0x80; break; // 仅选通道3
        default: csr_data[0] = 0xF0; break; // 4或其它值代表全选
    }
    WriteToAD9959ViaSpi(CSR, 1, csr_data, 0);
}

// 8. 改变当前选定通道的输出频率
void AD9959_SetWaveFrequency(double f)
{
    uchar ChannelFrequencyTuningWord1data[4];

    WrFrequencyTuningWorddata(f, ChannelFrequencyTuningWord1data);

    WriteToAD9959ViaSpi(
        CFTW0,
        4,
        ChannelFrequencyTuningWord1data,
        1
    );
}

// 9. 改变当前选定通道的相位
void AD9959_SetWavePhase(double f, int p)
{
    uchar ChannelPhaseOffsetTuningWorddata[2];
    uchar ChannelFrequencyTuningWorddata[4];
    uchar ChannelFunctionRegisterdata[3] = {0x00, 0x23, 0x35}; // 正弦单频模式

    // ⚠️ 注意：这里已经彻底删除了往 FR1 写数据的代码，防止破坏 PLL 锁相环！

    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0); // 1. 写入通道模式

    WrPhaseOffsetTuningWorddata(p, ChannelPhaseOffsetTuningWorddata);
    WriteToAD9959ViaSpi(CPOW0, 2, ChannelPhaseOffsetTuningWorddata, 0); // 2. 写入相位控制字

    WrFrequencyTuningWorddata(f, ChannelFrequencyTuningWorddata);
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 1); // 3. 写入频率控制字，并触发更新
}

// 10. 改变当前选定通道的幅度大小
void AD9959_SetWaveAmplitude(double f, int a)
{
    uchar ChannelFrequencyTuningWorddata[4];
    uchar ASRAmplituteWordata[3];
    uchar AmplitudeControldata[3] = {0xff, 0x17, 0xff}; // 手动乘法器模式调幅
    uchar ChannelFunctionRegisterdata[3] = {0x00, 0x23, 0x35};

    // ⚠️ 注意：同样彻底删除了写 FR1 的代码

    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0);
    WrAmplitudeTuningWorddata1(a, AmplitudeControldata, ASRAmplituteWordata);
    WriteToAD9959ViaSpi(ACR, 3, ASRAmplituteWordata, 0);
    WrFrequencyTuningWorddata(f, ChannelFrequencyTuningWorddata);
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 1);
}

void AD9959_SetPhaseDifference_Any(uchar ch_base, uchar ch_offset, double freq, double phase_diff)
{
    uchar ChannelPhaseOffsetTuningWorddata_base[2];
    uchar ChannelPhaseOffsetTuningWorddata_offset[2];
    uchar ChannelFrequencyTuningWorddata[4];

    // 灵魂指令：开启自动清零相位累加器 (0x23)
    uchar ChannelFunctionRegisterdata[3] = {0x00, 0x23, 0x35};

    // 1. 提前算好频率控制字 (两路同频)
    WrFrequencyTuningWorddata(freq, ChannelFrequencyTuningWorddata);

    // 2. 分别计算两个通道的相位控制字
    WrPhaseOffsetTuningWorddata(0, ChannelPhaseOffsetTuningWorddata_base);          // 基准通道设为 0°
    WrPhaseOffsetTuningWorddata(phase_diff, ChannelPhaseOffsetTuningWorddata_offset); // 偏移通道设为目标角度

    // ================= 潜伏期：悄悄配置基准通道 =================
    AD9959_SelectChannel(ch_base);
    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0);
    WriteToAD9959ViaSpi(CPOW0, 2, ChannelPhaseOffsetTuningWorddata_base, 0);
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 0);

    // ================= 潜伏期：悄悄配置偏移通道 =================
    AD9959_SelectChannel(ch_offset);
    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0);
    WriteToAD9959ViaSpi(CPOW0, 2, ChannelPhaseOffsetTuningWorddata_offset, 0);
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 0);

    // ================= 爆发期：一键全军出击！ =================
    // 同一个时钟边沿，两个通道的跑表同时清零起跑，相位差瞬间锁死！
    IO_update();
}

void AD9959_SetChannelFrequency(uchar channel, double freq)
{
    uchar ChannelFrequencyTuningWorddata[4];
    uchar ChannelFunctionRegisterdata[3] = {0x00, 0x23, 0x35}; // 正弦单频波模式

    // 1. 算出目标频率的 32 位机器码
    WrFrequencyTuningWorddata(freq, ChannelFrequencyTuningWorddata);

    // 2. 切换到指定的通道 (关闭其他通道的指令接收大门)
    AD9959_SelectChannel(channel);

    // 3. 写入通道工作模式 (temp=0，暂不触发更新)
    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0);

    // 4. 写入频率控制字，并在这一步触发 IO_update (temp=1) 生效！
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 1);
}


void AD9959_SetChannelFreqAndAmp(uchar channel, double freq, int amp)
{
    uchar ChannelFrequencyTuningWorddata[4];
    uchar ASRAmplituteWordata[3];

    // ACR底层控制字 (0x17 包含了开启内部幅度乘法器的硬件指令)
    uchar AmplitudeControldata[3] = {0xff, 0x17, 0xff};
    // CFR底层控制字 (正弦波模式)
    uchar ChannelFunctionRegisterdata[3] = {0x00, 0x23, 0x35};

    // 1. 算好目标频率和幅度的 32 位/10 位机器码
    WrFrequencyTuningWorddata(freq, ChannelFrequencyTuningWorddata);
    WrAmplitudeTuningWorddata1(amp, AmplitudeControldata, ASRAmplituteWordata);

    // 2. 切换到指定的通道 (关闭其他通道的指令接收大门)
    AD9959_SelectChannel(channel);

    // 3. 依次写入配置 (temp全部设为 0，写进影子寄存器，暂不触发更新)
    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0); // 写入通道模式
    WriteToAD9959ViaSpi(ACR, 3, ASRAmplituteWordata, 0);         // 写入幅度数据

    // 4. 写入频率控制字，并在这一步触发 IO_update (temp=1) 生效！
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 1);
}

/**
  * @brief  【电赛专供】多径传输信号模拟函数 (直达信号 vs 多径信号)
  * @note   直接输入物理题目的要求参数：频率、纳秒时延、dB衰减，内部自动计算并双路完美同步输出！
  * @param  ch_direct:    直达信号通道号 (0~3)，作为 0° 和 0dB 的绝对基准
  * @param  ch_multipath: 多径信号通道号 (0~3)，相对于直达信号产生时延和衰减
  * @param  freq:         两路共用的载波频率 (Hz)
  * @param  delay_ns:     多径信号的时延 (单位：纳秒 ns，例如输入 50.0 代表 50ns)
  * @param  atten_db:     多径信号的幅度衰减 (单位：分贝 dB，例如输入 2.0 代表衰减 2dB)
  * @retval 无
  */
void AD9959_SetMultipathSignal(uchar ch_direct, uchar ch_multipath, double freq, double delay_ns, double atten_db)
{
    uchar ChannelPhaseOffsetTuningWorddata_direct[2];
    uchar ChannelPhaseOffsetTuningWorddata_multipath[2];
    uchar ChannelFrequencyTuningWorddata[4];
    uchar ASRAmplituteWordata_direct[3];
    uchar ASRAmplituteWordata_multipath[3];

    // 底层控制字
    uchar ChannelFunctionRegisterdata[3] = {0x00, 0x23, 0x35}; // 开启相位自动清零
    uchar AmplitudeControldata[3] = {0xff, 0x17, 0xff};        // 开启乘法器

    // ================== 1. 数学大脑：时延转相位 ==================
    // 公式: 相位差 = 时延(秒) * 频率(Hz) * 360
    double phase_diff = (delay_ns * 1e-9) * freq * 360.0;

    // 安全防护：防止相位差超过 360 度溢出寄存器
    while(phase_diff >= 360.0) {
        phase_diff -= 360.0;
    }

    WrFrequencyTuningWorddata(freq, ChannelFrequencyTuningWorddata);
    WrPhaseOffsetTuningWorddata(0, ChannelPhaseOffsetTuningWorddata_direct);          // 直达信号 0度
    WrPhaseOffsetTuningWorddata(phase_diff, ChannelPhaseOffsetTuningWorddata_multipath); // 多径信号延迟相位

    // ================== 2. 数学大脑：dB衰减转幅度字 ==================
    // 直达信号不衰减，拉满 1023
    WrAmplitudeTuningWorddata1(1023, AmplitudeControldata, ASRAmplituteWordata_direct);

    // 多径信号根据 dB 公式计算线性衰减比例
    double amp_ratio = pow(10.0, -atten_db / 20.0);
    int amp_word = (int)(1023.0 * amp_ratio);

    // 安全限幅
    if(amp_word > 1023) amp_word = 1023;
    if(amp_word < 0) amp_word = 0;
    WrAmplitudeTuningWorddata1(amp_word, AmplitudeControldata, ASRAmplituteWordata_multipath);

    // ================= 3. 潜伏期：悄悄配置直达信号 =================
    AD9959_SelectChannel(ch_direct);
    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0);
    WriteToAD9959ViaSpi(ACR, 3, ASRAmplituteWordata_direct, 0);
    WriteToAD9959ViaSpi(CPOW0, 2, ChannelPhaseOffsetTuningWorddata_direct, 0);
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 0);

    // ================= 4. 潜伏期：悄悄配置多径信号 =================
    AD9959_SelectChannel(ch_multipath);
    WriteToAD9959ViaSpi(CFR, 3, ChannelFunctionRegisterdata, 0);
    WriteToAD9959ViaSpi(ACR, 3, ASRAmplituteWordata_multipath, 0);
    WriteToAD9959ViaSpi(CPOW0, 2, ChannelPhaseOffsetTuningWorddata_multipath, 0);
    WriteToAD9959ViaSpi(CFTW0, 4, ChannelFrequencyTuningWorddata, 0);

    // ================= 5. 爆发期：一键全军出击！ =================
    IO_update();
}
void AD9959_SoftwareSweep(uint8_t channel,
                          uint32_t start_hz,
                          uint32_t stop_hz,
                          uint32_t step_hz,
                          uint32_t dwell_us)
{
    uint32_t freq;

    if (channel > 3U ||
        start_hz > stop_hz ||
        step_hz == 0U)
    {
        return;
    }

    /* 只在开始时选择一次通道并配置单频模式 */
    AD9959_SetChannelFrequency(channel, (double)start_hz);

    for (freq = start_hz; freq <= stop_hz; freq += step_hz)
    {
        /* 后续每个频点只更新 CFTW0 */
        AD9959_SetWaveFrequency((double)freq);

        AD9959_DelayUs(dwell_us);

        /* 防止无符号加法越界 */
        if ((stop_hz - freq) < step_hz)
        {
            break;
        }
    }
}
/* ========================================================================
 *  电赛频谱仪专用降频扫描
 *  扫描范围：10.691 MHz -> 10.100 MHz
 *  扫描步进：500 Hz
 * ======================================================================== */

#define AD9959_SWEEP_START_HZ       10691000UL
#define AD9959_SWEEP_STOP_HZ        10100000UL
#define AD9959_SWEEP_STEP_HZ        500UL

#define AD9959_SWEEP_POINT_COUNT    \
    (((AD9959_SWEEP_START_HZ - AD9959_SWEEP_STOP_HZ) / \
       AD9959_SWEEP_STEP_HZ) + 1UL)

/**
  * @brief  AD9959专用500Hz步进降频扫描
  * @param  channel  AD9959输出通道，范围0~3
  * @param  dwell_us 每个频点更新后的停留时间，单位us
  * @retval 实际完成的扫频点数；参数错误时返回0
  *
  * @note
  * 扫描范围：
  *     10.691 MHz -> 10.100 MHz
  *
  * 对应输入频率：
  *     f_input = 10.700 MHz - f_LO
  *
  * 即约：
  *     9 kHz -> 600 kHz
  */
uint32_t AD9959_SweepDown_500Hz(uint8_t channel,
                               uint32_t dwell_us)
{
    uint32_t point_index;
    uint32_t frequency_hz;

    if (channel > 3U)
    {
        return 0U;
    }

    /*
     * 第一个频点通过完整接口配置：
     * 1. 选择通道
     * 2. 配置单频模式
     * 3. 设置为10.691 MHz
     */
    AD9959_SetChannelFrequency(channel,
                              (double)AD9959_SWEEP_START_HZ);

    /*
     * 第一个频点也需要保留稳定时间。
     * 后续加入ADC采样时，第一个采样点就在这里采集。
     */
    if (dwell_us > 0U)
    {
        AD9959_DelayUs(dwell_us);
    }

    /*
     * point_index从1开始，因为第0点10.691 MHz已经设置完成。
     *
     * 每个后续频点只写CFTW0寄存器，不再重复选择通道、
     * 不再重复配置CFR，从而显著缩短扫描时间。
     */
    for (point_index = 1U;
         point_index < AD9959_SWEEP_POINT_COUNT;
         point_index++)
    {
        frequency_hz =
            AD9959_SWEEP_START_HZ -
            point_index * AD9959_SWEEP_STEP_HZ;

        AD9959_SetWaveFrequency((double)frequency_hz);

        if (dwell_us > 0U)
        {
            AD9959_DelayUs(dwell_us);
        }
    }

    return AD9959_SWEEP_POINT_COUNT;
}
