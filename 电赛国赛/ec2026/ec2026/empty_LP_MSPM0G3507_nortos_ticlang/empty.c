#include <stdbool.h>
#include <stddef.h>
#include "core/rabi_system.h"
#include "core/rabi_tick.h"
#include "core/rabi_event.h"
#include "core/rabi_keypad.h"
#include "core/rabi_ui.h"

static volatile bool s_flag_render = false;

typedef enum
{
    UI_ITEM_MODE,
    UI_ITEM_FREQ,
    UI_ITEM_KP,
    UI_ITEM_KI,
    UI_ITEM_KD,
} ui_item_index_t;

static void allow_render(void);
static void event_handler(rabi_event_base_t base, rabi_event_id_t id, void *param);
static void handle_ui_key(rabi_keypad_key_t key);
static void ui_item_change_handler(uint8_t index, rabi_ui_item_value_t value);
static void ui_init(void);

static const char *s_mode_items[] = {"OFF", "ON"};

static const rabi_ui_item_cfg_t item_cfg_mode = {
    .label = "Mode:",
    .value_default.list_index = 0,
    .type = RABI_UI_ITEM_TYPE_LIST,
    .type_cfg.list = {
        .items = s_mode_items,
        .length = 2,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE,
    .cb = ui_item_change_handler,
};

static const rabi_ui_item_cfg_t item_cfg_freq = {
    .label = "Freq:",
    .value_default.numeric_value = 8,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.0f,
        .max = 999.999f,
        .digit_int = 3,
        .digit_dec = 3,
        .unit = NULL,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE,
    .cb = ui_item_change_handler,
};

static const rabi_ui_item_cfg_t item_cfg_kp = {
    .label = "KP:",
    .value_default.numeric_value = 1.0f,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.0f,
        .max = 999.999f,
        .digit_int = 3,
        .digit_dec = 3,
        .unit = NULL,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE,
    .cb = ui_item_change_handler,
};

static const rabi_ui_item_cfg_t item_cfg_ki = {
    .label = "KI:",
    .value_default.numeric_value = 0.0f,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.0f,
        .max = 999.999f,
        .digit_int = 3,
        .digit_dec = 3,
        .unit = NULL,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE,
    .cb = ui_item_change_handler,
};

static const rabi_ui_item_cfg_t item_cfg_kd = {
    .label = "KD:",
    .value_default.numeric_value = 0.0f,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.0f,
        .max = 999.999f,
        .digit_int = 3,
        .digit_dec = 3,
        .unit = NULL,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE,
    .cb = ui_item_change_handler,
};

int main(void)
{
    rabi_system_init();
    rabi_keypad_init();
    ui_init();

    rabi_event_listen(RABI_KEYPAD_EVENT, RABI_EVENT_ID_ANY, event_handler);

    while (1)
    {
        rabi_system_loop();
        if (s_flag_render)
        {
            rabi_ui_render();
            s_flag_render = false;
        }
    }
}

static void allow_render(void)
{
    s_flag_render = true;
}

static void event_handler(rabi_event_base_t base, rabi_event_id_t id, void *param)
{
    if (base != RABI_KEYPAD_EVENT || param == NULL) return;

    rabi_keypad_key_t key = *(rabi_keypad_key_t *)param;

    if (id == RABI_KEYPAD_EVENT_PRESS)
    {
        handle_ui_key(key);
        s_flag_render = true;
    }
    else if (id == RABI_KEYPAD_EVENT_HOLD_REPEAT &&
             (key == 'A' || key == 'B'))
    {
        handle_ui_key(key);
        s_flag_render = true;
    }
}

static void handle_ui_key(rabi_keypad_key_t key)
{
    switch (key)
    {
    case 'A':
        rabi_ui_input(RABI_UI_INPUT_UP);
        break;

    case 'B':
        rabi_ui_input(RABI_UI_INPUT_DOWN);
        break;

    case 'C':
        rabi_ui_input(RABI_UI_INPUT_ENTER);
        break;

    case 'D':
        rabi_ui_input(RABI_UI_INPUT_EXIT);
        break;

    default:
        break;
    }
}

/*
 * 接入说明：
 *
 * 1. 当前条目没有设置 RABI_UI_ITEM_FLAG_IMMEDIATE，因此只有按 D 退出编辑
 *    时才会进入本函数。若希望每次按 A/B 调值后立即生效，可在对应条目的
 *    flag 中额外加入 RABI_UI_ITEM_FLAG_IMMEDIATE。
 * 2. 数值条目的新值读取 value.numeric_value；列表条目的新值读取
 *    value.list_index。
 * 3. 可以在对应 case 中直接调用控制函数，也可以更新控制模块的配置结构体。
 * 4. 如果需要调用 rabi_event_post()，事件参数必须指向模块级或静态存储，
 *    不要把 &value 直接放进事件队列，因为 value 在本函数返回后就失效了。
 * 5. 接入 optional/rabi_pid 后，KP/KI/KD 任意一项确认时都建议用
 *    rabi_ui_get_value() 重新读取三项，再一次调用 rabi_pid_set_gains()；完整示例
 *    和参数单位见 optional/rabi_pid.h，避免控制器使用半新半旧的一组参数。
 */
static void ui_item_change_handler(uint8_t index, rabi_ui_item_value_t value)
{
    (void)value;

    switch (index)
    {
    case UI_ITEM_MODE:
        /* 示例：control_set_enabled(value.list_index == 1); */
        break;

    case UI_ITEM_KP:
        /* 接入提示：重读 KP/KI/KD 后统一调用 rabi_pid_set_gains()。 */
        break;

    case UI_ITEM_KI:
        /* 接入提示：重读 KP/KI/KD 后统一调用 rabi_pid_set_gains()。 */
        break;

    case UI_ITEM_KD:
        /* 接入提示：重读 KP/KI/KD 后统一调用 rabi_pid_set_gains()。 */
        break;

    default:
        break;
    }
}

static void ui_init(void)
{
    rabi_ui_init();
    rabi_ui_add_item(UI_ITEM_MODE, &item_cfg_mode);
    rabi_ui_add_item(UI_ITEM_FREQ, &item_cfg_freq);
    rabi_ui_add_item(UI_ITEM_KP, &item_cfg_kp);
    rabi_ui_add_item(UI_ITEM_KI, &item_cfg_ki);
    rabi_ui_add_item(UI_ITEM_KD, &item_cfg_kd);
    rabi_tick_register(allow_render, 50);
    s_flag_render = true;
}
    