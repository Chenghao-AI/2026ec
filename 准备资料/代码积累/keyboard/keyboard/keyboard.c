#include "keyboard.h"

#include "ti_msp_dl_config.h"

#define KEYBOARD_ROW_COUNT          (4U)
#define KEYBOARD_COLUMN_COUNT       (4U)
#define KEYBOARD_SETTLE_CYCLES      (CPUCLK_FREQ / 100000U) /* 10 us */
#define KEYBOARD_DEBOUNCE_CYCLES    (CPUCLK_FREQ / 100U)    /* 10 ms */

#define KEYBOARD_ALL_ROW_PINS                                              \
    (KEYBOARD_R1_PIN | KEYBOARD_R2_PIN | KEYBOARD_R3_PIN | KEYBOARD_R4_PIN)

#define KEYBOARD_ALL_COLUMN_PINS                                           \
    (KEYBOARD_C1_PIN | KEYBOARD_C2_PIN | KEYBOARD_C3_PIN | KEYBOARD_C4_PIN)

static const uint32_t g_keyboardRowPins[KEYBOARD_ROW_COUNT] = {
    KEYBOARD_R1_PIN,
    KEYBOARD_R2_PIN,
    KEYBOARD_R3_PIN,
    KEYBOARD_R4_PIN,
};

static const uint32_t g_keyboardColumnPins[KEYBOARD_COLUMN_COUNT] = {
    KEYBOARD_C1_PIN,
    KEYBOARD_C2_PIN,
    KEYBOARD_C3_PIN,
    KEYBOARD_C4_PIN,
};

static uint8_t keyboard_scan_raw(void)
{
    uint8_t detectedKey   = KEYBOARD_NO_KEY;
    uint8_t detectedCount = 0U;
    uint8_t row;
    uint8_t column;
    uint32_t columnLevels;

    /* A set bit releases an open-drain row; all rows idle high via pull-ups. */
    DL_GPIO_setPins(KEYBOARD_PORT, KEYBOARD_ALL_ROW_PINS);
    delay_cycles(KEYBOARD_SETTLE_CYCLES);

    for (row = 0U; row < KEYBOARD_ROW_COUNT; row++) {
        /* Select one row by driving only that open-drain output low. */
        DL_GPIO_clearPins(KEYBOARD_PORT, g_keyboardRowPins[row]);
        delay_cycles(KEYBOARD_SETTLE_CYCLES);

        columnLevels =
            DL_GPIO_readPins(KEYBOARD_PORT, KEYBOARD_ALL_COLUMN_PINS);

        for (column = 0U; column < KEYBOARD_COLUMN_COUNT; column++) {
            if ((columnLevels & g_keyboardColumnPins[column]) == 0U) {
                detectedCount++;
                detectedKey =
                    (uint8_t) ((row * KEYBOARD_COLUMN_COUNT) + column + 1U);
            }
        }

        /* Always release the selected row before scanning the next row. */
        DL_GPIO_setPins(KEYBOARD_PORT, g_keyboardRowPins[row]);
    }

    /* Keep the matrix electrically idle on every return path. */
    DL_GPIO_setPins(KEYBOARD_PORT, KEYBOARD_ALL_ROW_PINS);

    if (detectedCount != 1U) {
        return KEYBOARD_NO_KEY;
    }

    return detectedKey;
}

uint8_t keyboard_get_key(void)
{
    uint8_t firstSample = keyboard_scan_raw();

    if (firstSample == KEYBOARD_NO_KEY) {
        return KEYBOARD_NO_KEY;
    }

    delay_cycles(KEYBOARD_DEBOUNCE_CYCLES);

    if (keyboard_scan_raw() != firstSample) {
        return KEYBOARD_NO_KEY;
    }

    return firstSample;
}
