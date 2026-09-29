#ifndef __FPGA_UART_H_
#define __FPGA_UART_H_

#include "main.h"

#include <stdbool.h>
#include <stdint.h>

#define FPGA_UART_FRAME_CMD_START       0x01U
#define FPGA_UART_FRAME_CMD_STOP        0x02U
#define FPGA_UART_FRAME_CMD_RESEND      0x03U
#define FPGA_UART_FRAME_ACK             0x10U
#define FPGA_UART_FRAME_MEASURE_RESULT  0x20U
#define FPGA_UART_FRAME_ERROR           0x7FU

#define FPGA_MAX_WAVE_POINTS            2048U
#define FPGA_MAX_SPECTRUM_POINTS        10000U
#define FPGA_MAX_COMPONENTS             3U

typedef struct
{
    uint8_t status;

    uint16_t wave_point_count;
    uint32_t sample_interval_ns;
    int16_t waveform_001mv[FPGA_MAX_WAVE_POINTS];

    uint16_t vpp_001mv;
    uint16_t vrms_001mv;

    uint16_t spectrum_point_count;
    uint32_t spectrum_start_frequency_hz;
    uint32_t spectrum_bin_spacing_hz;
    uint16_t spectrum_amplitude_001mv[FPGA_MAX_SPECTRUM_POINTS];

    uint8_t sequence;
    uint8_t valid;
} FPGA_MeasureResult_t;

typedef struct
{
    uint8_t component_count;
    uint32_t frequency_hz[FPGA_MAX_COMPONENTS];
    uint16_t amplitude_001mv[FPGA_MAX_COMPONENTS];
} FPGA_SpectrumFeatures_t;

typedef struct
{
    uint32_t valid_frames;
    uint32_t crc_errors;
    uint32_t length_errors;
    uint32_t format_errors;
    uint32_t sequence_errors;
    uint32_t dropped_frames;
    uint32_t uart_errors;
    uint32_t parser_timeouts;
} FPGA_UART_Stats_t;

typedef struct
{
    uint32_t snapshot_counter;
    uint8_t expected_sequence;
    uint8_t waiting_for_result;
    uint8_t last_result_sequence;
    uint8_t last_ack_hal_status;
} FPGA_UART_DebugState_t;

/*
 * Debug-only observation points. They expose the exact accepted measurement
 * already stored by the protocol parser, without copying the large arrays or
 * using USART1/USART2 for logging.
 */
extern FPGA_MeasureResult_t g_fpga_debug_measurement;
extern FPGA_UART_Stats_t g_fpga_debug_stats;
extern volatile FPGA_UART_DebugState_t g_fpga_debug_state;

HAL_StatusTypeDef FPGA_UART_Init(void);
void FPGA_UART_Process(void);

HAL_StatusTypeDef FPGA_UART_RequestMeasurement(uint8_t mode);
HAL_StatusTypeDef FPGA_UART_SendStop(void);

bool FPGA_UART_HasNewMeasurement(void);
const FPGA_MeasureResult_t *FPGA_UART_GetMeasurement(void);
void FPGA_UART_ClearNewMeasurement(void);
const FPGA_UART_Stats_t *FPGA_UART_GetStats(void);

bool FPGA_UART_ExtractSpectrumFeatures(
    const FPGA_MeasureResult_t *measurement,
    FPGA_SpectrumFeatures_t *features);

void FPGA_UART_HandleError(UART_HandleTypeDef *huart);
uint16_t FPGA_UART_CRC16_CCITT_FALSE(const uint8_t *data, uint16_t length);

/*
 * Set a debugger breakpoint here. It is called only after a complete result
 * has been parsed and the ACK transmission attempt has finished.
 */
void FPGA_UART_DebugMeasurementReadyHook(void);

#endif /* __FPGA_UART_H_ */
