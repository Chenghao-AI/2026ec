/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "adc.h"
#include "i2c.h"
#include "tim.h"
#include "usart.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "FPGA_UART.h"
#include "TJC_SCREEN.h"
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "stdint.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
typedef enum
{
  DISPLAY_TARGET_NONE = 0,
  DISPLAY_TARGET_TIME,
  DISPLAY_TARGET_FREQUENCY
} DisplayTarget_t;
/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define FPGA_MEASUREMENT_MODE              0x01U
#define FPGA_MEASUREMENT_REQUEST_TIMEOUT_MS 3000U
#define TIME_WAVEFORM_DC_OFFSET_MV         19.0f
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */
uint8_t g_usart1_rx_byte = 0U;
uint8_t g_current_symbol = 0U;
uint8_t g_tjc_touch_command = 0U;
FPGA_SpectrumFeatures_t g_fpga_spectrum_features;
volatile uint8_t g_fpga_spectrum_features_ready = 0U;
static TJC_FrequencyPoint g_fpga_frequency_display[
    FPGA_MAX_COMPONENTS];
static TJC_TimePoint g_fpga_time_display[FPGA_MAX_WAVE_POINTS];
static DisplayTarget_t g_display_target = DISPLAY_TARGET_NONE;
static uint8_t g_measurement_pending = 0U;
static uint32_t g_measurement_request_tick = 0U;
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
static void App_StartMeasurement(DisplayTarget_t target)
{
    if ((target == DISPLAY_TARGET_NONE)
        || (g_measurement_pending != 0U)) {
        return;
    }

    if (FPGA_UART_RequestMeasurement(FPGA_MEASUREMENT_MODE) == HAL_OK) {
        g_display_target = target;
        g_measurement_pending = 1U;
        g_measurement_request_tick = HAL_GetTick();
        g_fpga_spectrum_features_ready = 0U;
    }
}

static void App_StopDisplay(void)
{
    /*
     * Do not stop USART2 or the FPGA measurement engine.  If a result is
     * already in flight, it is still received and ACKed, but it is not drawn.
     */
    g_display_target = DISPLAY_TARGET_NONE;
}

static void App_HandleTouchCommand(uint8_t command)
{
    switch (command) {
    case TJC_TOUCH_CMD_TIME_START:
        App_StartMeasurement(DISPLAY_TARGET_TIME);
        break;

    case TJC_TOUCH_CMD_TIME_STOP:
    case TJC_TOUCH_CMD_FREQ_STOP:
        App_StopDisplay();
        break;

    case TJC_TOUCH_CMD_TIME_TOGGLE:
        (void)TJC_ToggleTimeDisplayCycles();
        break;

    case TJC_TOUCH_CMD_FREQ_START:
        App_StartMeasurement(DISPLAY_TARGET_FREQUENCY);
        break;

    default:
        break;
    }
}

static void App_FinishMeasurement(
    const FPGA_MeasureResult_t *measurement)
{
    HAL_StatusTypeDef display_status;
    uint16_t point_index;
    uint8_t component_index;

    if ((measurement == NULL) || (g_measurement_pending == 0U)) {
        g_measurement_pending = 0U;
        g_display_target = DISPLAY_TARGET_NONE;
        return;
    }

    if (g_display_target == DISPLAY_TARGET_NONE) {
        g_measurement_pending = 0U;
        return;
    }

    if (!FPGA_UART_ExtractSpectrumFeatures(
            measurement, &g_fpga_spectrum_features)) {
        g_measurement_pending = 0U;
        g_display_target = DISPLAY_TARGET_NONE;
        return;
    }

    g_fpga_spectrum_features_ready = 1U;

    if (g_display_target == DISPLAY_TARGET_TIME) {
        for (point_index = 0U;
             point_index < measurement->wave_point_count;
             ++point_index) {
            g_fpga_time_display[point_index].time_ms =
                ((float)point_index
                 * (float)measurement->sample_interval_ns)
                / 1000000.0f;
            g_fpga_time_display[point_index].voltage_mv =
                (float)measurement->waveform_001mv[point_index]
                * 0.01f
                - TIME_WAVEFORM_DC_OFFSET_MV;
        }

        display_status = TJC_UpdateTimeDomain(
            g_fpga_time_display,
            measurement->wave_point_count,
            0.0f,
            (float)measurement->vpp_001mv * 0.01f,
            (float)measurement->vrms_001mv * 0.01f,
            (float)g_fpga_spectrum_features.frequency_hz[0]);
        if (display_status != HAL_OK) {
            HAL_Delay(10U);
            (void)TJC_UpdateTimeDomain(
                g_fpga_time_display,
                measurement->wave_point_count,
                0.0f,
                (float)measurement->vpp_001mv * 0.01f,
                (float)measurement->vrms_001mv * 0.01f,
                (float)g_fpga_spectrum_features.frequency_hz[0]);
        }
    } else if (g_display_target == DISPLAY_TARGET_FREQUENCY) {
        for (component_index = 0U;
             component_index
                 < g_fpga_spectrum_features.component_count;
             ++component_index) {
            g_fpga_frequency_display[component_index].frequency_khz =
                (float)g_fpga_spectrum_features
                    .frequency_hz[component_index] / 1000.0f;
            g_fpga_frequency_display[component_index].amplitude_mv =
                (float)g_fpga_spectrum_features
                    .amplitude_001mv[component_index] * 0.01f;
        }

        display_status = TJC_UpdateFrequencyDomain(
            g_fpga_frequency_display,
            g_fpga_spectrum_features.component_count,
            500.0f,
            300.0f);
        if (display_status != HAL_OK) {
            HAL_Delay(10U);
            (void)TJC_UpdateFrequencyDomain(
                g_fpga_frequency_display,
                g_fpga_spectrum_features.component_count,
                500.0f,
                300.0f);
        }
    }

    /*
     * One START corresponds to exactly one accepted result and one screen
     * update.  A later refresh requires the user to press Start again.
     */
    g_measurement_pending = 0U;
    g_display_target = DISPLAY_TARGET_NONE;
}

