#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "ti_msp_dl_config.h"
#include "core/rabi_event.h"
#include "core/rabi_keypad.h"
#include "core/rabi_system.h"
#include "core/rabi_tick.h"
#include "core/rabi_ui.h"
#include "optional/rabi_ad9850.h"

/*
 * AD9850 + OLED UI 独立联调入口
 * ============================
 *
 * 使用本入口时，在 CCS 中把根目录 empty.c 设为 Exclude from Build，并把本文件、
 * optional/rabi_gpio_serial.c、optional/rabi_ad9850.c 加入当前 Build。
 *
 * SysConfig 新建 GPIO Pin Group：GPIO_AD9850，四个输出均为初始 Low：
 *
 *     DATA  = PA25  -> 模块 DATA / D7 / Serial Data
 *     W_CLK = PA26  -> 模块 W_CLK
 *     FQ_UD = PA27  -> 模块 FQ_UD / UPDATE
 *     RESET = PA8   -> 模块 RESET
 *
 * 详细接线、电平转换、示波器和 SysConfig 步骤见：
 * optional/AD9850_UI_QUICKSTART.md
 */
#if !defined(GPIO_AD9850_PORT) || !defined(GPIO_AD9850_DATA_PIN) || \
    !defined(GPIO_AD9850_W_CLK_PIN) || \
    !defined(GPIO_AD9850_FQ_UD_PIN) || \
    !defined(GPIO_AD9850_RESET_PIN)
#error "Configure the GPIO_AD9850 pin group in SysConfig before building"
#endif

#define AD9850_REFERENCE_CLOCK_HZ 125000000U
#define AD9850_DEFAULT_FREQUENCY_HZ 1000000U

/*
 * 每段 GPIO 时序约 1 us，远慢于 AD9850 的 ns 级最低脉宽，适合杜邦线首次联调。
 * 一次 40-bit 更新约百余 us，UI 每按一次 A/B 都可以立即发送，不会明显卡顿。
 */
#define AD9850_GPIO_HALF_PERIOD_CYCLES (CPUCLK_FREQ / 1000000U)

static volatile bool s_render_due;
static rabi_ad9850_t s_dds;
static bool s_dds_ready;

typedef enum
{
    UI_ITEM_OUTPUT,
    UI_ITEM_FREQUENCY,
    UI_ITEM_STATE,
} ui_item_index_t;

static void allow_render(void);
static void event_handler(rabi_event_base_t base, rabi_event_id_t id, void *param);
static void handle_ui_key(rabi_keypad_key_t key);
static void ui_item_change_handler(uint8_t index, rabi_ui_item_value_t value);
static void ui_init(void);
static void dds_init(void);
static void set_state_text(const char *text);

static const rabi_ad9850_cfg_t s_dds_cfg = {
    .serial = {
        .data = {GPIO_AD9850_PORT, GPIO_AD9850_DATA_PIN},
        .clock = {GPIO_AD9850_PORT, GPIO_AD9850_W_CLK_PIN},
        .clock_idle_high = false,
        .half_period_cycles = AD9850_GPIO_HALF_PERIOD_CYCLES,
    },
    .fq_ud = {GPIO_AD9850_PORT, GPIO_AD9850_FQ_UD_PIN},
    .reset = {GPIO_AD9850_PORT, GPIO_AD9850_RESET_PIN},
    .reference_clock_hz = AD9850_REFERENCE_CLOCK_HZ,
    .amplitude_cb = NULL,
    .amplitude_context = NULL,
};

static const char *s_output_items[] = {"OFF", "ON"};

