/**
  ******************************************************************************
  * @file    spectrum_display.c
  * @brief   Spectrum analyser rendering engine — dual-mode (single-freq + sweep)
  *
  *          Layout (landscape 480x320):
  *            Header bar:   Y =   0 …  29   (navy, title)
  *            Bottom bar:   Y = 250 … 319   (mode-dependent data — DRAWN FIRST)
  *            Plot area:    X =  45 … 440,   Y =  38 … 240  (white)
  *            X-axis zone:  Y = 231 … 249   (tick labels on body bg)
  *
  *          Y-axis convention (per competition spec: signals <= 0 dBm):
  *            Top    = SPECTRUM_Y_REF_DBM    (0 dBm, or higher if signal > 0)
  *            Bottom = SPECTRUM_Y_MIN_DBM   (-60 dBm, noise floor)
  *
  *          IMPORTANT: All large arrays (200-point datasets) are declared
  *          static to avoid stack overflow on STM32F407 (default ~1 KB stack).
  *
  *          Mode 0 (Single frequency):
  *            - One spectral line at the user-set frequency
  *            - Pulse-simulated power: rapid rise -> peak -> decay -> bounce
  *            - Bottom bar (full-width, flat): freq (left) | power (right)
  *            - Target frequency marker always visible on X-axis
  *
  *          Mode 1 (Sweep):
  *            - 80-100 MHz sweep over 15 s, 100-kHz step (200 points)
  *            - Power fills in left-to-right as sweep progresses
  *            - After sweep: AM carrier / sideband detection + modulation index
  *            - Bottom bar shows 5 values: fc, Pc, fs, Ps, ma
  ******************************************************************************
  */
#include "spectrum_display.h"
#include "lcd_st7796.h"
#include <stdio.h>
#include <string.h>
#include <math.h>

/* =================================================================== */
/*  Theme colours (RGB565)                                               */
/* =================================================================== */
#define CLR_HEADER_BG     0x1923U   /* dark navy                         */
#define CLR_BODY_BG       0xEF7DU   /* light gray-blue                   */
#define CLR_PLOT_BG       0xFFFFU   /* white                             */
#define CLR_GRID          0xB5B6U   /* visible gray for grid lines        */
#define CLR_AXES          0x0000U   /* black                             */
#define CLR_SIGNAL        0xF800U   /* pure red for spectral lines        */
#define CLR_LABEL         0x1923U   /* dark navy text                     */
#define CLR_INFO_BORDER   0x001FU   /* bright blue border                 */
#define CLR_INFO_FILL     0xFFFFU   /* white                             */
#define CLR_INFO_TEXT     0x0000U   /* black                             */
#define CLR_BAR_BG        0x07E0U   /* pure green bottom bar (max visible) */
#define CLR_BAR_TEXT      0x0000U   /* black text on green bar            */
#define CLR_SWEEP_LINE    0x07FFU   /* cyan for sweep progress marker     */
#define CLR_CARRIER       0xF800U   /* pure red for carrier marker        */
#define CLR_SIDEBAND      0xFC00U   /* orange for sideband marker         */
#define CLR_TARGET_MARK   0x001FU   /* pure blue for single-freq X-axis   */

/* =================================================================== */
/*  Layout constants (pixel space, 480x320 landscape)                    */
/* =================================================================== */

/* Header */
#define HDR_Y0             0U
#define HDR_Y1            29U

/* Plot area — sits between header and bottom bar */
#define PLOT_X0           45U
#define PLOT_X1          440U
#define PLOT_Y0           38U
#define PLOT_Y1          228U   /* leaves room for X-axis labels above bar */

#define PLOT_W            ((float)(PLOT_X1 - PLOT_X0))   /* 395 px        */
#define PLOT_H            ((float)(PLOT_Y1 - PLOT_Y0))   /* 190 px        */

/* X-axis: 80-100 MHz  ->  PLOT_X0 … PLOT_X1 */
#define FREQ_LO           80.0f
#define FREQ_HI          100.0f
#define FREQ_SCALE        (PLOT_W / (FREQ_HI - FREQ_LO))

/* Bottom info bar — full width, drawn FIRST for guaranteed visibility */
#define BAR_Y0           250U
#define BAR_Y1           319U
#define BAR_X0             0U
#define BAR_X1           479U
#define BAR_TEXT_Y_L1    264U   /* first line of text  */
#define BAR_TEXT_Y_L2    290U   /* second line of text */
#define BAR_TEXT_X_L     12U
#define BAR_TEXT_X_R    240U

/* Minimum visible line height (pixels) for a spectral signal */
#define MIN_LINE_HEIGHT    3U

/* Spectral line width in pixels (odd number recommended for centering) */
#define LINE_WIDTH         2U

/* =================================================================== */
/*  Global buffer for MCU data injection                                 */
/* =================================================================== */
spectrum_signal_t g_spectrum_buffer[SPECTRUM_MAX_POINTS];
uint16_t          g_spectrum_count = 0U;

/* AM detection result (updated after sweep completes) */
am_detection_result_t g_am_result = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f};

/* =================================================================== */
/*  Per-frame dynamic Y-axis state                                       */
/* =================================================================== */
static float y_axis_max_dBm;
static float y_axis_min_dBm;
static float y_tick_step;
static int   y_tick_count;

/* =================================================================== */
/*  Sweep state (static — BSS, not stack)                                */
/* =================================================================== */
static spectrum_signal_t g_sweep_data[SPECTRUM_MAX_POINTS];
static uint8_t           g_sweep_initialised = 0U;
static uint8_t           g_sweep_complete     = 0U;

/* =================================================================== */
/*  Work buffers (static — BSS, not stack — prevents overflow)           */
/* =================================================================== */
static spectrum_signal_t g_work_buf[SPECTRUM_MAX_POINTS];   /* shared work buffer */
static uint16_t          g_sort_idx[SPECTRUM_MAX_POINTS];   /* for find_top_n     */

