/* Rabi 核心模块：OLED 菜单 UI 实现。 */
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include "rabi_ui.h"
#include "rabi_oled.h"
#include "rabi_tick.h"
#include "rabi_utils.h"

#define MAX_ITEMS 8
#define MAX_VIEW_ROW 4
#define MAX_PART_LEN 6
#define LEN_ROW_CHAR 15

#define TICK_MS 50
#define BLINK_MS 500
#define IDLE_MS 10000

typedef struct
{
    const rabi_ui_item_cfg_t *cfg;
    rabi_ui_item_value_t value;
} item_rt_t;

static item_rt_t s_items[MAX_ITEMS];

static uint8_t s_cursor = 0;
static uint8_t s_top_cursor = 0;
static volatile int8_t s_focus = -1;
static volatile uint8_t s_blink_tick = 0;
static volatile uint16_t s_idle_tick = 0;
static volatile bool s_is_active = false;

static void move_cursor(int8_t direction);
static void move_focus(int8_t direction);
static void handle_edit(int8_t num_step);
static float calc_step(uint8_t focus, uint8_t digit_dec);
static void split_float(float value, uint8_t digit_decimal, int *out_int, int *out_decimal);
static void tick_cb(void);

void rabi_ui_init(void)
{
    rabi_oled_init();
    rabi_tick_register(tick_cb, TICK_MS);
}

rabi_err_t rabi_ui_add_item(uint8_t index, const rabi_ui_item_cfg_t *item_cfg)
{
    if (index >= MAX_ITEMS || !item_cfg) return RABI_ERR_INVALID_ARG;

    s_items[index].cfg = item_cfg;
    s_items[index].value = item_cfg->value_default;

    return RABI_ERR_OK;
}

rabi_err_t rabi_ui_remove_item(uint8_t index)
{
    if (index >= MAX_ITEMS) return RABI_ERR_INVALID_ARG;

    s_items[index].cfg = NULL;

    return RABI_ERR_OK;
}

rabi_err_t rabi_ui_set_value(uint8_t index, rabi_ui_item_value_t new_value)
{
    if (index >= MAX_ITEMS || !s_items[index].cfg) return RABI_ERR_INVALID_ARG;

    s_items[index].value = new_value;

    return RABI_ERR_OK;
}

rabi_err_t rabi_ui_get_value(uint8_t index, rabi_ui_item_value_t *out_value)
{
    if (index >= MAX_ITEMS || !s_items[index].cfg) return RABI_ERR_INVALID_ARG;

    *out_value = s_items[index].value;

    return RABI_ERR_OK;
}

void rabi_ui_render(void)
{
    for (uint8_t i = 0; i < MAX_VIEW_ROW; i++)
    {
        uint8_t row = s_top_cursor + i;

        if (!s_items[row].cfg)
        {
            rabi_oled_print(i, "");
            continue;
        }

        item_rt_t *item = &s_items[row];

        char row_str[LEN_ROW_CHAR + 1];
        memset(row_str, ' ', LEN_ROW_CHAR);
        row_str[LEN_ROW_CHAR] = '\0';

        uint8_t row_index = 0;

        if (s_is_active && row == s_cursor) row_str[row_index++] = (s_blink_tick < BLINK_MS / TICK_MS) ? '>' : ' ';
        memcpy(&row_str[row_index], item->cfg->label, strlen(item->cfg->label));

        if (row == s_cursor &&
            s_focus >= 0 &&
            !(item->cfg->flag & RABI_UI_ITEM_FLAG_IMMEDIATE) &&
            (s_blink_tick >= BLINK_MS / TICK_MS))
        {
            rabi_oled_clear_focus();
            goto end_print;
        }

        char value_str[LEN_ROW_CHAR + 1] = {0};
        switch (item->cfg->type)
        {
        case RABI_UI_ITEM_TYPE_TEXT:
            snprintf(value_str, sizeof(value_str), "%s", item->value.text);
            break;

        case RABI_UI_ITEM_TYPE_NUMERIC: {
            int part_int = 0;
            int part_dec = 0;
            uint8_t digit_int = item->cfg->type_cfg.numeric.digit_int;
            uint8_t digit_dec = item->cfg->type_cfg.numeric.digit_dec;
            digit_int = digit_int > MAX_PART_LEN ? MAX_PART_LEN : digit_int;
            digit_dec = digit_dec > MAX_PART_LEN ? MAX_PART_LEN : digit_dec;

            split_float(item->value.numeric_value, digit_dec, &part_int, &part_dec);

            const char *unit = item->cfg->type_cfg.numeric.unit ? item->cfg->type_cfg.numeric.unit : "";
            if (digit_dec)
            {
                snprintf(value_str, sizeof(value_str), "%*d.%0*d%s", digit_int, part_int, digit_dec, part_dec, unit);
            }
            else
            {
                snprintf(value_str, sizeof(value_str), "%*d%s", digit_int, part_int, unit);
            }

            if (row != s_cursor) break;

            if (s_focus < 0)
            {
                rabi_oled_clear_focus();
            }
            else
            {
                uint8_t focus_col = LEN_ROW_CHAR - strlen(unit) - s_focus - (s_focus >= digit_dec) - 1;
                rabi_oled_set_focus(i, focus_col);
            }
            break;
        }

        case RABI_UI_ITEM_TYPE_LIST:
            snprintf(value_str, sizeof(value_str), "%s", item->cfg->type_cfg.list.items[item->value.list_index]);
            break;
        }

        row_index = LEN_ROW_CHAR - strlen(value_str);
        row_index = row_index > 0 ? row_index : 1;
        memcpy(&row_str[row_index], value_str, strlen(value_str));

    end_print:
        rabi_oled_print(i, row_str);
    }
}

