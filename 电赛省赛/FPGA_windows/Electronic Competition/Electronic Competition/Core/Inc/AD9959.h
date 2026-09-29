#ifndef __AD9959_H
#define __AD9959_H

#include "main.h"

#define uchar unsigned char
#define uint  unsigned int

// ----- 引脚映射定义（可根据实物连线任意修改） -----
#define SCLK_PORT        GPIOD
#define SCLK_PIN         GPIO_PIN_4
#define CS_PORT          GPIOD
#define CS_PIN           GPIO_PIN_5
#define IO_UPDATE_PORT   GPIOD
#define IO_UPDATE_PIN    GPIO_PIN_6
#define SDIO0_PORT       GPIOD
#define SDIO0_PIN        GPIO_PIN_7

#define PS0_PORT         GPIOD
#define PS0_PIN          GPIO_PIN_0
#define PS1_PORT         GPIOD
#define PS1_PIN          GPIO_PIN_1
#define PS2_PORT         GPIOD
#define PS2_PIN          GPIO_PIN_2
#define PS3_PORT         GPIOD
#define PS3_PIN          GPIO_PIN_3

#define SDIO1_PORT       GPIOG
#define SDIO1_PIN        GPIO_PIN_9
#define SDIO2_PORT       GPIOG
#define SDIO2_PIN        GPIO_PIN_10
#define SDIO3_PORT       GPIOG
#define SDIO3_PIN        GPIO_PIN_11
#define PWR_PORT         GPIOG
#define PWR_PIN          GPIO_PIN_12
#define RESET_PORT       GPIOG
#define RESET_PIN        GPIO_PIN_13

// ----- HAL库引脚电平操作宏 -----
#define SCLK_1()        HAL_GPIO_WritePin(SCLK_PORT, SCLK_PIN, GPIO_PIN_SET)
#define SCLK_0()        HAL_GPIO_WritePin(SCLK_PORT, SCLK_PIN, GPIO_PIN_RESET)
#define CS_1()          HAL_GPIO_WritePin(CS_PORT, CS_PIN, GPIO_PIN_SET)
#define CS_0()          HAL_GPIO_WritePin(CS_PORT, CS_PIN, GPIO_PIN_RESET)
#define IO_UPDATE_1()   HAL_GPIO_WritePin(IO_UPDATE_PORT, IO_UPDATE_PIN, GPIO_PIN_SET)
#define IO_UPDATE_0()   HAL_GPIO_WritePin(IO_UPDATE_PORT, IO_UPDATE_PIN, GPIO_PIN_RESET)
#define SDIO0_1()       HAL_GPIO_WritePin(SDIO0_PORT, SDIO0_PIN, GPIO_PIN_SET)
#define SDIO0_0()       HAL_GPIO_WritePin(SDIO0_PORT, SDIO0_PIN, GPIO_PIN_RESET)

#define PS0_1()         HAL_GPIO_WritePin(PS0_PORT, PS0_PIN, GPIO_PIN_SET)
#define PS0_0()         HAL_GPIO_WritePin(PS0_PORT, PS0_PIN, GPIO_PIN_RESET)
#define PS1_1()         HAL_GPIO_WritePin(PS1_PORT, PS1_PIN, GPIO_PIN_SET)
#define PS1_0()         HAL_GPIO_WritePin(PS1_PORT, PS1_PIN, GPIO_PIN_RESET)
#define PS2_1()         HAL_GPIO_WritePin(PS2_PORT, PS2_PIN, GPIO_PIN_SET)
#define PS2_0()         HAL_GPIO_WritePin(PS2_PORT, PS2_PIN, GPIO_PIN_RESET)
#define PS3_1()         HAL_GPIO_WritePin(PS3_PORT, PS3_PIN, GPIO_PIN_SET)
#define PS3_0()         HAL_GPIO_WritePin(PS3_PORT, PS3_PIN, GPIO_PIN_RESET)

#define PWR_1()         HAL_GPIO_WritePin(PWR_PORT, PWR_PIN, GPIO_PIN_SET)
#define PWR_0()         HAL_GPIO_WritePin(PWR_PORT, PWR_PIN, GPIO_PIN_RESET)
#define RESET_1()       HAL_GPIO_WritePin(RESET_PORT, RESET_PIN, GPIO_PIN_SET)
#define RESET_0()       HAL_GPIO_WritePin(RESET_PORT, RESET_PIN, GPIO_PIN_RESET)

// ----- 寄存器地址宏定义 -----
#define CSR   0x00
#define FR1   0x01
#define FR2   0x02
#define CFR   0x03
#define CFTW0 0x04
#define CPOW0 0x05
#define ACR   0x06
#define SRR   0x07
#define RDW   0x08
#define FDW   0x09

// ----- 底层函数声明 -----
//@brief  系统唤醒与初始化 (底层基石)
//@note   拉低所有引脚防干扰，执行硬件硬复位，并让内部 PLL 锁相环倍频至 500MHz。
//必须在 main 函数里的 MX_GPIO_Init() 之后调用！
void AD9959_Init(void);