/* =================================================================== */
/*  Coordinate conversion helpers                                        */
/* =================================================================== */

static inline uint16_t freq_to_x(float f_MHz)
{
    float x = (float)PLOT_X0 + (f_MHz - FREQ_LO) * FREQ_SCALE;
    if (x < (float)PLOT_X0) x = (float)PLOT_X0;
    if (x > (float)PLOT_X1) x = (float)PLOT_X1;
    return (uint16_t)x;
}

static inline uint16_t power_to_y(float p_dBm)
{
    if (p_dBm > y_axis_max_dBm) p_dBm = y_axis_max_dBm;
    if (p_dBm < y_axis_min_dBm) p_dBm = y_axis_min_dBm;

    float range = y_axis_max_dBm - y_axis_min_dBm;
    if (range < 0.01f) range = 1.0f;

    float frac = (y_axis_max_dBm - p_dBm) / range;
    float y = (float)PLOT_Y0 + frac * PLOT_H;

    if (y < (float)PLOT_Y0) y = (float)PLOT_Y0;
    if (y > (float)PLOT_Y1) y = (float)PLOT_Y1;
    return (uint16_t)y;
}

static inline uint8_t is_visible(float power_dBm)
{
    return (power_dBm > y_axis_min_dBm + SIGNAL_VISIBLE_DELTA_DB) ? 1U : 0U;
}

/* =================================================================== */
/*  Y-axis range computation                                             */
/* =================================================================== */

static void compute_y_axis_single_freq(float power_dBm)
{
    (void)power_dBm;
    y_axis_max_dBm = SPECTRUM_Y_REF_DBM;    /* top = 0 dBm   */
    y_axis_min_dBm = SPECTRUM_Y_MIN_DBM;    /* bottom = -60  */

    float range = y_axis_max_dBm - y_axis_min_dBm;
    if (range <= 15.0f)       y_tick_step = 5.0f;
    else if (range <= 30.0f)  y_tick_step = 10.0f;
    else                      y_tick_step = 20.0f;

    y_tick_count = (int)(range / y_tick_step) + 1;
    if (y_tick_count > 13) y_tick_count = 13;
}

static void compute_y_axis_range(const spectrum_signal_t *signals,
                                 uint16_t count)
{
    float max_p = -1000.0f;
    uint16_t i;

    for (i = 0U; i < count; i++) {
        if (signals[i].power_dBm > max_p) max_p = signals[i].power_dBm;
    }

    if (max_p < SPECTRUM_Y_REF_DBM) {
        y_axis_max_dBm = SPECTRUM_Y_REF_DBM;
    } else {
        float raw = max_p + SPECTRUM_Y_MARGIN_DB;
        int n = (int)(raw / 10.0f);
        if (raw > (float)n * 10.0f) n++;
        y_axis_max_dBm = (float)(n * 10);
    }

    y_axis_min_dBm = SPECTRUM_Y_MIN_DBM;

    float range = y_axis_max_dBm - y_axis_min_dBm;
    if (range <= 15.0f)       y_tick_step = 5.0f;
    else if (range <= 30.0f)  y_tick_step = 10.0f;
    else                      y_tick_step = 20.0f;

    y_tick_count = (int)(range / y_tick_step) + 1;
    if (y_tick_count > 13) y_tick_count = 13;
}

/* =================================================================== */
/*  Drawing primitives                                                   */
/* =================================================================== */

static void draw_header(const char *title)
{
    /* Fill header bar */
    LCD_Fill(0U, HDR_Y0, (uint16_t)(LCD_WIDTH - 1U), HDR_Y1, CLR_HEADER_BG);
    /* Separator line */
    LCD_DrawLine(0U, (uint16_t)(HDR_Y1 + 1U),
                 (uint16_t)(LCD_WIDTH - 1U), (uint16_t)(HDR_Y1 + 1U),
                 CLR_INFO_BORDER);
    /* Title text — centered */
    uint16_t title_w = (uint16_t)((uint16_t)strlen(title) * FONT_WIDTH);
    uint16_t title_x = (uint16_t)(((uint16_t)LCD_WIDTH - title_w) / 2U);
    LCD_ShowString(title_x, 6U, title, WHITE, CLR_HEADER_BG);
}

static void draw_body_bg(void)
{
    /* Fill body area (below header, above bottom bar) */
    LCD_Fill(0U, (uint16_t)(HDR_Y1 + 2U),
             (uint16_t)(LCD_WIDTH - 1U), (uint16_t)(BAR_Y0 - 1U),
             CLR_BODY_BG);
    /* White plot area */
    LCD_Fill(PLOT_X0, PLOT_Y0, PLOT_X1, PLOT_Y1, CLR_PLOT_BG);
}

static void draw_grid(void)
{
    int t;
    /* Y grid */
    for (t = 0; t < y_tick_count; t++) {
        float dBm_val = y_axis_min_dBm + (float)t * y_tick_step;
        if (dBm_val > y_axis_max_dBm + 0.01f) break;
        uint16_t gy = power_to_y(dBm_val);
        LCD_DrawLine(PLOT_X0, gy, PLOT_X1, gy, CLR_GRID);
    }
    /* X grid */
    uint8_t f;
    for (f = 80U; f <= 100U; f += 5U) {
        uint16_t gx = freq_to_x((float)f);
        LCD_DrawLine(gx, PLOT_Y0, gx, PLOT_Y1, CLR_GRID);
    }
}

