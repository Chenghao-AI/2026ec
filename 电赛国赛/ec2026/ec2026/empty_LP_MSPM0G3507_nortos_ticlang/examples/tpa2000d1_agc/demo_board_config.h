/*
 * TPA2000D1 综合示例：把 SysConfig 生成的名字映射到示例硬件适配层。
 *
 * 默认保持 0，因此当前工程没有 ADC/DAC 配置时也能通过编译，并在 OLED 显示
 * "CFG"。完成 SYSCONFIG.md 后，把下面改为 1，并按生成头文件填写宏映射。
 */
#pragma once

#ifndef DEMO_AGC_HW_READY
#define DEMO_AGC_HW_READY 0
#endif

#if DEMO_AGC_HW_READY

#include "ti_msp_dl_config.h"

/* ADC12 + FIFO + DMA。推荐 SysConfig 实例名：ADC_AGC、DMA_ADC_AGC。 */
#define DEMO_AGC_ADC_INST                  ADC_AGC_INST
#define DEMO_AGC_ADC_DMA_TRIGGER           DL_ADC12_DMA_MEM10_RESULT_LOADED
#define DEMO_AGC_DMA_INST                  DMA
#define DEMO_AGC_DMA_CHANNEL               DMA_ADC_AGC_CHAN_ID
#define DEMO_AGC_DMA_COMPLETION_INTERRUPT  DL_DMA_INTERRUPT_CHANNEL0
#define DEMO_AGC_DMA_POLL_LIMIT            4000000U

/* 100 kHz 周期 Timer；推荐实例名 TIMER_ADC_TRIGGER。 */
#define DEMO_AGC_TIMER_INST                TIMER_ADC_TRIGGER_INST
#define DEMO_AGC_TIMER_CLOCK_HZ            1000000U
#define DEMO_AGC_TIMER_MAX_COUNTS          65536U

/* DAC12 输出到 PA15。推荐实例名 DAC_GAIN。 */
#define DEMO_AGC_DAC_INST                  DAC_GAIN_INST
#define DEMO_AGC_DAC_REFERENCE_LOW_MV      0U
#define DEMO_AGC_DAC_REFERENCE_HIGH_MV     3300U
#define DEMO_AGC_DAC_CALIBRATE_ON_INIT     1

/* TPA2000D1 SHUTDOWN：高电平正常工作，低电平关断。推荐 PA27。 */
#define DEMO_AGC_SHUTDOWN_PORT             GPIO_AGC_PORT
#define DEMO_AGC_SHUTDOWN_PIN              GPIO_AGC_AMP_SD_PIN

#endif

