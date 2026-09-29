/*
 * 2024 TI 杯模拟邀请赛 B 题综合示例总入口。
 *
 * 使用方法：在 CCS 中把工程根目录的 empty.c 设为 Exclude from Build，再把本目录
 * 的 main.c、demo_agc.c、demo_hw.c 加入当前构建。完整接线、SysConfig 和调试顺序
 * 见 README.md 与 SYSCONFIG.md。
 */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "demo_agc.h"
#include "demo_config.h"
#include "demo_hw.h"
#include "../../core/rabi_event.h"
#include "../../core/rabi_keypad.h"
#include "../../core/rabi_system.h"
#include "../../core/rabi_tick.h"
#include "../../core/rabi_ui.h"

typedef enum
{
    UI_ITEM_MODE,
    UI_ITEM_TARGET,
    UI_ITEM_POWER,
    UI_ITEM_FREQUENCY,
    UI_ITEM_CONTROL,
    UI_ITEM_STATE,
} ui_item_index_t;

static void app_tick(void);
static void event_handler(rabi_event_base_t base, rabi_event_id_t id, void *param);
static void handle_ui_key(rabi_keypad_key_t key);
static void ui_item_change_handler(uint8_t index, rabi_ui_item_value_t value);
static void ui_init(void);
static void app_set_enabled(bool enabled);
static void run_measurement_and_control(void);
static void enter_safe_fault(const char *state_text);
static void update_result_ui(const demo_agc_result_t *result);

static demo_agc_t s_agc;
static bool s_agc_ready;
static bool s_enabled;
static volatile bool s_render_due;
static volatile bool s_control_due;
static uint8_t s_app_tick_divider;

/* DMA 要求 4-byte 对齐；2048 点占 4096 bytes。 */
static uint16_t s_samples[DEMO_SAMPLE_COUNT] __attribute__((aligned(4)));

static const demo_agc_cfg_t s_agc_cfg = {
    .sample_rate_hz = DEMO_SAMPLE_RATE_HZ,
    .control_period_ms = DEMO_CONTROL_PERIOD_MS,
    .adc_reference_mv = DEMO_ADC_REFERENCE_MV,
    .adc_full_scale_raw = DEMO_ADC_FULL_SCALE_RAW,
    .sense_gain_numerator = DEMO_SENSE_GAIN_NUMERATOR,
    .sense_gain_denominator = DEMO_SENSE_GAIN_DENOMINATOR,
    .voltage_cal_numerator = DEMO_VOLTAGE_CAL_NUMERATOR,
    .voltage_cal_denominator = DEMO_VOLTAGE_CAL_DENOMINATOR,
    .load_resistance_milliohm = DEMO_LOAD_RESISTANCE_MILLIOHM,
    .power_min_mw = DEMO_POWER_MIN_MW,
    .power_max_mw = DEMO_POWER_MAX_MW,
    .power_step_mw = DEMO_POWER_STEP_MW,
    .control_min_mv = DEMO_CONTROL_MIN_MV,
    .control_max_mv = DEMO_CONTROL_MAX_MV,
    .control_start_mv = DEMO_CONTROL_START_MV,
    .kp = DEMO_PID_KP,
    .ki = DEMO_PID_KI,
    .kd = DEMO_PID_KD,
    .power_ema_alpha = DEMO_POWER_EMA_ALPHA,
    .control_rise_mv_per_step = DEMO_CONTROL_RISE_MV_PER_STEP,
    .control_fall_mv_per_step = DEMO_CONTROL_FALL_MV_PER_STEP,
    .settle_confirm_blocks = DEMO_SETTLE_CONFIRM_BLOCKS,
    .frequency_hysteresis_raw = DEMO_FREQUENCY_HYSTERESIS_RAW,
};

static const char *s_mode_items[] = {"OFF", "AUTO"};
static const char *s_target_items[] = {
    "0.2W", "0.4W", "0.6W", "0.8W", "1.0W",
    "1.2W", "1.4W", "1.6W", "1.8W", "2.0W",
};
static const uint16_t s_target_mw[] = {
    200U, 400U, 600U, 800U, 1000U,
    1200U, 1400U, 1600U, 1800U, 2000U,
};