static void draw_axes(void)
{
    char buf[16];

    /* Y-axis line */
    LCD_DrawLine(PLOT_X0, PLOT_Y0, PLOT_X0, PLOT_Y1, CLR_AXES);

    /* dBm label — placed just below header, left of plot area */
    LCD_ShowString(2U, 32U, "dBm", CLR_AXES, CLR_BODY_BG);

    /* Y tick marks and numeric labels */
    {
        int t;
        for (t = 0; t < y_tick_count; t++) {
            float dBm_val = y_axis_min_dBm + (float)t * y_tick_step;
            if (dBm_val > y_axis_max_dBm + 0.01f) break;

            uint16_t ty = power_to_y(dBm_val);
            LCD_DrawLine((uint16_t)(PLOT_X0 - 4U), ty, PLOT_X0, ty, CLR_AXES);

            sprintf(buf, "%.0f", (double)dBm_val);
            uint16_t lbl_w = (uint16_t)((uint16_t)strlen(buf) * FONT_WIDTH);
            uint16_t lx    = (uint16_t)(PLOT_X0 - 8U - lbl_w);
            uint16_t ly    = (uint16_t)(ty - (FONT_HEIGHT / 2U));
            if (lx < 2U) lx = 2U;
            LCD_ShowString(lx, ly, buf, CLR_AXES, CLR_BODY_BG);
        }
    }

    /* X-axis line */
    LCD_DrawLine(PLOT_X0, PLOT_Y1, PLOT_X1, PLOT_Y1, CLR_AXES);

    /* X-axis label "Freq/MHz" bottom-right inside plot */
    {
        const char *xlabel = "Freq/MHz";
        uint16_t xlbl_w = (uint16_t)((uint16_t)strlen(xlabel) * FONT_WIDTH);
        uint16_t xlbl_x = (uint16_t)(PLOT_X1 - xlbl_w - 2U);
        uint16_t xlbl_y = (uint16_t)(PLOT_Y1 - FONT_HEIGHT - 2U);
        LCD_ShowString(xlbl_x, xlbl_y, xlabel, CLR_AXES, CLR_PLOT_BG);
    }

    /* X tick marks: 80, 85, 90, 95, 100 MHz */
    {
        uint8_t fx;
        for (fx = 80U; fx <= 100U; fx += 5U) {
            uint16_t tx = freq_to_x((float)fx);
            LCD_DrawLine(tx, PLOT_Y1, tx, (uint16_t)(PLOT_Y1 + 5U), CLR_AXES);
            sprintf(buf, "%u", fx);
            uint16_t lbl_w = (uint16_t)((uint16_t)strlen(buf) * FONT_WIDTH);
            uint16_t lx    = (uint16_t)(tx - (lbl_w / 2U));
            LCD_ShowString(lx, (uint16_t)(PLOT_Y1 + 6U), buf, CLR_AXES, CLR_BODY_BG);
        }
    }
}

/**
  * @brief  Draw a THICK vertical spectral line (LINE_WIDTH pixels wide).
  *          The line extends from the noise-floor baseline up to the
  *          signal's power level.  A minimum height is enforced so that
  *          even very weak signals remain visible.
  */
static void draw_spectral_line(float freq_MHz, float power_dBm,
                               const char *label, uint16_t color)
{
    uint16_t px = freq_to_x(freq_MHz);
    uint16_t py = power_to_y(power_dBm);
    uint16_t base_y = power_to_y(y_axis_min_dBm);

    /* Enforce minimum visible height */
    {
        uint16_t line_h = (uint16_t)(base_y - py);
        if (line_h < MIN_LINE_HEIGHT) {
            if (base_y >= (uint16_t)(PLOT_Y0 + MIN_LINE_HEIGHT)) {
                py = base_y - MIN_LINE_HEIGHT;
            } else {
                py = PLOT_Y0;
            }
        }
    }

    /* Draw a thick line: fill a LINE_WIDTH-pixel-wide vertical strip */
    {
        int16_t half_w = (int16_t)(LINE_WIDTH / 2U);
        int16_t x_start = (int16_t)px - half_w;
        int16_t x_end   = (int16_t)px + half_w;
        if (x_start < (int16_t)PLOT_X0) x_start = (int16_t)PLOT_X0;
        if (x_end   > (int16_t)PLOT_X1) x_end   = (int16_t)PLOT_X1;
        LCD_Fill((uint16_t)x_start, py, (uint16_t)x_end, base_y, color);
    }

    /* Top pixel marker (extra-bright dot) */
    if (px > PLOT_X0 && px < PLOT_X1 && py > PLOT_Y0) {
        LCD_DrawPixel(px, (uint16_t)(py - 1U), WHITE);
        LCD_DrawPixel(px, py, color);
    }

    /* Draw label if provided */
    if (label != NULL && label[0] != '\0') {
        uint16_t lbl_w = (uint16_t)((uint16_t)strlen(label) * FONT_WIDTH);
        uint16_t lbl_x;
        if (px > (lbl_w / 2U)) {
            lbl_x = (uint16_t)(px - (lbl_w / 2U));
        } else {
            lbl_x = 0U;
        }
        if ((uint32_t)lbl_x + lbl_w >= LCD_WIDTH) {
            lbl_x = (uint16_t)(LCD_WIDTH - 1U - lbl_w);
        }
        uint16_t lbl_y;
        if (py >= (uint16_t)(PLOT_Y0 + FONT_HEIGHT + 4U)) {
            lbl_y = (uint16_t)(py - FONT_HEIGHT - 2U);
        } else {
            lbl_y = (uint16_t)(py + 4U);
        }
        /* Erase background behind label */
        LCD_Fill(lbl_x, lbl_y, (uint16_t)(lbl_x + lbl_w - 1U),
                 (uint16_t)(lbl_y + FONT_HEIGHT - 1U), CLR_PLOT_BG);
        LCD_ShowString(lbl_x, lbl_y, label, color, CLR_PLOT_BG);
    }
}

