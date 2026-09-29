/**
  ******************************************************************************
  * @file    spectrum_display.h
  * @brief   Spectrum analyser display engine — 200-point, dual-mode
  *
  *          Designed for the 2026 Fudan Electronic Design Contest B:
  *          "Simple Spectrum Analyser" on ST7796 480x320 landscape LCD.
  *
  *          Modes (selectable in main.c):
  *            Mode 0 — Single frequency (pulse signal, pre-filtered)
  *            Mode 1 — Sweep 80-100 MHz over 15 s with AM demodulation
  *
  *          Key features:
  *            – 200 frequency–power data points per frame
  *            – Dynamic Y-axis handling negative dBm (competition spec)
  *            – AM carrier / sideband detection with modulation index
  *            – Pure vertical lines for spectrum display
  *
  *          Competition spec reference (2026 Fudan B):
  *            – Signal: 80–100 MHz, 1 mV–10 mV eff  →  –47 dBm to –27 dBm
  *            – Sweep: 100 kHz step, ≤ 30 s
  *            – AM: carrier 80–100 MHz, mod freq ≥ 200 kHz, m ≈ 0.5
  *            – Display ≥ 100 points, freq error ≤ 0.01 %, power error ≤ 1 dB
  *            – X‑axis: MHz,  Y‑axis: dBm
  ******************************************************************************
  */
#ifndef __SPECTRUM_DISPLAY_H
#define __SPECTRUM_DISPLAY_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* =================================================================== */
/*  Configuration constants                                              */
/* =================================================================== */

/** Maximum number of frequency–power data points per frame. */
#define SPECTRUM_MAX_POINTS  200U

/**
  * @brief  Y-axis headroom margin (dBm).
  *          The Y-axis upper bound is set to
  *            max(any_signal_power) + SPECTRUM_Y_MARGIN_DB
  *          clamped to SPECTRUM_Y_REF_DBM (0 dBm) unless signal exceeds it.
  *          3 dB is standard RF headroom.
  */
#define SPECTRUM_Y_MARGIN_DB  3.0f

/**
  * @brief  Y-axis default reference level (dBm) — top of plot unless signal > 0.
  *         Per competition spec, signal powers are typically negative
  *         (-47 to -27 dBm).  Top of Y‑axis is pinned at 0 dBm.
  */
#define SPECTRUM_Y_REF_DBM    0.0f

/**
  * @brief  Y-axis default minimum (dBm) — noise floor.
  *         Sufficiently below the weakest specified signal (–47 dBm).
  */
#define SPECTRUM_Y_MIN_DBM   -60.0f

/**
  * @brief  Only draw a spectral line if power is at least this far above
  *         the noise floor.  Prevents noise‑only lines cluttering the plot.
  */
#define SIGNAL_VISIBLE_DELTA_DB  3.0f

/* =================================================================== */
/*  Operating mode constants                                              */
/* =================================================================== */
#define SPECTRUM_MODE_SINGLE_FREQ  0
#define SPECTRUM_MODE_SWEEP        1

/* =================================================================== */
/*  Sweep parameters (per competition spec)                               */
/* =================================================================== */
#define SWEEP_FREQ_START_MHZ     80.0f
#define SWEEP_FREQ_END_MHZ      100.0f
#define SWEEP_STEP_KHZ          100U
#define SWEEP_TOTAL_TIME_MS     15000U       /* 15 s — spec requires ≤30 s */

/* =================================================================== */
/*  AM detection thresholds                                               */
/* =================================================================== */
/**
  * @brief  Minimum carrier power (dBm) to attempt AM demodulation.
  *         Set to –55 dBm — well below the weakest spec signal (–47 dBm)
  *         so that carriers near the noise floor are still evaluated.
  */
#define AM_MIN_CARRIER_DBM     -55.0f

/**
  * @brief  Sideband must be within this many dB of carrier to be considered
  *         a valid modulation product.
  */
#define AM_SIDEBAND_MAX_DELTA   30.0f

/**
  * @brief  Minimum modulation frequency (kHz) for valid AM sideband pair.
  *         Per spec: modulation frequency ≥ 200 kHz.
  */
#define AM_MIN_MOD_FREQ_KHZ     100U

/**
  * @brief  Maximum modulation frequency (kHz).
  */