static const rabi_ui_item_cfg_t s_item_mode = {
    .label = "Mode:",
    .value_default.list_index = 0U,
    .type = RABI_UI_ITEM_TYPE_LIST,
    .type_cfg.list = {
        .items = s_mode_items,
        .length = 2U,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE,
    .cb = ui_item_change_handler,
};

static const rabi_ui_item_cfg_t s_item_target = {
    .label = "Set:",
    .value_default.list_index = 9U,
    .type = RABI_UI_ITEM_TYPE_LIST,
    .type_cfg.list = {
        .items = s_target_items,
        .length = 10U,
    },
    .flag = RABI_UI_ITEM_FLAG_EDITABLE,
    .cb = ui_item_change_handler,
};

static const rabi_ui_item_cfg_t s_item_power = {
    .label = "Pout:",
    .value_default.numeric_value = 0.0f,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.0f,
        .max = 9.99f,
        .digit_int = 1U,
        .digit_dec = 2U,
        .unit = "W",
    },
    .flag = RABI_UI_ITEM_FLAG_READONLY,
    .cb = NULL,
};

static const rabi_ui_item_cfg_t s_item_frequency = {
    .label = "Freq:",
    .value_default.numeric_value = 0.0f,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.0f,
        .max = 99999.0f,
        .digit_int = 5U,
        .digit_dec = 0U,
        .unit = "Hz",
    },
    .flag = RABI_UI_ITEM_FLAG_READONLY,
    .cb = NULL,
};

static const rabi_ui_item_cfg_t s_item_control = {
    .label = "Ctrl:",
    .value_default.numeric_value = 0.0f,
    .type = RABI_UI_ITEM_TYPE_NUMERIC,
    .type_cfg.numeric = {
        .min = 0.0f,
        .max = 3300.0f,
        .digit_int = 4U,
        .digit_dec = 0U,
        .unit = "mV",
    },
    .flag = RABI_UI_ITEM_FLAG_READONLY,
    .cb = NULL,
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
    rabi_event_listen(RABI_KEYPAD_EVENT, RABI_EVENT_ID_ANY, event_handler);

    s_agc_ready = demo_agc_init(&s_agc, &s_agc_cfg) == RABI_ERR_OK;
    if (!s_agc_ready)
    {
        enter_safe_fault("AGC ERR");
    }
    else if (demo_hw_init() != RABI_ERR_OK)
    {
        /* 完成 SysConfig 并将 DEMO_AGC_HW_READY 改为 1 后，此状态才会变为 OFF。 */
        enter_safe_fault("CFG");
    }
    else
    {
        app_set_enabled(false);
    }

    (void)rabi_tick_register(app_tick, 50U);
    s_render_due = true;
    s_control_due = true;

    while (1)
    {
        rabi_system_loop();

        if (s_control_due)
        {
            s_control_due = false;
            run_measurement_and_control();
        }

        if (s_render_due)
        {
            s_render_due = false;
            rabi_ui_render();
        }
    }
}

/* SysTick ISR 上下文：只置标志，不采 ADC、不算 RMS、不刷 OLED。 */
static void app_tick(void)
{
    s_render_due = true;
    s_app_tick_divider++;
    if (s_app_tick_divider >= DEMO_CONTROL_PERIOD_MS / 50U)
    {
        s_app_tick_divider = 0U;
        s_control_due = true;
    }
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
    switch (index)
    {
    case UI_ITEM_MODE:
        app_set_enabled(value.list_index == 1U);
        break;

    case UI_ITEM_TARGET:
        if (value.list_index <
            sizeof(s_target_mw) / sizeof(s_target_mw[0]))
        {
            /*
             * 比赛时若“设定完成后还要触发记录/蜂鸣/继电器”等动作，就放在这里；
             * 不要在 UI 回调中做长时间阻塞，复杂动作改为置标志或投递静态事件。
             */
            (void)demo_agc_set_target_mw(
                &s_agc, s_target_mw[value.list_index]);
        }
        break;

    default:
        break;
    }
}

static void ui_init(void)
{
    rabi_ui_init();
    (void)rabi_ui_add_item(UI_ITEM_MODE, &s_item_mode);
    (void)rabi_ui_add_item(UI_ITEM_TARGET, &s_item_target);
    (void)rabi_ui_add_item(UI_ITEM_POWER, &s_item_power);
    (void)rabi_ui_add_item(UI_ITEM_FREQUENCY, &s_item_frequency);
    (void)rabi_ui_add_item(UI_ITEM_CONTROL, &s_item_control);
    (void)rabi_ui_add_item(UI_ITEM_STATE, &s_item_state);
}