/* =================================================================== */
/*  Top-N selection (static idx buffer — no stack alloc)                  */
/* =================================================================== */

static void find_top_n(const spectrum_signal_t *signals, uint16_t count,
                       uint16_t *out_indices, uint16_t n)
{
    uint16_t i, j;
    if (n > count) n = count;
    if (n == 0U) return;
    if (count > SPECTRUM_MAX_POINTS) count = SPECTRUM_MAX_POINTS;

    for (i = 0U; i < count; i++) g_sort_idx[i] = i;

    for (i = 0U; i < n; i++) {
        uint16_t best = i;
        for (j = (uint16_t)(i + 1U); j < count; j++) {
            if (signals[g_sort_idx[j]].power_dBm
                > signals[g_sort_idx[best]].power_dBm) {
                best = j;
            }
        }
        if (best != i) {
            uint16_t tmp = g_sort_idx[i];
            g_sort_idx[i] = g_sort_idx[best];
            g_sort_idx[best] = tmp;
        }
    }

    for (i = 0U; i < n; i++) out_indices[i] = g_sort_idx[i];
}

/* =================================================================== */
/*  Bottom info bars — DRAWN FIRST for guaranteed visibility             */
/* =================================================================== */

/**
  * @brief  Mode 0 bottom bar.
  *         Left: frequency (MHz).  Right: real-time power (dBm).
  */
static void draw_bottom_bar_single_freq(float freq_MHz, float power_dBm)
{
    char buf[40];

    /* Solid green fill — maximum visibility */
    LCD_Fill(BAR_X0, BAR_Y0, BAR_X1, BAR_Y1, CLR_BAR_BG);
    /* Thick border */
    LCD_DrawRectangle(BAR_X0, BAR_Y0, BAR_X1, BAR_Y1, CLR_INFO_BORDER);

    /* Left: frequency */
    sprintf(buf, "Freq: %.2f MHz", (double)freq_MHz);
    LCD_ShowString(BAR_TEXT_X_L, BAR_TEXT_Y_L1, buf, CLR_BAR_TEXT, CLR_BAR_BG);

    /* Right: power */
    sprintf(buf, "Power: %.1f dBm", (double)power_dBm);
    LCD_ShowString(BAR_TEXT_X_R, BAR_TEXT_Y_L1, buf, CLR_BAR_TEXT, CLR_BAR_BG);
}

/**
  * @brief  Mode 1 bottom bar.
  *          Shows 5 values: fc, Pc, fs, Ps, ma (carrier + sideband).
  *          If no carrier/sideband detected, shows 0 values or "Sweeping...".
  */
static void draw_bottom_bar_sweep(const am_detection_result_t *am)
{
    char buf[60];

    LCD_Fill(BAR_X0, BAR_Y0, BAR_X1, BAR_Y1, CLR_BAR_BG);
    LCD_DrawRectangle(BAR_X0, BAR_Y0, BAR_X1, BAR_Y1, CLR_INFO_BORDER);

    if (am->carrier_freq_MHz > 0.01f) {
        /* Line 1: Carrier Freq | Carrier Power | Modulation Index */
        sprintf(buf, "fc:%.2fMHz  Pc:%.1fdBm  ma:%.3f",
                (double)am->carrier_freq_MHz,
                (double)am->carrier_power_dBm,
                (double)am->modulation_index);
        LCD_ShowString((uint16_t)(BAR_X0 + 8U), BAR_TEXT_Y_L1,
                       buf, CLR_BAR_TEXT, CLR_BAR_BG);

        /* Line 2: Sideband Freq | Sideband Power */
        if (am->sideband_freq_MHz > 0.001f
            && am->sideband_power_dBm > -100.0f) {
            sprintf(buf, "fs:%.2fMHz  Ps:%.1fdBm",
                    (double)am->sideband_freq_MHz,
                    (double)am->sideband_power_dBm);
        } else {
            sprintf(buf, "fs:0.00  Ps:0.0  ma:0.000  (no sideband)");
        }
        LCD_ShowString((uint16_t)(BAR_X0 + 8U), BAR_TEXT_Y_L2,
                       buf, CLR_BAR_TEXT, CLR_BAR_BG);
    } else {
        /* Sweep in progress */
        sprintf(buf, "Sweeping... (80-100 MHz, 15s)");
        LCD_ShowString((uint16_t)(BAR_X0 + 8U), BAR_TEXT_Y_L1,
                       buf, CLR_BAR_TEXT, CLR_BAR_BG);
    }
}

/* =================================================================== */
/*  Pulse simulation for Mode 0                                          */
/* =================================================================== */

float simulate_pulse_power(void)
{
    uint32_t t_ms = HAL_GetTick();
    float phase = (float)(t_ms % 800UL) / 800.0f;  /* 800 ms period */
    float power;

    if (phase < 0.15f) {
        /* Rise: -60 -> -8 dBm */
        power = SPECTRUM_Y_MIN_DBM + 52.0f * (phase / 0.15f);
    } else if (phase < 0.30f) {
        /* Fall: -8 -> -60 dBm */
        power = -8.0f - 52.0f * ((phase - 0.15f) / 0.15f);
    } else if (phase < 0.40f) {
        /* Bounce: -60 -> -25 dBm */
        power = SPECTRUM_Y_MIN_DBM + 35.0f * ((phase - 0.30f) / 0.10f);
    } else if (phase < 0.50f) {
        /* Bounce decay: -25 -> -60 dBm */
        power = -25.0f - 35.0f * ((phase - 0.40f) / 0.10f);
    } else {
        power = SPECTRUM_Y_MIN_DBM;
    }

    return power;
}

/* =================================================================== */
/*  Sweep data generation (simulated — per competition spec)             */
/* =================================================================== */

