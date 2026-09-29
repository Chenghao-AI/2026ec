/* Rabi 核心模块：OLED 菜单 UI 接口。 */
#pragma once

#include "rabi_err.h"

#if defined(__cplusplus)
extern "C"
{
#endif

typedef enum
{
    RABI_UI_ITEM_TYPE_TEXT,
    RABI_UI_ITEM_TYPE_NUMERIC,
    RABI_UI_ITEM_TYPE_LIST,
} rabi_ui_item_type_t;

typedef enum
{
    RABI_UI_ITEM_FLAG_READONLY = 0,
    RABI_UI_ITEM_FLAG_EDITABLE = 1 << 0,
    RABI_UI_ITEM_FLAG_IMMEDIATE = 1 << 1,
} rabi_ui_item_flag_t;

typedef enum
{
    RABI_UI_INPUT_UP,
    RABI_UI_INPUT_DOWN,
    RABI_UI_INPUT_ENTER,
    RABI_UI_INPUT_EXIT,
} rabi_ui_input_t;

typedef union {
    const char *text;
    float numeric_value;
    uint8_t list_index;
} rabi_ui_item_value_t;

typedef union {
    struct
    {
        float min;
        float max;
        uint8_t digit_int;
        uint8_t digit_dec;
        const char *unit;
    } numeric;
    struct
    {
        const char **items;
        uint8_t length;
    } list;
} rabi_ui_item_type_cfg_t;

typedef void (*rabi_ui_item_change_cb_t)(uint8_t index, rabi_ui_item_value_t value);

typedef struct
{
    const char *label;
    rabi_ui_item_value_t value_default;

    rabi_ui_item_type_t type;
    rabi_ui_item_type_cfg_t type_cfg;
    rabi_ui_item_flag_t flag;

    rabi_ui_item_change_cb_t cb;
} rabi_ui_item_cfg_t;

void rabi_ui_init(void);

rabi_err_t rabi_ui_add_item(uint8_t index, const rabi_ui_item_cfg_t *item_cfg);

rabi_err_t rabi_ui_remove_item(uint8_t index);

rabi_err_t rabi_ui_set_value(uint8_t index, rabi_ui_item_value_t new_value);

rabi_err_t rabi_ui_get_value(uint8_t index, rabi_ui_item_value_t *out_value);

void rabi_ui_render(void);

void rabi_ui_input(rabi_ui_input_t input);

#if defined(__cplusplus)
}
#endif
