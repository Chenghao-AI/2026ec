/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body - spectrum analyser, dual-mode
  *
  *          === MODE SELECTION (g_spectrum_mode, recompile & flash) ===
  *
  *            g_spectrum_mode = 0 -> Single Frequency
  *              - Only g_target_freq_MHz shows pulse power
  *              - Front-end pre-filtered, other freqs = noise floor (-60 dBm)
  *              - Power pulse: 0 -> peak -> 0 -> bounce -> 0 (fast)
  *              - Title: "Spectrum Analyzer"
  *              - Bottom bar (flat): Left=Freq(MHz), Right=Power(dBm)
  *              - X-axis shows target frequency value
  *
  *            g_spectrum_mode = 1 -> Sweep Frequency
  *              - 80-100 MHz, 100 kHz step, 15 seconds total
  *              - Spectrum fills left-to-right as sweep progresses
  *              - Title: "sweep frequency"
  *              - After sweep: AM detection shows 5 values:
  *                fc, Pc, fs, Ps, ma (carrier freq/pwr, sideband freq/pwr,
  *                modulation index). If no sideband: fs=0, Ps=0, ma=0
  *
  *          === FREQUENCY CONFIG (Mode 0 only) ===
  *
  *            g_target_freq_MHz sets target frequency, range 80.00 - 100.00 MHz
  *
  *          === DATA SOURCE TOGGLE ===
  *
  *            USE_REAL_SWEEP_DATA  0 = simulated sweep data (debug)
  *            USE_REAL_SWEEP_DATA  1 = real data via Spectrum_SweepSetData()
  *
  *          === EXAMPLES ===
  *            Ex 1 - 90 MHz single-freq pulse:
  *              volatile uint8_t g_spectrum_mode   = 0;
  *              volatile float   g_target_freq_MHz = 90.00f;
  *
  *            Ex 2 - Sweep + AM detection:
  *              volatile uint8_t g_spectrum_mode   = 1;
  *
  *            Ex 3 - Sweep with real external data:
  *              volatile uint8_t  g_spectrum_mode    = 1;
  *              #define USE_REAL_SWEEP_DATA  1
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "spi.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "lcd_st7796.h"
#include "spectrum_display.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */

/* ---- Mode Selection -------------------------------------------------------
 *
 *  g_spectrum_mode:
 *    0 = Single-freq (pulse power, title "Spectrum Analyzer")
 *    1 = Sweep  (80-100 MHz + AM, title "sweep frequency")
 *
 *  g_target_freq_MHz:
 *    Target frequency in single-freq mode (80.00 - 100.00 MHz)
 *    Ignored in sweep mode.
 *
 *  USE_REAL_SWEEP_DATA:
 *    0 = Simulated sweep data via sweep_generate_data() (debug)
 *    1 = Real external data via Spectrum_SweepSetData()
 *
 *  Runtime switching: modify volatile vars via debugger.
 * ------------------------------------------------------------------------ */
#define USE_REAL_SWEEP_DATA  0   /* 0=simulated sweep,  1=real external data */

volatile uint8_t g_spectrum_mode   = 1;       /* 0=single-freq,  1=sweep      */
volatile float   g_target_freq_MHz = 90.00f;  /* target freq for Mode 0 (MHz) */

/* ---- Real data placeholder (replace with your own module) -------------- */
#if USE_REAL_SWEEP_DATA
/* Example: include your detector header here */
/* #include "my_rf_detector.h" */

/*
 *  Call this to fill a 200-point array from your hardware.
 *  Replace the body with actual ADC / FFT / detector reads.
 */