static void sweep_generate_data(spectrum_signal_t *buf)
{
    uint16_t i;
    float f_step = (SWEEP_FREQ_END_MHZ - SWEEP_FREQ_START_MHZ)
                   / (float)(SPECTRUM_MAX_POINTS - 1U);

    for (i = 0U; i < SPECTRUM_MAX_POINTS; i++) {
        float f = SWEEP_FREQ_START_MHZ + (float)i * f_step;
        float p = SPECTRUM_Y_MIN_DBM;

        /* Carrier 1: 90.00 MHz, -27 dBm, AM sidebands at +/-0.50 MHz */
        /* Upper sideband (90.50 MHz) */
        if (f >= 90.45f && f <= 90.55f) {
            float d = (f - 90.50f) * 10.0f;
            float contrib = -39.0f - (d * d) * 15.0f;
            if (contrib > p) p = contrib;
        }
        /* Carrier (90.00 MHz) */
        if (f >= 89.90f && f <= 90.10f) {
            float d = (f - 90.00f) * 10.0f;
            float contrib = -27.0f - (d * d) * 25.0f;
            if (contrib > p) p = contrib;
        }
        /* Lower sideband (89.50 MHz) */
        if (f >= 89.45f && f <= 89.55f) {
            float d = (f - 89.50f) * 10.0f;
            float contrib = -39.0f - (d * d) * 15.0f;
            if (contrib > p) p = contrib;
        }

        /* Carrier 2: 95.00 MHz, -35 dBm, unmodulated */
        if (f >= 94.93f && f <= 95.07f) {
            float d = (f - 95.00f) * 10.0f;
            float contrib = -35.0f - (d * d) * 30.0f;
            if (contrib > p) p = contrib;
        }

        buf[i].freq_MHz  = f;
        buf[i].power_dBm = p;
    }
}

/* =================================================================== */
/*  AM detection                                                          */
/* =================================================================== */

static void detect_am(const spectrum_signal_t *signals, uint16_t count,
                      am_detection_result_t *result)
{
    uint16_t top_idx[10];

    result->carrier_freq_MHz   = 0.0f;
    result->carrier_power_dBm  = 0.0f;
    result->sideband_freq_MHz  = 0.0f;
    result->sideband_power_dBm = 0.0f;
    result->modulation_index   = 0.0f;

    if (signals == NULL || count < 3U) return;

    find_top_n(signals, count, top_idx, 10U);

    uint16_t best = top_idx[0];
    if (signals[best].power_dBm < AM_MIN_CARRIER_DBM) return;

    float fc = signals[best].freq_MHz;
    float pc = signals[best].power_dBm;

    result->carrier_freq_MHz  = fc;
    result->carrier_power_dBm = pc;

    float best_sideband_pow  = -1000.0f;
    float best_mod_freq      = 0.0f;

    uint16_t pk;
    for (pk = 1U; pk < 10U; pk++) {
        uint16_t idx = top_idx[pk];
        float f_side = signals[idx].freq_MHz;
        float p_side = signals[idx].power_dBm;

        if (p_side < pc - AM_SIDEBAND_MAX_DELTA) continue;

        float delta_f = f_side - fc;
        if (delta_f < 0.0f) delta_f = -delta_f;

        float delta_khz = delta_f * 1000.0f;
        if (delta_khz < (float)AM_MIN_MOD_FREQ_KHZ) continue;
        if (delta_khz > (float)AM_MAX_MOD_FREQ_KHZ) continue;

        float partner_freq = fc - (f_side - fc);
        uint8_t  has_partner = 0U;
        float    partner_pow = -1000.0f;

        uint16_t j;
        for (j = 1U; j < 10U; j++) {
            if (j == pk) continue;
            uint16_t pidx = top_idx[j];
            float p_dist = signals[pidx].freq_MHz - partner_freq;
            if (p_dist < 0.0f) p_dist = -p_dist;
            if (p_dist < 0.15f) {
                has_partner = 1U;
                partner_pow = signals[pidx].power_dBm;
                break;
            }
        }

        if (has_partner) {
            float avg_pow = (p_side + partner_pow) / 2.0f;
            if (avg_pow > best_sideband_pow) {
                best_sideband_pow  = avg_pow;
                best_mod_freq      = delta_f;
            }
        }
    }

    if (best_sideband_pow > -100.0f) {
        result->sideband_freq_MHz  = best_mod_freq;
        result->sideband_power_dBm = best_sideband_pow;

        float dB_diff = best_sideband_pow - pc;
        float linear_ratio = powf(10.0f, dB_diff / 20.0f);
        result->modulation_index = 2.0f * linear_ratio;

        if (result->modulation_index > 1.5f) result->modulation_index = 1.5f;
        if (result->modulation_index < 0.001f) result->modulation_index = 0.0f;
    }
}

/* =================================================================== */
/*  PUBLIC API — Mode 0: Single Frequency                                */
/* =================================================================== */

