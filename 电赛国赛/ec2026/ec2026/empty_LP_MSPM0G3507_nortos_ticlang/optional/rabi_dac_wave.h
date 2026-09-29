/* Rabi 备用模块：MSPM0 DAC12 FIFO + DMA 波表输出接口。 */
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <ti/driverlib/dl_dac12.h>
#include "core/rabi_err.h"
#include "optional/rabi_dma.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/*
 * DAC 波表输出
 * ============
 *
 * 让 DMA 把 uint16_t 12-bit 波表循环送入 DAC FIFO，CPU 不必逐点进中断。适合低频
 * 正弦/三角/锯齿、扫控制电压和任意测试激励。每个样本只使用低 12 bit，建议表值
 * 明确限制在 0~4095。
 *
 * 有两种节拍来源：
 *
 * 1. DAC 内置 Sample Time Generator：配置最省事，采样率只有固定档位；
 * 2. Timer ZERO -> Event Fabric -> DAC HWTRIG0：频率更灵活，也便于与 ADC 同步。
 *
 * 无论哪种方式：
 *
 *     output_frequency = sample_rate_hz / sample_count
 *
 * 例如 64 点正弦、64 kSPS 得到 1 kHz。提高点数会改善波形阶梯，却在同一采样率下
 * 降低最高输出频率；DAC 建立时间、运放带宽和重建低通也会限制实际波形质量。
 *
 * SysConfig：DAC 内置采样节拍
 * ----------------------------
 * 1. DAC12：12-bit Binary、Output Enable、Amplifier On、FIFO Enable；
 * 2. FIFO Trigger 选 Sample Time Generator，选择所需 Samples Per Second；
 * 3. DMA Trigger Enable，Threshold 建议 2/4 Empty；
 * 4. 从 DAC12 的 DMA 配置入口添加 DMA Full Channel：外部 DAC trigger、Repeat
 *    Single、Source Increment、Destination Unchanged、两侧 Half Word；
 * 5. cfg.use_sample_time_generator=true，sample_rate_hz 填所选实际 SPS。
 *
 * SysConfig：Timer Event 节拍
 * --------------------------
 * 1. DAC FIFO Trigger 改成 Hardware Trigger 0，Sample Time Generator Disable；
 * 2. 添加 Periodic Timer，并把 ZERO Event 发布到一个 Event Fabric channel；
 * 3. DAC Subscriber 0 订阅同一 channel；DMA 设置与上面相同；
 * 4. cfg.use_sample_time_generator=false，sample_rate_hz 填 Timer ZERO 频率；
 * 5. 先 rabi_dac_wave_start() 填好 FIFO/DMA，再启动 Timer，避免开头 underrun。
 *
 * 最小示例
 * --------
 *
 *     // 16 点近似正弦，仅作快速冒烟测试；比赛时可离线生成更长表。
 *     static const uint16_t s_sine16[] = {
 *         2048, 2831, 3496, 3940, 4095, 3940, 3496, 2831,
 *         2048, 1264,  599,  155,    0,  155,  599, 1264,
 *     };
 *
 *     static rabi_dac_wave_t s_wave;
 *     static const rabi_dac_wave_cfg_t s_wave_cfg = {
 *         .instance = DAC0,
 *         .dma = {
 *             .instance = DMA,
 *             .channel = DMA_DAC_CHAN_ID,
 *             .completion_interrupt = DL_DMA_INTERRUPT_CHANNEL0,
 *             .poll_limit = 100000U,
 *         },
 *         .sample_rate_hz = 16000U,
 *         .repeat = true,
 *         .use_sample_time_generator = true,
 *     };
 *
 *     rabi_dac_wave_init(&s_wave, &s_wave_cfg);
 *     rabi_dac_wave_start(&s_wave, s_sine16, 16U); // 输出约 1 kHz
 *
 * 波形幅值和偏置
 * --------------
 * 表中 0~4095 表示整个参考范围。若只需中心在 mid、峰值 amplitude_raw 的正弦，
 * 应离线生成并检查每点都满足 0 <= mid + wave <= 4095；超过范围必须限幅，否则
 * uint16_t 回绕会产生很大的尖峰。DAC 本身只能输出参考范围内的单极性电压，双极性
 * 和更大幅值要靠后级运放完成。
 *
 * 使用边界
 * --------
 * - 波表必须是静态/全局或在 stop 前始终有效，不能传即将退出的栈数组；
 * - repeat=true 需要 DMA Full Channel；并非所有通道都支持相同 Repeat 能力；
 * - 非循环传输结束后应尽快 stop，继续触发会产生 FIFO underrun；
 * - 本模块不同时管理触发 Timer。硬件事件模式由业务层最后启动、最先停止 Timer；
 * - 切换波表时先 stop 再 start，不要在 DMA 正读数组时原地改整张表；
 * - DAC 波表适合较低频任意波。更高频、频率分辨率更重要的正弦仍优先 AD9850/DDS。
 */

typedef struct
{
    DAC12_Regs *instance;
    rabi_dma_t dma;
    uint32_t sample_rate_hz;
    bool repeat;
    bool use_sample_time_generator;
} rabi_dac_wave_cfg_t;

typedef struct
{
    rabi_dac_wave_cfg_t cfg;
    const uint16_t *samples;
    size_t sample_count;
    bool running;
    bool initialized;
} rabi_dac_wave_t;

rabi_err_t rabi_dac_wave_init(
    rabi_dac_wave_t *wave, const rabi_dac_wave_cfg_t *cfg);

rabi_err_t rabi_dac_wave_start(
    rabi_dac_wave_t *wave,
    const uint16_t *samples,
    size_t sample_count);

rabi_err_t rabi_dac_wave_stop(rabi_dac_wave_t *wave);

/* 非循环 DMA 已搬完波表时返回 true；repeat 模式始终返回 false。 */
bool rabi_dac_wave_is_complete(const rabi_dac_wave_t *wave);

/* 按 cfg.sample_rate_hz 和当前 sample_count 计算理想输出频率。 */
uint32_t rabi_dac_wave_get_frequency_millihz(
    const rabi_dac_wave_t *wave);

#if defined(__cplusplus)
}
#endif