static void external_fetch_sweep_data(spectrum_signal_t *buf, uint16_t count)
{
    uint16_t i;
    float f_step = (SWEEP_FREQ_END_MHZ - SWEEP_FREQ_START_MHZ)
                   / (float)(count - 1U);
    for (i = 0U; i < count; i++) {
        buf[i].freq_MHz  = SWEEP_FREQ_START_MHZ + (float)i * f_step;
        buf[i].power_dBm = SPECTRUM_Y_MIN_DBM;           /* <- replace with */
        /* buf[i].power_dBm = my_detector_read_dBm(i);      your real data  */
    }
}
#endif /* USE_REAL_SWEEP_DATA */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

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
  MX_SPI1_Init();
  /* USER CODE BEGIN 2 */

  /* Disable touch chip on shared SPI bus to avoid bus contention */
  HAL_GPIO_WritePin(CS2_GPIO_Port, CS2_Pin, GPIO_PIN_SET);

  /* Turn off backlight during init to avoid flicker */
  HAL_GPIO_WritePin(BLK_GPIO_Port, BLK_Pin, GPIO_PIN_RESET);

  /* Initialise the ST7796 in landscape mode (480x320) */
  ST7796_Init();

  /* ---- Per-mode initialisation ---- */
  if (g_spectrum_mode == SPECTRUM_MODE_SWEEP) {
#if USE_REAL_SWEEP_DATA
      /* ---- Real data path ---- */
      spectrum_signal_t init_data[SPECTRUM_MAX_POINTS];
      external_fetch_sweep_data(init_data, SPECTRUM_MAX_POINTS);
      Spectrum_SweepSetData(init_data, SPECTRUM_MAX_POINTS);
#else
      /* ---- Simulated data path ---- */
      Spectrum_SweepInit();
#endif
  }

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */

    /* Read mode each frame to support runtime switching via debugger */
    uint8_t current_mode = g_spectrum_mode;

    /* =================================================================
     *  MODE 0 - Single-frequency (pulse signal, pre-filtered)
     *
     *  Only g_target_freq_MHz shows a non-zero power value.
     *  Power waveform: rapid rise -> peak -> fall -> bounce -> quiet.
     *
     *  Replace simulate_pulse_power() with real ADC reading:
     *      float power = ReadADCPower_dBm();
     * ================================================================= */
    if (current_mode == SPECTRUM_MODE_SINGLE_FREQ) {

        /* Clamp target frequency to valid range */
        float freq = g_target_freq_MHz;
        if (freq < SWEEP_FREQ_START_MHZ) freq = SWEEP_FREQ_START_MHZ;
        if (freq > SWEEP_FREQ_END_MHZ)  freq = SWEEP_FREQ_END_MHZ;

        /*
         *  Pulse power source - currently simulated (800 ms period).
         *  Replace with real ADC / detector for competition.
         */
        float power = simulate_pulse_power();

        Spectrum_SingleFreqDraw(freq, power);

        HAL_Delay(50U);   /* ~20 fps */
    }

    /* =================================================================
     *  MODE 1 - Sweep  (80-100 MHz over 15 s, 100 kHz steps)
     *
     *  Spectrum fills left-to-right.  After sweep completes, AM
     *  detection runs and results display in the bottom bar.
     *  After a 2-second hold, the sweep restarts.
     *
     *  Real data path (USE_REAL_SWEEP_DATA=1):
     *    1. external_fetch_sweep_data() fills 200-point array
     *    2. Spectrum_SweepSetData() injects into sweep engine
     *    3. Spectrum_SweepDraw() renders as before
     *
     *  Simulated path (USE_REAL_SWEEP_DATA=0):
     *    Spectrum_SweepInit() generates 200 points internally.
     * ================================================================= */
    else   /* current_mode == SPECTRUM_MODE_SWEEP */
    {
        static uint32_t sweep_start_ms = 0U;
        static uint8_t  sweep_running  = 0U;

        if (!sweep_running) {
#if USE_REAL_SWEEP_DATA
            spectrum_signal_t real_data[SPECTRUM_MAX_POINTS];
            external_fetch_sweep_data(real_data, SPECTRUM_MAX_POINTS);
            Spectrum_SweepSetData(real_data, SPECTRUM_MAX_POINTS);
#else
            Spectrum_SweepInit();
#endif
            sweep_start_ms = HAL_GetTick();
            sweep_running  = 1U;
        }

        uint32_t now_ms     = HAL_GetTick();
        uint32_t elapsed_ms;

        /* Handle 32-bit tick wrap-around gracefully */
        if (now_ms >= sweep_start_ms) {
            elapsed_ms = now_ms - sweep_start_ms;
        } else {
            sweep_start_ms = now_ms;
            elapsed_ms     = 0U;
#if USE_REAL_SWEEP_DATA
            {
                spectrum_signal_t real_data[SPECTRUM_MAX_POINTS];
                external_fetch_sweep_data(real_data, SPECTRUM_MAX_POINTS);
                Spectrum_SweepSetData(real_data, SPECTRUM_MAX_POINTS);
            }
#else
            Spectrum_SweepInit();
#endif
        }

        Spectrum_SweepDraw((float)elapsed_ms);

        /* When sweep completes, pause then restart */
        if (elapsed_ms >= SWEEP_TOTAL_TIME_MS) {
            HAL_Delay(2000U);
#if USE_REAL_SWEEP_DATA
            {
                spectrum_signal_t real_data[SPECTRUM_MAX_POINTS];
                external_fetch_sweep_data(real_data, SPECTRUM_MAX_POINTS);
                Spectrum_SweepSetData(real_data, SPECTRUM_MAX_POINTS);
            }
#else
            Spectrum_SweepInit();
#endif
            sweep_start_ms = HAL_GetTick();
        }

        HAL_Delay(50U);   /* ~20 fps */
    }
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