void Spectrum_SingleFreqDraw(float target_freq_MHz, float power_dBm)
{
    char   lbl_buf[24];
    uint16_t i;

    /* Clamp frequency */
    float freq = target_freq_MHz;
    if (freq < FREQ_LO) freq = FREQ_LO;
    if (freq > FREQ_HI) freq = FREQ_HI;

    /* Build dataset in STATIC work buffer (not on stack!) */
    float f_step = (FREQ_HI - FREQ_LO) / (float)(SPECTRUM_MAX_POINTS - 1U);
    for (i = 0U; i < SPECTRUM_MAX_POINTS; i++) {
        g_work_buf[i].freq_MHz  = FREQ_LO + (float)i * f_step;
        g_work_buf[i].power_dBm = SPECTRUM_Y_MIN_DBM;
    }

    /* Find closest bin */
    uint16_t best_bin = 0U;
    float best_dist = 1000.0f;
    for (i = 0U; i < SPECTRUM_MAX_POINTS; i++) {
        float dist = g_work_buf[i].freq_MHz - freq;
        if (dist < 0.0f) dist = -dist;
        if (dist < best_dist) { best_dist = dist; best_bin = i; }
    }
    g_work_buf[best_bin].power_dBm = power_dBm;

    /* Narrow Gaussian spread */
    {
        int16_t spread;
        for (spread = -2; spread <= 2; spread++) {
            int16_t idx = (int16_t)best_bin + spread;
            if (idx >= 0 && idx < (int16_t)SPECTRUM_MAX_POINTS
                && idx != (int16_t)best_bin) {
                float p = power_dBm - (float)(spread < 0 ? -spread : spread) * 5.0f;
                if (p < SPECTRUM_Y_MIN_DBM) p = SPECTRUM_Y_MIN_DBM;
                g_work_buf[(uint16_t)idx].power_dBm = p;
            }
        }
    }

    /* === DRAW ORDER: Bottom bar FIRST, then plot === */
    /* Phase 1: Bottom bar (green — guaranteed visible) */
    draw_bottom_bar_single_freq(freq, power_dBm);

    /* Phase 2: Y-axis */
    compute_y_axis_single_freq(power_dBm);

    /* Phase 3: Header + body background + plot */
    draw_header("Spectrum Analyzer");
    draw_body_bg();

    /* Phase 4: Grid + axes */
    draw_grid();
    draw_axes();

    /* Phase 5: Draw visible spectral lines */
    for (i = 0U; i < SPECTRUM_MAX_POINTS; i++) {
        /* Always draw the target bin — skip visibility check for it */
        if (i != best_bin && !is_visible(g_work_buf[i].power_dBm)) continue;

        const char *label_ptr = NULL;
        if (i == best_bin) {
            sprintf(lbl_buf, "%.1fdBm", (double)g_work_buf[i].power_dBm);
            label_ptr = lbl_buf;
        }
        draw_spectral_line(g_work_buf[i].freq_MHz, g_work_buf[i].power_dBm,
                           label_ptr, (i == best_bin) ? CLR_CARRIER : CLR_SIGNAL);
    }

    /* Phase 6: Target frequency marker on X-axis */
    {
        uint16_t tx = freq_to_x(freq);
        /* Tick mark up from X-axis */
        LCD_DrawLine(tx, PLOT_Y1, tx, (uint16_t)(PLOT_Y1 - 14U), CLR_TARGET_MARK);
        /* Tick mark down from X-axis */
        LCD_DrawLine(tx, PLOT_Y1, tx, (uint16_t)(PLOT_Y1 + 6U), CLR_TARGET_MARK);

        /* Frequency label — inside plot, just above X-axis */
        sprintf(lbl_buf, "%.2f MHz", (double)freq);
        uint16_t lbl_w = (uint16_t)((uint16_t)strlen(lbl_buf) * FONT_WIDTH);
        uint16_t lx    = (uint16_t)(tx - (lbl_w / 2U));
        if (lx < PLOT_X0) lx = PLOT_X0;
        if ((uint32_t)lx + lbl_w > PLOT_X1) lx = (uint16_t)(PLOT_X1 - lbl_w);
        uint16_t ly = (uint16_t)(PLOT_Y1 - FONT_HEIGHT - 2U);
        LCD_Fill(lx, ly, (uint16_t)(lx + lbl_w - 1U),
                 (uint16_t)(ly + FONT_HEIGHT - 1U), CLR_PLOT_BG);
        LCD_ShowString(lx, ly, lbl_buf, CLR_TARGET_MARK, CLR_PLOT_BG);
    }
}

/* =================================================================== */
/*  PUBLIC API — Mode 1: Sweep                                           */
/* =================================================================== */

void Spectrum_SweepInit(void)
{
    sweep_generate_data(g_sweep_data);
    g_sweep_initialised = 1U;
    g_sweep_complete    = 0U;

    g_am_result.carrier_freq_MHz   = 0.0f;
    g_am_result.carrier_power_dBm  = 0.0f;
    g_am_result.sideband_freq_MHz  = 0.0f;
    g_am_result.sideband_power_dBm = 0.0f;
    g_am_result.modulation_index   = 0.0f;
}

/**
  * @brief  Inject real sweep data from external module.
  *
  *          Usage pattern in main.c:
  *            // 1. 从外部模块获取 200 点频谱数据
  *            spectrum_signal_t my_data[200];
  *            for (int i = 0; i < 200; i++) {
  *                my_data[i].freq_MHz  = 80.0f + i * 0.1005f;
  *                my_data[i].power_dBm = external_read_power(i);
  *            }
  *            // 2. 注入
  *            Spectrum_SweepSetData(my_data, 200);
  *            // 3. (可选) 如需重置 sweep 计时:
  *            //     sweep_start_ms = HAL_GetTick();
  */
void Spectrum_SweepSetData(const spectrum_signal_t *data, uint16_t count)
{
    uint16_t i;
    uint16_t n = (count > SPECTRUM_MAX_POINTS) ? SPECTRUM_MAX_POINTS : count;

    for (i = 0U; i < n; i++) {
        g_sweep_data[i].freq_MHz  = data[i].freq_MHz;
        g_sweep_data[i].power_dBm = data[i].power_dBm;
    }

    /* Zero-fill remaining bins (if data shorter than 200 points) */
    for (i = n; i < SPECTRUM_MAX_POINTS; i++) {
        g_sweep_data[i].freq_MHz  = SWEEP_FREQ_START_MHZ
            + (float)i * (SWEEP_FREQ_END_MHZ - SWEEP_FREQ_START_MHZ)
                         / (float)(SPECTRUM_MAX_POINTS - 1U);
        g_sweep_data[i].power_dBm = SPECTRUM_Y_MIN_DBM;
    }

    g_sweep_initialised = 1U;
    g_sweep_complete    = 0U;

    g_am_result.carrier_freq_MHz   = 0.0f;
    g_am_result.carrier_power_dBm  = 0.0f;
    g_am_result.sideband_freq_MHz  = 0.0f;
    g_am_result.sideband_power_dBm = 0.0f;
    g_am_result.modulation_index   = 0.0f;
}