static const rabi_ui_item_cfg_t s_item_output = {
    .label = "Output:",
    .value_default.list_index = 1U,
    .type = RABI_UI_ITEM_TYPE_LIST,
    .type_cfg.list = {
        .items = s_output_items,
        .length = 2U,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE | RABI_UI_ITEM_FLAG_IMMEDIATE,
    .cb = ui_item_change_handler,
};

/*
 * UI 以 kHz 显示，保留 0.1 kHz，因此最低调节步进为 100 Hz。
 * 按 C 选择数位，A/B 每改变一次都会立刻调用 AD9850 更新频率。
 * 上限暂定 20 MHz，便于普通模块/示波器联调并避开接近 Nyquist 的严重镜像。
 */
static const rabi_ui_item_cfg_t s_item_frequency = {
    .label = "Freq:",
    .value_default.numeric_value =
        (float)AD9850_DEFAULT_FREQUENCY_HZ / 1000.0f,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.1f,
        .max = 20000.0f,
        .digit_int = 5U,
        .digit_dec = 1U,
        .unit = "kHz",
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE | RABI_UI_ITEM_FLAG_IMMEDIATE,
    .cb = ui_item_change_handler,
};

static const rabi_ui_item_cfg_t s_item_state = {
    .label = "State:",
    .value_default.text = "BOOT",
    .type = RABI_UI_ITEM_TYPE_TEXT,
    .flag = RABI_UI_ITEM_FLAG_READONLY,
    .cb = NULL,
};

int main(void)
{
    rabi_system_init();
    rabi_keypad_init();
    ui_init();
    dds_init();

    (void)rabi_event_listen(
        RABI_KEYPAD_EVENT, RABI_EVENT_ID_ANY, event_handler);
    (void)rabi_tick_register(allow_render, 50U);
    s_render_due = true;

    while (1)
    {
        rabi_system_loop();
        if (s_render_due)
        {
            s_render_due = false;
            rabi_ui_render();
        }
    }
}

/* SysTick ISR 上下文只置刷新标志，不在这里操作 AD9850 或 OLED。 */
static void allow_render(void)
{
    s_render_due = true;
}

static void event_handler(rabi_event_base_t base, rabi_event_id_t id, void *param)
{
    if (base != RABI_KEYPAD_EVENT || param == NULL) return;

    rabi_keypad_key_t key = *(rabi_keypad_key_t *)param;
    if (id == RABI_KEYPAD_EVENT_PRESS ||
        (id == RABI_KEYPAD_EVENT_HOLD_REPEAT &&
         (key == 'A' || key == 'B')))
    {
        handle_ui_key(key);
        s_render_due = true;
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

static void ui_item_change_handler(uint8_t index, rabi_ui_item_value_t value)
{
    if (!s_dds_ready)
    {
        set_state_text("DDS ERR");
        return;
    }

    rabi_err_t err = RABI_ERR_OK;
    switch (index)
    {
    case UI_ITEM_OUTPUT:
        err = rabi_ad9850_set_output_enabled(
            &s_dds, value.list_index == 1U);
        break;

    case UI_ITEM_FREQUENCY: {
        /* kHz -> Hz，+0.5f 让 float 到整数采用四舍五入而不是直接截断。 */
        uint32_t frequency_hz =
            (uint32_t)(value.numeric_value * 1000.0f + 0.5f);
        err = rabi_ad9850_set_frequency(&s_dds, frequency_hz);
        break;
    }

    default:
        return;
    }

    set_state_text(err == RABI_ERR_OK ? "OK" : "DDS ERR");
}

static void ui_init(void)
{
    rabi_ui_init();
    (void)rabi_ui_add_item(UI_ITEM_OUTPUT, &s_item_output);
    (void)rabi_ui_add_item(UI_ITEM_FREQUENCY, &s_item_frequency);
    (void)rabi_ui_add_item(UI_ITEM_STATE, &s_item_state);
}

static void dds_init(void)
{
    rabi_err_t err = rabi_ad9850_init(&s_dds, &s_dds_cfg);
    if (err == RABI_ERR_OK)
    {
        err = rabi_ad9850_set_frequency(
            &s_dds, AD9850_DEFAULT_FREQUENCY_HZ);
    }
    if (err == RABI_ERR_OK)
    {
        err = rabi_ad9850_set_output_enabled(&s_dds, true);
    }

    s_dds_ready = err == RABI_ERR_OK;
    if (!s_dds_ready && s_dds.initialized)
    {
        (void)rabi_ad9850_set_output_enabled(&s_dds, false);
    }
    set_state_text(s_dds_ready ? "OK" : "DDS ERR");
}

static void set_state_text(const char *text)
{
    (void)rabi_ui_set_value(UI_ITEM_STATE,
        (rabi_ui_item_value_t){.text = text});
}
