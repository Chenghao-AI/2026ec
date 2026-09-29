#include "keypad.h"

#include "ti_msp_dl_config.h"

static const uint32_t g_columnPins[4] = {
    KEYPAD_COLS_COL1_PIN,
    KEYPAD_COLS_COL2_PIN,
    KEYPAD_COLS_COL3_PIN,
    KEYPAD_COLS_COL4_PIN
};

/* Top row to bottom row: S1..S4, S5..S8, S9..S12, S13..S16. */
static const uint32_t g_rowPins[4] = {
    KEYPAD_ROWS_ROW1_PIN,
    KEYPAD_ROWS_ROW2_PIN,
    KEYPAD_ROWS_ROW3_PIN,
    KEYPAD_ROWS_ROW4_PIN
};

static uint8_t g_candidate;
static uint8_t g_stableKey;
static uint8_t g_stableCount;

static uint8_t keypad_scan_raw(void)
{
    const uint32_t allColumns = KEYPAD_COLS_COL1_PIN |
                                KEYPAD_COLS_COL2_PIN |
                                KEYPAD_COLS_COL3_PIN |
                                KEYPAD_COLS_COL4_PIN;
    uint8_t column;
    uint8_t row;
    uint8_t found = KEYPAD_NONE;
    uint32_t inputs;

    DL_GPIO_setPins(KEYPAD_COLS_PORT, allColumns);
    for (column = 0U; column < 4U; column++) {
        DL_GPIO_clearPins(KEYPAD_COLS_PORT, g_columnPins[column]);
        delay_cycles(320U);
        inputs = DL_GPIO_readPins(KEYPAD_ROWS_PORT,
                                  KEYPAD_ROWS_ROW1_PIN |
                                  KEYPAD_ROWS_ROW2_PIN |
                                  KEYPAD_ROWS_ROW3_PIN |
                                  KEYPAD_ROWS_ROW4_PIN);

        for (row = 0U; row < 4U; row++) {
            if ((inputs & g_rowPins[row]) == 0U) {
                uint8_t key = (uint8_t)(row * 4U + column + 1U);
                if ((found != KEYPAD_NONE) && (found != key)) {
                    DL_GPIO_setPins(KEYPAD_COLS_PORT, allColumns);
                    return KEYPAD_NONE;
                }
                found = key;
            }
        }
        DL_GPIO_setPins(KEYPAD_COLS_PORT, g_columnPins[column]);
    }
    return found;
}

void Keypad_Init(void)
{
    DL_GPIO_setPins(KEYPAD_COLS_PORT,
                    KEYPAD_COLS_COL1_PIN |
                    KEYPAD_COLS_COL2_PIN |
                    KEYPAD_COLS_COL3_PIN |
                    KEYPAD_COLS_COL4_PIN);
    g_candidate = KEYPAD_NONE;
    g_stableKey = KEYPAD_NONE;
    g_stableCount = 0U;
}

uint8_t Keypad_GetPress(void)
{
    uint8_t raw = keypad_scan_raw();

    if (raw != g_candidate) {
        g_candidate = raw;
        g_stableCount = 1U;
        return KEYPAD_NONE;
    }

    if (g_stableCount < 4U) {
        g_stableCount++;
    }

    if ((g_stableCount >= 4U) && (g_stableKey != g_candidate)) {
        g_stableKey = g_candidate;
        if (g_stableKey != KEYPAD_NONE) {
            return g_stableKey;
        }
    }
    return KEYPAD_NONE;
}