void rabi_ui_input(rabi_ui_input_t input)
{
    if (!s_items[s_cursor].cfg) return;

    s_idle_tick = 0;
    if (!s_is_active)
    {
        s_is_active = true;
        return;
    }

    switch (input)
    {
    case RABI_UI_INPUT_UP:
        if (s_focus < 0)
            move_cursor(-1);
        else
            handle_edit(1);
        break;

    case RABI_UI_INPUT_DOWN:
        if (s_focus < 0)
            move_cursor(1);
        else
            handle_edit(-1);
        break;

    case RABI_UI_INPUT_ENTER:
        if (s_items[s_cursor].cfg->flag & RABI_UI_ITEM_FLAG_EDITABLE)
        {
            move_focus(-1);
        }
        break;

    case RABI_UI_INPUT_EXIT:
        if (s_focus < 0)
        {
            s_is_active = false;
            s_idle_tick = 0;
        }
        else
        {
            s_focus = -1;
            s_blink_tick = 0;
            if (!(s_items[s_cursor].cfg->flag & RABI_UI_ITEM_FLAG_IMMEDIATE) && s_items[s_cursor].cfg->cb)
            {
                s_items[s_cursor].cfg->cb(s_cursor, s_items[s_cursor].value);
            }
        }
        break;
    }
}

static void move_cursor(int8_t direction)
{
    int8_t next = s_cursor;

    while (1)
    {
        next += direction;

        if (next >= MAX_ITEMS || next < 0) break;

        if (s_items[next].cfg != NULL)
        {
            s_cursor = next;
            break;
        }
    }

    if (s_cursor < s_top_cursor)
    {
        s_top_cursor = s_cursor;
    }
    else if (s_cursor >= s_top_cursor + MAX_VIEW_ROW)
    {
        s_top_cursor = s_cursor - MAX_VIEW_ROW + 1;
    }
}

static void move_focus(int8_t direction)
{
    if (s_items[s_cursor].cfg->type != RABI_UI_ITEM_TYPE_NUMERIC)
    {
        s_focus = 0;
        return;
    }

    uint8_t digit_int = s_items[s_cursor].cfg->type_cfg.numeric.digit_int;
    uint8_t digit_dec = s_items[s_cursor].cfg->type_cfg.numeric.digit_dec;

    if (s_focus < 0)
    {
        s_focus = digit_int + digit_dec - 1;
    }
    else
    {
        s_focus += direction;
        if (s_focus >= digit_int + digit_dec) s_focus = 0;
        if (s_focus < 0) s_focus = digit_int + digit_dec - 1;
    }
}

static void handle_edit(int8_t num_step)
{
    item_rt_t *item = &s_items[s_cursor];

    switch (item->cfg->type)
    {
    case RABI_UI_ITEM_TYPE_NUMERIC: {
        float step = calc_step(s_focus, item->cfg->type_cfg.numeric.digit_dec);
        float min = item->cfg->type_cfg.numeric.min;
        float max = item->cfg->type_cfg.numeric.max;

        float new_value = item->value.numeric_value + (num_step * step);
        item->value.numeric_value = rabi_utils_clamp_float(new_value, min, max);
        break;
    }

    case RABI_UI_ITEM_TYPE_LIST: {
        uint8_t length = item->cfg->type_cfg.list.length;

        int8_t new_index = item->value.list_index + num_step;
        item->value.list_index = new_index >= 0 ? (new_index < length ? new_index : 0) : length - 1;
        break;
    }

    default:
        break;
    }

    if ((item->cfg->flag & RABI_UI_ITEM_FLAG_IMMEDIATE) && item->cfg->cb)
    {
        item->cfg->cb(s_cursor, item->value);
    }
}

static float calc_step(uint8_t focus, uint8_t digit_dec)
{
    static const float step_lut[MAX_PART_LEN << 1] = {0.000001f, 0.00001f, 0.0001f, 0.001f, 0.01f, 0.1f, 1.0f, 10.0f, 100.0f, 1000.0f, 10000.0f, 100000.0f};

    int8_t power = focus - digit_dec;
    int8_t index = rabi_utils_clamp_int(power + MAX_PART_LEN, 0, (MAX_PART_LEN << 1) - 1);

    return step_lut[index];
}

static void split_float(float value, uint8_t digit_decimal, int *out_int, int *out_decimal)
{
    int multiplier = 1;
    for (uint8_t i = 0; i < digit_decimal; i++) multiplier *= 10;

    float rounding_offset = value > 0 ? 0.5f : -0.5f;
    int value_int = (int)(value * multiplier + rounding_offset);

    *out_int = value_int / multiplier;
    *out_decimal = value_int % multiplier;

    *out_decimal = *out_decimal >= 0 ? *out_decimal : -*out_decimal;
}

static void tick_cb(void)
{
    if (s_focus >= 0)
    {
        s_blink_tick++;
        s_blink_tick = (s_blink_tick == (BLINK_MS / TICK_MS) << 1) ? 0 : s_blink_tick;
    }
    if (s_is_active)
    {
        s_idle_tick++;
        if (s_idle_tick >= IDLE_MS / TICK_MS)
        {
            s_focus = -1;
            s_blink_tick = 0;
            s_is_active = false;
            s_idle_tick = 0;
        }
    }
}
