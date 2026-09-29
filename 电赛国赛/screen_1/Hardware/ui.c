#include "ui.h"

#include <stddef.h>

#include "graphics.h"
#include "plot.h"
#include "st7796.h"

#define COLOR_CYAN     RGB565(34U, 211U, 238U)
#define COLOR_TEAL     RGB565(34U, 160U, 176U)
#define COLOR_GOLD     RGB565(255U, 190U, 74U)
#define COLOR_GREEN    RGB565(61U, 214U, 140U)

#define PLOT_X (16U)
#define PLOT_Y (122U)
#define PLOT_W (448U)
#define PLOT_H (158U)

const UITheme UI_THEME_DARK = {
    RGB565(5U, 12U, 22U),
    RGB565(8U, 34U, 54U),
    RGB565(9U, 25U, 40U),
    RGB565(12U, 39U, 58U),
    RGB565(238U, 247U, 251U),
    RGB565(134U, 163U, 178U),
    COLOR_CYAN,
    COLOR_GREEN
};

static const int16_t g_sine[32] = {
      0,  20,  38,  56,  71,  83,  92,  98,
    100,  98,  92,  83,  71,  56,  38,  20,
      0, -20, -38, -56, -71, -83, -92, -98,
   -100, -98, -92, -83, -71, -56, -38, -20
};

static uint16_t g_demoSpectrum[128];
static int16_t g_demoWaveform[128];

void UI_DrawPageFrame(const char *title, const char *status,
                      const UITheme *theme)
{
    if (theme == NULL) {
        theme = &UI_THEME_DARK;
    }

    ST7796_FillScreen(theme->background);
    ST7796_FillRect(0U, 0U, ST7796_WIDTH, 46U, theme->header);
    ST7796_FillRect(0U, 44U, ST7796_WIDTH, 2U, theme->accent);
    Graphics_DrawText(16U, 14U, title, 2U,
                      theme->primaryText, theme->header);
    Graphics_DrawText(378U, 18U, status, 1U,
                      theme->success, theme->header);

    ST7796_FillRect(0U, 292U, ST7796_WIDTH, 28U, theme->header);
    Graphics_DrawText(14U, 303U, "S1 SPECTRUM", 1U,
                      theme->accent, theme->header);
    Graphics_DrawText(178U, 303U, "S2 PERIODIC", 1U,
                      COLOR_GOLD, theme->header);
    Graphics_DrawText(370U, 303U, "MSPM0", 1U,
                      theme->secondaryText, theme->header);
}

void UI_DrawCard(uint16_t x, uint16_t y, uint16_t width,
                 uint16_t height, const char *label, const char *value,
                 uint16_t accent, const UITheme *theme)
{
    if ((width < 20U) || (height < 28U)) {
        return;
    }
    if (theme == NULL) {
        theme = &UI_THEME_DARK;
    }

    ST7796_FillRect(x, y, width, height, theme->panelAlternate);
    ST7796_FillRect(x, y, 4U, height, accent);
    Graphics_DrawText((uint16_t)(x + 14U), (uint16_t)(y + 8U), label, 1U,
                      theme->secondaryText, theme->panelAlternate);
    Graphics_DrawText((uint16_t)(x + 14U), (uint16_t)(y + 27U), value, 2U,
                      theme->primaryText, theme->panelAlternate);
}

static void build_demo_spectrum(void)
{
    uint16_t index;

    for (index = 0U; index < 128U; index++) {
        int16_t mainDistance = (int16_t)index - 64;
        int16_t leftDistance = (int16_t)index - 40;
        int16_t rightDistance = (int16_t)index - 88;
        uint16_t value = (uint16_t)(5U + ((index * 7U + 3U) % 7U));

        if (mainDistance < 0) mainDistance = (int16_t)-mainDistance;
        if (leftDistance < 0) leftDistance = (int16_t)-leftDistance;
        if (rightDistance < 0) rightDistance = (int16_t)-rightDistance;

        if (mainDistance <= 3) {
            value = (uint16_t)(100 - mainDistance * 22);
        } else if (leftDistance <= 2) {
            value = (uint16_t)(35 - leftDistance * 10);
        } else if (rightDistance <= 2) {
            value = (uint16_t)(30 - rightDistance * 9);
        }
        g_demoSpectrum[index] = value;
    }
}

static void build_demo_waveform(void)
{
    uint16_t index;

    for (index = 0U; index < 128U; index++) {
        g_demoWaveform[index] = g_sine[index & 31U];
    }
}