static void app_set_enabled(bool enabled)
{
    if (!s_agc_ready || !demo_hw_is_ready())
    {
        s_enabled = false;
        demo_hw_set_amplifier_enabled(false);
        (void)rabi_ui_set_value(UI_ITEM_MODE,
            (rabi_ui_item_value_t){.list_index = 0U});
        (void)rabi_ui_set_value(UI_ITEM_STATE,
            (rabi_ui_item_value_t){.text = "CFG"});
        return;
    }

    if (!enabled)
    {
        /* 先关功率级，再清控制电压；任何软件错误都走相同的安全顺序。 */
        demo_hw_set_amplifier_enabled(false);
        (void)demo_hw_set_control_mv(DEMO_CONTROL_MIN_MV);
        (void)demo_agc_set_enabled(&s_agc, false);
        s_enabled = false;
        (void)rabi_ui_set_value(UI_ITEM_STATE,
            (rabi_ui_item_value_t){.text = "OFF"});
        return;
    }

    /* 先确保最小增益，再复位控制器，最后解除 TPA2000D1 关断。 */
    if (demo_hw_set_control_mv(DEMO_CONTROL_MIN_MV) != RABI_ERR_OK ||
        demo_agc_set_enabled(&s_agc, true) != RABI_ERR_OK)
    {
        enter_safe_fault("DAC ERR");
        return;
    }
    demo_hw_set_amplifier_enabled(true);
    s_enabled = true;
    (void)rabi_ui_set_value(UI_ITEM_STATE,
        (rabi_ui_item_value_t){.text = "TRACK"});
}

static void run_measurement_and_control(void)
{
    if (!s_agc_ready || !demo_hw_is_ready()) return;

    rabi_err_t err = demo_hw_capture(s_samples, DEMO_SAMPLE_COUNT);
    if (err != RABI_ERR_OK)
    {
        enter_safe_fault("ADC ERR");
        return;
    }

    demo_agc_result_t result;
    err = demo_agc_process(&s_agc,
        s_samples, DEMO_SAMPLE_COUNT, &result);
    if (err != RABI_ERR_OK)
    {
        enter_safe_fault("MATH ERR");
        return;
    }

    if (s_enabled &&
        demo_hw_set_control_mv(result.control_mv) != RABI_ERR_OK)
    {
        enter_safe_fault("DAC ERR");
        return;
    }

    update_result_ui(&result);
}

static void enter_safe_fault(const char *state_text)
{
    demo_hw_set_amplifier_enabled(false);
    if (demo_hw_is_ready())
    {
        (void)demo_hw_set_control_mv(DEMO_CONTROL_MIN_MV);
    }
    if (s_agc_ready)
    {
        (void)demo_agc_set_enabled(&s_agc, false);
    }
    s_enabled = false;
    (void)rabi_ui_set_value(UI_ITEM_MODE,
        (rabi_ui_item_value_t){.list_index = 0U});
    (void)rabi_ui_set_value(UI_ITEM_STATE,
        (rabi_ui_item_value_t){.text = state_text});
}

static void update_result_ui(const demo_agc_result_t *result)
{
    (void)rabi_ui_set_value(UI_ITEM_POWER,
        (rabi_ui_item_value_t){
            .numeric_value = (float)result->power_mw / 1000.0f,
        });
    (void)rabi_ui_set_value(UI_ITEM_FREQUENCY,
        (rabi_ui_item_value_t){
            .numeric_value = (float)result->frequency_millihz / 1000.0f,
        });
    (void)rabi_ui_set_value(UI_ITEM_CONTROL,
        (rabi_ui_item_value_t){
            .numeric_value = (float)result->control_mv,
        });

    const char *state = "OFF";
    if (s_enabled)
    {
        state = result->settled ? "OK" :
            (result->control_saturated ? "LIMIT" : "TRACK");
    }
    (void)rabi_ui_set_value(UI_ITEM_STATE,
        (rabi_ui_item_value_t){.text = state});
}
