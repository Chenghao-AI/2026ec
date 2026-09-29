/* Rabi 核心模块：4x4 矩阵键盘实现。 */
#include <stdbool.h>
#include "rabi_keypad.h"
#include "rabi_tick.h"
#include "ti_msp_dl_config.h"

#if !defined(GPIO_KEYPAD_PORT) || !defined(GPIO_KEYPAD_ROW0_PIN) || \
    !defined(GPIO_KEYPAD_ROW1_PIN) || !defined(GPIO_KEYPAD_ROW2_PIN) || \
    !defined(GPIO_KEYPAD_ROW3_PIN) || !defined(GPIO_KEYPAD_COL0_PIN) || \
    !defined(GPIO_KEYPAD_COL1_PIN) || !defined(GPIO_KEYPAD_COL2_PIN) || \
    !defined(GPIO_KEYPAD_COL3_PIN)
#error "Configure the GPIO_KEYPAD pin group in SysConfig before building"
#endif

#define SCAN_ROW_PERIOD_MS 1U
#define SCAN_ROW_NUM 4U
#define SCAN_FRAME_MS (SCAN_ROW_PERIOD_MS * SCAN_ROW_NUM)
#define MS_TO_FRAME_TICKS(ms) (((ms) + SCAN_FRAME_MS - 1U) / SCAN_FRAME_MS)

#define DEBOUNCE_MS 20U
#define LONG_PRESS_MS 500U
#define HOLD_REPEAT_MS 100U

#define KEY_NONE 0xFFU
#define KEY_INVALID 0xFEU

#define ROW_PINS (GPIO_KEYPAD_ROW0_PIN | GPIO_KEYPAD_ROW1_PIN | \
                  GPIO_KEYPAD_ROW2_PIN | GPIO_KEYPAD_ROW3_PIN)

RABI_EVENT_DEFINE_BASE(RABI_KEYPAD_EVENT);

static const uint32_t s_row_pins[4] = {
    GPIO_KEYPAD_ROW0_PIN,
    GPIO_KEYPAD_ROW1_PIN,
    GPIO_KEYPAD_ROW2_PIN,
    GPIO_KEYPAD_ROW3_PIN,
};

static const uint32_t s_col_pins[4] = {
    GPIO_KEYPAD_COL0_PIN,
    GPIO_KEYPAD_COL1_PIN,
    GPIO_KEYPAD_COL2_PIN,
    GPIO_KEYPAD_COL3_PIN,
};

static rabi_keypad_key_t s_keymap[4][4] = {
    {'1', '2', '3', 'A'},
    {'4', '5', '6', 'B'},
    {'7', '8', '9', 'C'},
    {'*', '0', '#', 'D'},
};

static uint8_t s_candidate_key = KEY_NONE;
static uint8_t s_stable_key = KEY_NONE;
static uint8_t s_debounce_ticks;
static uint16_t s_hold_ticks;
static uint8_t s_scan_row;
static uint8_t s_scan_key;

static void timer_scan(void);
static bool scan_matrix(uint8_t *out_key);
static void set_stable_key(uint8_t new_key);
static void post_key_event(rabi_keypad_event_t event, uint8_t key);

void rabi_keypad_init(void)
{
    DL_GPIO_clearPins(GPIO_KEYPAD_PORT, ROW_PINS);
    DL_GPIO_disableOutput(GPIO_KEYPAD_PORT, ROW_PINS);

    s_candidate_key = KEY_NONE;
    s_stable_key = KEY_NONE;
    s_debounce_ticks = 0;
    s_hold_ticks = 0;
    s_scan_row = 0;
    s_scan_key = KEY_NONE;

    DL_GPIO_enableOutput(GPIO_KEYPAD_PORT, s_row_pins[s_scan_row]);
    rabi_tick_register(timer_scan, SCAN_ROW_PERIOD_MS);
}