#define AM_MAX_MOD_FREQ_KHZ     5000U

/* =================================================================== */
/*  Data types                                                           */
/* =================================================================== */

/** One frequency–power measurement point. */
typedef struct {
    float freq_MHz;   /**< Frequency in MHz    (typically 80.0 – 100.0) */
    float power_dBm;  /**< Power in dBm        (may be negative)        */
} spectrum_signal_t;

/**
  * @brief  AM demodulation result (computed after sweep completes).
  */
typedef struct {
    float carrier_freq_MHz;     /**< Carrier frequency (MHz), 0 if none      */
    float carrier_power_dBm;    /**< Carrier power (dBm)                     */
    float sideband_freq_MHz;    /**< Sideband (modulating) frequency (MHz)   */
    float sideband_power_dBm;   /**< Sideband power (dBm)                   */
    float modulation_index;     /**< AM modulation index m (0–1 typically)   */
} am_detection_result_t;

/* =================================================================== */
/*  Global data buffer (for MCU-side data injection)                     */
/* =================================================================== */

extern spectrum_signal_t g_spectrum_buffer[SPECTRUM_MAX_POINTS];
extern uint16_t          g_spectrum_count;

/** Latest AM detection result (updated after sweep completes). */
extern am_detection_result_t g_am_result;

/* =================================================================== */
/*  Public API — original (backward compatible)                          */
/* =================================================================== */

void Spectrum_Draw(const spectrum_signal_t *signals, uint16_t count);
void Spectrum_DrawFromBuffer(void);
void Spectrum_DemoRun(void);

/* =================================================================== */
/*  Public API — Mode 0 (single frequency, pulse signal)                 */
/* =================================================================== */

/**
  * @brief  Draw the single-frequency spectrum view.
  *
  *          Only @p target_freq_MHz shows a non-zero power line; all other
  *          frequency bins are at noise floor (-60 dBm).  A flat info bar
  *          at the bottom shows frequency (left) and power (right).
  *
  * @param  target_freq_MHz  The frequency of interest (80–100 MHz).
  * @param  power_dBm        Current power at that frequency (typically < 0).
  *
  * @note   Call this repeatedly (~20 Hz) to animate the pulse waveform.
  */
void Spectrum_SingleFreqDraw(float target_freq_MHz, float power_dBm);

/* =================================================================== */
/*  Public API — Mode 1 (sweep, AM demodulation)                         */
/* =================================================================== */

/**
  * @brief  Initialise / reset the sweep state.
  *         Must be called once before starting a new sweep.
  */
void Spectrum_SweepInit(void);

/**
  * @brief  Inject external sweep data into the sweep engine.
  *
  *          Copies @p count frequency–power pairs into the internal sweep
  *          buffer.  Must be called BEFORE Spectrum_SweepInit() (which
  *          would overwrite the data with simulation) or call
  *          Spectrum_SweepInit() first, then call this to override.
  *
  * @param  data   Pointer to external spectrum data array.
  * @param  count  Number of points (max SPECTRUM_MAX_POINTS = 200).
  */
void Spectrum_SweepSetData(const spectrum_signal_t *data, uint16_t count);

/**
  * @brief  Draw the sweep spectrum view at a given elapsed time.
  *
  *          Frequencies from #SWEEP_FREQ_START_MHZ up to the current
  *          sweep position show their power values; frequencies beyond
  *          show noise floor.  When the sweep completes (elapsed >=
  *          #SWEEP_TOTAL_TIME_MS), AM detection runs and the result
  *          is stored in @ref g_am_result and displayed on screen.
  *
  * @param  elapsed_ms  Time since sweep start (0 … #SWEEP_TOTAL_TIME_MS).
  */
void Spectrum_SweepDraw(float elapsed_ms);

/* =================================================================== */
/*  Pulse simulation (Mode 0 data source — replace with real ADC)       */
/* =================================================================== */

/**
  * @brief  Return a simulated pulse power value (dBm) based on system tick.
  *         Negative values (noise floor ≈ –60 dBm, peak ≈ –10 dBm).
  *         Replace with real ADC reading for actual competition use.
  */
float simulate_pulse_power(void);

#ifdef __cplusplus
}
#endif

#endif /* __SPECTRUM_DISPLAY_H */