//@brief  触发数据同步更新 (一键发射扳机)
//@note   给硬件 IO_UPDATE 引脚发送极短的上升沿脉冲，让之前写进“影子寄存器”的数据瞬间生效。
void IO_update(void);
void AD9959_DelayUs(uint32_t us);
void WriteToAD9959ViaSpi(uchar RegisterAddress, uchar NumberofRegisters, uchar *RegisterData, uchar temp);
void WrFrequencyTuningWorddata(double f, uchar *ChannelFrequencyTuningWorddata);
void WrPhaseOffsetTuningWorddata(double f, uchar *ChannelPhaseOffsetTuningWorddata);
void WrAmplitudeTuningWorddata(double f, uchar *ChannelAmplitudeTuningWorddata);
void WrAmplitudeTuningWorddata1(double f, uchar *ChannelAmplitudeTuningWorddata, uchar *ASRAmplituteWordata);

// ----- 模拟赛道核心应用层函数声明 -----
/**
  * @brief  通道选择开关 (决定接下来的指令发给谁);改变内部 CSR 寄存器，决定后续数据的流向。
  * @param  Channel: 通道号。0~3 分别对应 IOUT0~3。传入 4 代表全选 (后续指令四个通道一起生效)。
  */
void AD9959_SelectChannel(uchar Channel);

/**
  * @brief  单频正弦波输出 (最基础的起步函数);让当前选中的通道输出指定频率的正弦波，自动触发波形更新。
  * @param  f: 目标频率，浮点数，单位为 Hz (如输入 30000000.0 代表 30MHz)。
  */
void AD9959_SetWaveFrequency(double f);

/**
  * @brief  带相位的单频正弦波输出;在设定频率的同时，指定波形的初始起跑相位。
  * @param  f: 目标频率 (Hz);p: 初始相位，整数，范围 0 ~ 360 度
  */
void AD9959_SetWavePhase(double f, int p);

/**
  * @brief  定频调幅正弦波输出 (解决高频衰减的利器);可在设定频率的同时，控制输出波形的峰峰值，用于电赛高频平坦度补偿。
  * @param  f: 目标频率 (Hz);a: 幅度控制字，整数，范围 0 ~ 1023 (1023为满幅输出)。
  */
void AD9959_SetWaveAmplitude(double f, int a);

/**
  * @brief  【完全体】任意双通道、任意相位差正交同步输出;利用影子寄存器和相位累加器清零机制，实现任意两个通道的纳秒级相位同步。
  * @param  ch_base:基准通道 (0~3)，其绝对相位将被设为 0° 作为参考;ch_offset: 偏移通道 (0~3)，其绝对相位将被设为 phase_diff
  * @param  freq:两路共用的输出频率 (Hz)phase_diff:偏移通道相对于基准通道的相位差 (0~360度)
  */
void AD9959_SetPhaseDifference_Any(uchar ch_base, uchar ch_offset, double freq, double phase_diff);

/**
  * @brief  任意单通道独立变频函数 (指哪打哪);指定任意通道输出特定频率，且绝对不会干扰其他正在运行的通道。
  * @param  channel: 目标通道号 (0~3);freq:    目标输出频率 (Hz)
  */
void AD9959_SetChannelFrequency(uchar channel, double freq);

/**
  * @brief  任意单通道独立变频调幅函数 (指哪打哪，全能版);指定任意通道输出特定频率和幅度，绝对不干扰其他通道。 非常适合用于扫频时的“全频段幅度平坦度软件补偿”。
  * @param  channel: 目标通道号 (0~3)  famreq:目标输出频率 (Hz)  amp:目标幅度控制字 (0~1023，1023为满幅度输出，512为一半)
  */
void AD9959_SetChannelFreqAndAmp(uchar channel, double freq, int amp);

/**
  * @brief  【电赛专供】多径传输信号模拟函数 (直达信号 vs 多径信号);直接输入物理题目的要求参数：频率、纳秒时延、dB衰减，内部自动计算并双路完美同步输出！
  * @param  ch_direct:直达信号通道号 (0~3)，作为 0° 和 0dB 的绝对基准;  ch_multipath: 多径信号通道号 (0~3)，相对于直达信号产生时延和衰减;    freq:两路共用的载波频率 (Hz)
  * @param  delay_ns:多径信号的时延 (单位：纳秒 ns，例如输入 50.0 代表 50ns)   atten_db:多径信号的幅度衰减 (单位：分贝 dB，例如输入 2.0 代表衰减 2dB)
  */
void AD9959_SetMultipathSignal(uchar ch_direct, uchar ch_multipath, double freq, double delay_ns, double atten_db);

/**
 * @brief 软件步进扫频：控制指定AD9959通道从start_hz扫描到stop_hz，每次增加step_hz，并在每个频点停留dwell_us微秒。
 * @param channel  AD9959通道号，取值0～3，分别对应CH0～CH3。
 * @param start_hz 扫频起始频率，单位Hz，例如10100000表示10.1MHz。
 * @param stop_hz  扫频终止频率，单位Hz，例如10700000表示10.7MHz。
 * @param step_hz  扫频步进，单位Hz，例如500表示每次增加500Hz，不能为0。
 * @param dwell_us 每个频点的额外停留时间，单位μs；实际单点时间还包括DDS寄存器更新时间。
 * @note 使用前必须调用AD9959_Init()；本函数为阻塞式执行，扫频期间CPU不会返回主循环。
 */
void AD9959_SoftwareSweep(uint8_t channel, uint32_t start_hz, uint32_t stop_hz, uint32_t step_hz, uint32_t dwell_us);

/* 10.691 MHz -> 10.100 MHz，500 Hz步进降频扫描 */
uint32_t AD9959_SweepDown_500Hz(uint8_t channel,
                               uint32_t dwell_us);
#endif