void rabi_keypad_deinit(void)
{
    rabi_tick_unregister(timer_scan);
    DL_GPIO_disableOutput(GPIO_KEYPAD_PORT, ROW_PINS);

    s_candidate_key = KEY_NONE;
    s_stable_key = KEY_NONE;
    s_debounce_ticks = 0;
    s_hold_ticks = 0;
    s_scan_row = 0;
    s_scan_key = KEY_NONE;
}

static void timer_scan(void)
{
    uint8_t raw_key;
    if (!scan_matrix(&raw_key)) return;
    if (raw_key == KEY_INVALID) return;

    if (raw_key != s_candidate_key)
    {
        s_candidate_key = raw_key;
        s_debounce_ticks = 1;
    }
    else if (s_debounce_ticks < MS_TO_FRAME_TICKS(DEBOUNCE_MS))
    {
        s_debounce_ticks++;
    }

    if (s_candidate_key != s_stable_key &&
        s_debounce_ticks >= MS_TO_FRAME_TICKS(DEBOUNCE_MS))
    {
        set_stable_key(s_candidate_key);
        return;
    }

    if (s_stable_key == KEY_NONE || raw_key != s_stable_key) return;

    s_hold_ticks++;
    if (HOLD_REPEAT_MS &&
        s_hold_ticks > MS_TO_FRAME_TICKS(LONG_PRESS_MS) &&
        ((s_hold_ticks - MS_TO_FRAME_TICKS(LONG_PRESS_MS)) %
            MS_TO_FRAME_TICKS(HOLD_REPEAT_MS)) == 0)
    {
        post_key_event(RABI_KEYPAD_EVENT_HOLD_REPEAT, s_stable_key);
    }
}

static bool scan_matrix(uint8_t *out_key)
{
    uint32_t col_state = DL_GPIO_readPins(GPIO_KEYPAD_PORT,
        GPIO_KEYPAD_COL0_PIN | GPIO_KEYPAD_COL1_PIN |
        GPIO_KEYPAD_COL2_PIN | GPIO_KEYPAD_COL3_PIN);

    for (uint8_t col = 0; col < 4; col++)
    {
        if (col_state & s_col_pins[col]) continue;

        uint8_t key = (s_scan_row * 4U) + col;
        if (s_scan_key == KEY_NONE)
        {
            s_scan_key = key;
        }
        else
        {
            s_scan_key = KEY_INVALID;
        }
    }

    DL_GPIO_disableOutput(GPIO_KEYPAD_PORT, s_row_pins[s_scan_row]);

    s_scan_row++;
    bool is_frame_ready = s_scan_row >= SCAN_ROW_NUM;
    if (is_frame_ready)
    {
        *out_key = s_scan_key;
        s_scan_row = 0;
        s_scan_key = KEY_NONE;
    }

    DL_GPIO_enableOutput(GPIO_KEYPAD_PORT, s_row_pins[s_scan_row]);
    return is_frame_ready;
}

static void set_stable_key(uint8_t new_key)
{
    uint8_t old_key = s_stable_key;

    if (old_key != KEY_NONE)
    {
        post_key_event(RABI_KEYPAD_EVENT_RELEASE, old_key);
        if (LONG_PRESS_MS &&
            s_hold_ticks >= MS_TO_FRAME_TICKS(LONG_PRESS_MS))
        {
            post_key_event(RABI_KEYPAD_EVENT_LONG_PRESS, old_key);
        }
        else
        {
            post_key_event(RABI_KEYPAD_EVENT_CLICK, old_key);
        }
    }

    s_stable_key = new_key;
    s_hold_ticks = 0;

    if (new_key != KEY_NONE)
    {
        post_key_event(RABI_KEYPAD_EVENT_PRESS, new_key);
    }
}

static void post_key_event(rabi_keypad_event_t event, uint8_t key)
{
    rabi_event_post(RABI_KEYPAD_EVENT, event,
        &s_keymap[key >> 2][key & 0x03U]);
}