void Spectrum_SweepDraw(float elapsed_ms)
{
    char   lbl_buf[24];
    uint16_t i;
    uint16_t top3[3];

    if (!g_sweep_initialised) Spectrum_SweepInit();

    /* Compute sweep progress */
    float sweep_frac;
    if (elapsed_ms >= (float)SWEEP_TOTAL_TIME_MS) {
        sweep_frac = 1.0f;
        if (!g_sweep_complete) {
            g_sweep_complete = 1U;
            detect_am(g_sweep_data, SPECTRUM_MAX_POINTS, &g_am_result);
        }
    } else {
        sweep_frac = elapsed_ms / (float)SWEEP_TOTAL_TIME_MS;
    }

    float current_freq = SWEEP_FREQ_START_MHZ
        + (SWEEP_FREQ_END_MHZ - SWEEP_FREQ_START_MHZ) * sweep_frac;

    /* Build visible dataset in STATIC work buffer (not on stack!) */
    for (i = 0U; i < SPECTRUM_MAX_POINTS; i++) {
        g_work_buf[i].freq_MHz = g_sweep_data[i].freq_MHz;
        if (g_sweep_data[i].freq_MHz <= current_freq + 0.05f) {
            g_work_buf[i].power_dBm = g_sweep_data[i].power_dBm;
        } else {
            g_work_buf[i].power_dBm = SPECTRUM_Y_MIN_DBM;
        }
    }

    /* === DRAW ORDER: Bottom bar FIRST === */
    if (g_sweep_complete) {
        draw_bottom_bar_sweep(&g_am_result);
    } else {
        am_detection_result_t empty = {0};
        draw_bottom_bar_sweep(&empty);
    }

    /* Phase 1: Y-axis */
    compute_y_axis_range(g_work_buf, SPECTRUM_MAX_POINTS);

    /* Phase 2: Header + body */
    draw_header("sweep frequency");
    draw_body_bg();

    /* Phase 3: Grid + axes */
    draw_grid();
    draw_axes();

    /* Phase 4: Top-3 peaks */
    find_top_n(g_work_buf, SPECTRUM_MAX_POINTS, top3, 3U);

    /* Phase 5: Draw spectral lines */
    for (i = 0U; i < SPECTRUM_MAX_POINTS; i++) {
        /* Skip non-visible bins (but still draw if top3) */
        uint8_t is_top3 = 0U;
        uint8_t k;
        for (k = 0U; k < 3U; k++) {
            if (top3[k] == i) { is_top3 = 1U; break; }
        }
        if (!is_top3 && !is_visible(g_work_buf[i].power_dBm)) continue;

        /* Choose colour */
        uint16_t line_color = CLR_SIGNAL;
        if (g_sweep_complete && g_am_result.carrier_freq_MHz > 0.01f) {
            float dist_c = g_work_buf[i].freq_MHz - g_am_result.carrier_freq_MHz;
            if (dist_c < 0.0f) dist_c = -dist_c;
            if (dist_c < 0.15f) {
                line_color = CLR_CARRIER;
            } else if (g_am_result.sideband_freq_MHz > 0.01f) {
                float sb = g_am_result.sideband_freq_MHz;
                float dist_u = g_work_buf[i].freq_MHz - (g_am_result.carrier_freq_MHz + sb);
                float dist_l = g_work_buf[i].freq_MHz - (g_am_result.carrier_freq_MHz - sb);
                if (dist_u < 0.0f) dist_u = -dist_u;
                if (dist_l < 0.0f) dist_l = -dist_l;
                if (dist_u < 0.18f || dist_l < 0.18f) {
                    line_color = CLR_SIDEBAND;
                }
            }
        }

        /* Label only for top-3 */
        const char *label_ptr = NULL;
        if (is_top3) {
            sprintf(lbl_buf, "%.1f", (double)g_work_buf[i].power_dBm);
            label_ptr = lbl_buf;
        }

        draw_spectral_line(g_work_buf[i].freq_MHz, g_work_buf[i].power_dBm,
                           label_ptr, line_color);
    }

    /* Phase 6: Sweep progress line (cyan) */
    {
        uint16_t sx = freq_to_x(current_freq);
        LCD_DrawLine(sx, PLOT_Y0, sx, PLOT_Y1, CLR_SWEEP_LINE);
    }
}

/* =================================================================== */
/*  PUBLIC API — Original (backward compatible)                          */
/* =================================================================== */