void LTC1069_SetClock(uint32_t target_clk_hz)
{
    // 增加安全防护：限制频率在合理范围内 (例如：3kHz 到 2MHz 时钟)
    // 防止除以 0 或超出定时器 16位 寄存器上限
    if(target_clk_hz < 3000 || target_clk_hz > 2000000) return;

    // STM32F407 APB2 定时器时钟为 168MHz
    // 计算需要的总分频周期数 (ARR + 1)
    uint32_t period_ticks = 168000000 / target_clk_hz;

    // 计算实际的 ARR 和 CCR 值 (Pulse)
    uint32_t arr_val = period_ticks - 1;
    uint32_t ccr_val = period_ticks / 2; // 严格平分，保证 50% 占空比

    // 动态更新寄存器
    __HAL_TIM_SET_AUTORELOAD(&htim1, arr_val);
    __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, ccr_val);

    // 手动触发一次更新事件，让影子寄存器的值立即生效
    // 防止由于 ARR 突变导致当前 PWM 周期输出畸变
    htim1.Instance->EGR = TIM_EGR_UG;
}
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_I2C1_Init();
  MX_TIM1_Init();
  MX_USART1_UART_Init();
  MX_ADC1_Init();
  MX_USART2_UART_Init();
  /* USER CODE BEGIN 2 */
  if (TJC_Init() != HAL_OK)
  {
      Error_Handler();
  }

  if (FPGA_UART_Init() != HAL_OK)
  {
      Error_Handler();
  }

  /* Wait for the serial screen to finish booting. */
  HAL_Delay(1000);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    const FPGA_MeasureResult_t *measurement;

    FPGA_UART_Process();

    if (FPGA_UART_HasNewMeasurement())
    {
      measurement = FPGA_UART_GetMeasurement();
      App_FinishMeasurement(measurement);
      FPGA_UART_ClearNewMeasurement();
    }

    if (TJC_GetTouchCommand(&g_tjc_touch_command)) {
      App_HandleTouchCommand(g_tjc_touch_command);
    }

    if ((g_measurement_pending != 0U)
        && ((HAL_GetTick() - g_measurement_request_tick)
            >= FPGA_MEASUREMENT_REQUEST_TIMEOUT_MS)) {
      /*
       * Release the UI after a missing result. USART2 remains active, so a
       * late frame can still be parsed and ACKed without refreshing the page.
       */
      g_measurement_pending = 0U;
      g_display_target = DISPLAY_TARGET_NONE;
    }

    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLM = 8;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
  RCC_OscInitStruct.PLL.PLLQ = 4;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_5) != HAL_OK)
  {
    Error_Handler();
  }
}

/* USER CODE BEGIN 4 */
/**
 * @brief 串口接收完成中断回调
 */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART1)
    {
        // 物理 Debug 指示：收到串口屏数据翻转状态 LED
        HAL_GPIO_TogglePin(GPIOF, GPIO_PIN_9);

        // 传入状态机解析
        TJC_UART_RxCpltCallback(g_usart1_rx_byte);

        // 重新挂起中断接收
        HAL_UART_Receive_IT(&huart1, &g_usart1_rx_byte, 1);
    }
}

/**
 * @brief 串口错误回调（彻底解锁 ORE 卡死问题）
 */
void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART1)
    {
        __HAL_UART_CLEAR_OREFLAG(huart);
        __HAL_UART_CLEAR_NEFLAG(huart);
        __HAL_UART_CLEAR_FEFLAG(huart);

        // 重置 HAL 库内部状态码，防止中断挂起失败
        huart->ErrorCode = HAL_UART_ERROR_NONE;
        huart->RxState = HAL_UART_STATE_READY;

        HAL_UART_Receive_IT(&huart1, &g_usart1_rx_byte, 1);
    }
    else if (huart->Instance == USART2)
    {
        FPGA_UART_HandleError(huart);
    }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
