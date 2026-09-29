/* Rabi 核心模块：事件队列实现。 */
#include <stdbool.h>
#include "rabi_event.h"
#include "ti_msp_dl_config.h"

#define MAX_EVENT_MESSAGE 8
#define MAX_EVENT_LISTENER 8

typedef struct
{
    rabi_event_base_t base;
    rabi_event_id_t id;
    void *param;
} event_message_t;

typedef struct
{
    rabi_event_base_t base;
    rabi_event_id_t id;
    rabi_event_cb_t cb;
} event_listener_t;

static event_message_t s_messages[MAX_EVENT_MESSAGE];
static volatile uint8_t s_messages_head;
static volatile uint8_t s_messages_tail;

static event_listener_t s_listeners[MAX_EVENT_LISTENER];
static uint8_t s_listeners_num;

static uint32_t enter_critical(void)
{
    uint32_t primask = __get_PRIMASK();
    __disable_irq();
    return primask;
}

static void exit_critical(uint32_t primask)
{
    __set_PRIMASK(primask);
}

void rabi_event_init(void)
{
    uint32_t primask = enter_critical();
    s_messages_head = 0;
    s_messages_tail = 0;
    s_listeners_num = 0;
    exit_critical(primask);
}

void rabi_event_loop(void)
{
    event_message_t message;
    uint32_t primask = enter_critical();

    if (s_messages_head == s_messages_tail)
    {
        exit_critical(primask);
        return;
    }

    message = s_messages[s_messages_tail];
    s_messages_tail = (s_messages_tail + 1U) & (MAX_EVENT_MESSAGE - 1U);
    exit_critical(primask);

    for (uint8_t i = 0; i < s_listeners_num; i++)
    {
        bool is_base_match = s_listeners[i].base == RABI_EVENT_BASE_ANY || s_listeners[i].base == message.base;
        if (!is_base_match) continue;

        bool is_id_match = s_listeners[i].id == RABI_EVENT_ID_ANY || s_listeners[i].id == message.id;
        if (!is_id_match) continue;

        s_listeners[i].cb(message.base, message.id, message.param);
    }
}

rabi_err_t rabi_event_listen(rabi_event_base_t base, rabi_event_id_t id, rabi_event_cb_t cb)
{
    if (!cb) return RABI_ERR_INVALID_ARG;
    if (s_listeners_num >= MAX_EVENT_LISTENER) return RABI_ERR_NO_RESOURCES;

    s_listeners[s_listeners_num].base = base;
    s_listeners[s_listeners_num].id = id;
    s_listeners[s_listeners_num].cb = cb;
    s_listeners_num++;

    return RABI_ERR_OK;
}

rabi_err_t rabi_event_post(rabi_event_base_t base, rabi_event_id_t id, void *param)
{
    rabi_err_t err = RABI_ERR_OK;
    uint32_t primask = enter_critical();

    uint8_t next_head = (s_messages_head + 1U) & (MAX_EVENT_MESSAGE - 1U);
    if (next_head == s_messages_tail)
    {
        err = RABI_ERR_NO_RESOURCES;
        goto final;
    }

    s_messages[s_messages_head].base = base;
    s_messages[s_messages_head].id = id;
    s_messages[s_messages_head].param = param;
    s_messages_head = next_head;

final:
    exit_critical(primask);
    return err;
}