void Spectrum_Draw(const spectrum_signal_t *signals, uint16_t count)
{
    char   lbl_buf[12];
    uint16_t top3[3];
    uint16_t i;

    if (signals == NULL || count == 0U) return;
    if (count > SPECTRUM_MAX_POINTS) count = SPECTRUM_MAX_POINTS;

    compute_y_axis_range(signals, count);

    draw_header("Spectrum Analyzer");
    draw_body_bg();
    draw_grid();
    draw_axes();

    find_top_n(signals, count, top3, 3U);

    for (i = 0U; i < count; i++) {
        if (!is_visible(signals[i].power_dBm)) continue;

        const char *label_ptr = NULL;
        uint8_t is_top3 = 0U;
        uint8_t k;
        for (k = 0U; k < 3U; k++) {
            if (top3[k] == i) { is_top3 = 1U; break; }
        }
        if (is_top3) {
            sprintf(lbl_buf, "%.1f", (double)signals[i].power_dBm);
            label_ptr = lbl_buf;
        }

        draw_spectral_line(signals[i].freq_MHz, signals[i].power_dBm,
                           label_ptr, CLR_SIGNAL);
    }

    /* Compat info box — bottom-right */
    {
        #define INFO_X0  240U
        #define INFO_Y0  258U
        #define INFO_X1  465U
        #define INFO_Y1  313U
        char buf[40];

        uint16_t best = top3[0];
        float f = signals[best].freq_MHz;
        float p = signals[best].power_dBm;

        LCD_DrawRectangle(INFO_X0, INFO_Y0, INFO_X1, INFO_Y1, CLR_INFO_BORDER);
        LCD_Fill((uint16_t)(INFO_X0 + 1U), (uint16_t)(INFO_Y0 + 1U),
                 (uint16_t)(INFO_X1 - 1U), (uint16_t)(INFO_Y1 - 1U), CLR_INFO_FILL);

        sprintf(buf, "Peak: %.2f MHz", (double)f);
        LCD_ShowString((uint16_t)(INFO_X0 + 6U), (uint16_t)(INFO_Y0 + 6U),
                       buf, CLR_INFO_TEXT, CLR_INFO_FILL);
        sprintf(buf, "Pow: %.1f dBm", (double)p);
        LCD_ShowString((uint16_t)(INFO_X0 + 6U), (uint16_t)(INFO_Y0 + 26U),
                       buf, CLR_INFO_TEXT, CLR_INFO_FILL);
        #undef INFO_X0
        #undef INFO_Y0
        #undef INFO_X1
        #undef INFO_Y1
    }
}

void Spectrum_DrawFromBuffer(void)
{
    Spectrum_Draw(g_spectrum_buffer, g_spectrum_count);
}

/* =================================================================== */
/*  Demo sequencer (backward compatible)                                  */
/* =================================================================== */

#define DEMO_DELAY  3000U

static uint16_t demo_generate_pattern(spectrum_signal_t *buf, uint8_t pattern_id)
{
    uint16_t i;
    float    f_step = (FREQ_HI - FREQ_LO) / (float)(SPECTRUM_MAX_POINTS - 1U);

    for (i = 0U; i < SPECTRUM_MAX_POINTS; i++) {
        float f = FREQ_LO + (float)i * f_step;
        float p = SPECTRUM_Y_MIN_DBM;

        switch (pattern_id) {
        case 0:
            if (i >= 93U && i <= 107U) {
                float d = (float)((int)i - 100) * 0.5f;
                p = -15.0f - (d * d) * 1.5f;
                if (p < SPECTRUM_Y_MIN_DBM) p = SPECTRUM_Y_MIN_DBM;
            }
            break;
        case 1:
            if (i >= 43U && i <= 57U) {
                float d = (float)((int)i - 50) * 0.5f;
                p = -20.0f - (d * d) * 2.0f;
            } else if (i >= 93U && i <= 107U) {
                float d = (float)((int)i - 100) * 0.5f;
                p = -12.0f - (d * d) * 1.5f;
            }
            if (p < SPECTRUM_Y_MIN_DBM) p = SPECTRUM_Y_MIN_DBM;
            break;
        case 2:
            {
                struct { int idx; float pow; } peaks[5] = {
                    { 35, -22.0f }, { 60, -18.0f }, { 100, -10.0f },
                    { 130, -25.0f }, { 160, -20.0f },
                };
                uint8_t n;
                for (n = 0U; n < 5U; n++) {
                    if (i >= (uint16_t)(peaks[n].idx - 4U)
                        && i <= (uint16_t)(peaks[n].idx + 4U)) {
                        float d = (float)((int)i - peaks[n].idx);
                        float contrib = peaks[n].pow - (d * d) * 1.5f;
                        if (contrib > p) p = contrib;
                    }
                }
            }
            break;
        case 3:
            if (i >= 58U && i <= 66U) {
                float d = (float)((int)i - 62) * 0.5f;
                p = -45.0f - (d * d) * 0.8f;
            } else if (i >= 133U && i <= 147U) {
                float d = (float)((int)i - 140) * 0.5f;
                p = -40.0f - (d * d) * 0.5f;
            }
            if (p < SPECTRUM_Y_MIN_DBM) p = SPECTRUM_Y_MIN_DBM;
            break;
        case 4:
            if (i >= 95U && i <= 105U) {
                float d = (float)((int)i - 100) * 0.5f;
                p = 5.0f - (d * d) * 1.0f;
                if (p < SPECTRUM_Y_MIN_DBM) p = SPECTRUM_Y_MIN_DBM;
            }
            break;
        case 5:
            {
                uint8_t pk;
                for (pk = 0U; pk < 8U; pk++) {
                    int pk_idx = 15 + pk * 22;
                    float pk_pow = -15.0f - (float)pk * 3.0f;
                    if (i >= (uint16_t)(pk_idx - 3U)
                        && i <= (uint16_t)(pk_idx + 3U)) {
                        float d = (float)((int)i - pk_idx);
                        float contrib = pk_pow - (d * d) * 2.0f;
                        if (contrib > p) p = contrib;
                    }
                }
            }
            break;
        default: break;
        }

        buf[i].freq_MHz  = f;
        buf[i].power_dBm = p;
    }
    return SPECTRUM_MAX_POINTS;
}

void Spectrum_DemoRun(void)
{
    static spectrum_signal_t demo_buf[SPECTRUM_MAX_POINTS];
    uint8_t scene;
    for (scene = 0U; scene < 6U; scene++) {
        uint16_t n = demo_generate_pattern(demo_buf, scene);
        Spectrum_Draw(demo_buf, n);
        HAL_Delay(DEMO_DELAY);
    }
}