static void show_welcome(void)
{
    const UITheme *theme = &UI_THEME_DARK;

    ST7796_FillScreen(theme->background);
    ST7796_FillRect(0U, 0U, ST7796_WIDTH, 58U, theme->header);
    ST7796_FillRect(0U, 56U, ST7796_WIDTH, 2U, theme->accent);
    Graphics_DrawText(24U, 18U, "ELECTRONIC COMPETITION", 2U,
                      theme->primaryText, theme->header);
    Graphics_DrawText(24U, 76U, "MSPM0G3507 SIGNAL CONSOLE", 2U,
                      theme->accent, theme->background);
    Graphics_DrawText(24U, 106U, "SELECT AN ANALYSIS VIEW", 1U,
                      theme->secondaryText, theme->background);

    ST7796_FillRect(24U, 140U, 208U, 104U, theme->panelAlternate);
    ST7796_FillRect(24U, 140U, 5U, 104U, theme->accent);
    Graphics_DrawText(46U, 158U, "S1", 3U,
                      theme->accent, theme->panelAlternate);
    Graphics_DrawText(46U, 196U, "SPECTRUM", 2U,
                      theme->primaryText, theme->panelAlternate);

    ST7796_FillRect(248U, 140U, 208U, 104U, theme->panelAlternate);
    ST7796_FillRect(248U, 140U, 5U, 104U, COLOR_GOLD);
    Graphics_DrawText(270U, 158U, "S2", 3U,
                      COLOR_GOLD, theme->panelAlternate);
    Graphics_DrawText(270U, 196U, "PERIODIC", 2U,
                      theme->primaryText, theme->panelAlternate);

    Graphics_DrawText(24U, 278U, "READY - PRESS S1 OR S2", 1U,
                      theme->success, theme->background);
}

void UI_Init(void)
{
    ST7796_Init();
    show_welcome();
}

void UI_ShowSpectrum(void)
{
    PlotStyle style = PLOT_STYLE_DARK;

    UI_DrawPageFrame("SPECTRUM ANALYZER", "LIVE", &UI_THEME_DARK);
    UI_DrawCard(16U, 58U, 216U, 54U, "CARRIER", "50.0 KHZ",
                COLOR_CYAN, &UI_THEME_DARK);
    UI_DrawCard(248U, 58U, 216U, 54U, "AMPLITUDE", "200 MV",
                COLOR_GOLD, &UI_THEME_DARK);

    build_demo_spectrum();
    style.traceColor = COLOR_CYAN;
    style.drawZeroAxis = false;
    (void)Plot_DrawSpectrum(PLOT_X, PLOT_Y, PLOT_W, PLOT_H,
                            g_demoSpectrum, 128U, 100U, &style);
    Graphics_DrawText(24U, 128U, "MAGNITUDE", 1U,
                      UI_THEME_DARK.secondaryText, UI_THEME_DARK.panel);
    Graphics_DrawText(24U, 260U, "0", 1U,
                      UI_THEME_DARK.secondaryText, UI_THEME_DARK.panel);
    Graphics_DrawText(205U, 260U, "50", 1U,
                      COLOR_GOLD, UI_THEME_DARK.panel);
    Graphics_DrawText(374U, 260U, "100 KHZ", 1U,
                      UI_THEME_DARK.secondaryText, UI_THEME_DARK.panel);
}

void UI_ShowPeriodicSignal(void)
{
    PlotStyle style = PLOT_STYLE_DARK;

    UI_DrawPageFrame("PERIODIC SIGNAL", "STABLE", &UI_THEME_DARK);
    UI_DrawCard(16U, 58U, 216U, 54U, "FREQUENCY", "100 KHZ",
                COLOR_CYAN, &UI_THEME_DARK);
    UI_DrawCard(248U, 58U, 216U, 54U, "PEAK-PEAK", "200 MV",
                COLOR_GOLD, &UI_THEME_DARK);

    build_demo_waveform();
    style.traceColor = COLOR_CYAN;
    (void)Plot_DrawWaveform(PLOT_X, PLOT_Y, PLOT_W, PLOT_H,
                            g_demoWaveform, 128U, -120, 120, &style);
    Graphics_DrawText(24U, 128U, "+100 MV", 1U,
                      COLOR_GOLD, UI_THEME_DARK.panel);
    Graphics_DrawText(24U, 194U, "0 V", 1U,
                      UI_THEME_DARK.secondaryText, UI_THEME_DARK.panel);
    Graphics_DrawText(24U, 258U, "-100 MV", 1U,
                      COLOR_GOLD, UI_THEME_DARK.panel);
    Graphics_DrawText(354U, 258U, "10 US/DIV", 1U,
                      UI_THEME_DARK.secondaryText, UI_THEME_DARK.panel);
}

void UI_HandleKey(uint8_t key)
{
    if (key == 1U) {
        UI_ShowSpectrum();
    } else if (key == 2U) {
        UI_ShowPeriodicSignal();
    }
}
