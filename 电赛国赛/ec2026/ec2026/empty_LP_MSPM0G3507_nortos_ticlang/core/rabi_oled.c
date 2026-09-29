/* Rabi 核心模块：OLED 驱动实现。 */
#include <stdbool.h>
#include <string.h>
#include "rabi_oled.h"
#include "rabi_font.h"
#include "ti_msp_dl_config.h"

#define ROW_PADDING_LEFT 4

#define MAX_ROW 4
#define MAX_CHAR_PER_ROW 15

static char s_row_char[MAX_ROW][MAX_CHAR_PER_ROW];
static int8_t s_focus_pos[] = {-1, -1};

static void send_cmd(uint8_t cmd);
static void send_data(const uint8_t *data, uint16_t length);
static void init_spi(void);
static void init_cmd(void);
static void set_cursor(uint8_t page, uint8_t column);
static void draw_char_underline(uint8_t row, uint8_t index, char ch, bool underline);

static void set_chip_select(bool selected)
{
#if defined(GPIO_OLED_CS_PIN)
    if (selected)
    {
        DL_GPIO_clearPins(GPIO_OLED_PORT, GPIO_OLED_CS_PIN);
    }
    else
    {
        DL_GPIO_setPins(GPIO_OLED_PORT, GPIO_OLED_CS_PIN);
    }
#else
    (void)selected;
#endif
}

static void send_byte(uint8_t data)
{
    while (DL_SPI_isTXFIFOFull(SPI_OLED_INST));
    DL_SPI_transmitData8(SPI_OLED_INST, data);
    while (DL_SPI_isBusy(SPI_OLED_INST));

    if (!DL_SPI_isRXFIFOEmpty(SPI_OLED_INST))
    {
        (void)DL_SPI_receiveData8(SPI_OLED_INST);
    }
}

void rabi_oled_init(void)
{
    init_spi();
    init_cmd();
    rabi_oled_clear();
}

void rabi_oled_clear(void)
{
    uint8_t buffer[128] = {0};
    for (uint8_t page = 0; page < 8; page++)
    {
        set_cursor(page, 0);
        send_data(buffer, 128);
    }
    memset(s_row_char, ' ', sizeof(s_row_char));
}

rabi_err_t rabi_oled_print(uint8_t row, const char *text)
{
    if (row >= MAX_ROW) return RABI_ERR_INVALID_ARG;

    for (uint8_t i = 0; i < MAX_CHAR_PER_ROW; i++)
    {
        char ch = (text != NULL && *text != '\0') ? *text++ : ' ';
        if (s_row_char[row][i] == ch) continue;

        s_row_char[row][i] = ch;
        draw_char_underline(row, i, ch, s_focus_pos[0] == row && s_focus_pos[1] == i);
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_oled_set_focus(uint8_t row, uint8_t index)
{
    if (row >= MAX_ROW || index >= MAX_CHAR_PER_ROW) return RABI_ERR_INVALID_ARG;

    if (s_focus_pos[0] == row && s_focus_pos[1] == index) return RABI_ERR_OK;

    if (s_focus_pos[0] >= 0 && s_focus_pos[1] >= 0)
    {
        char old_ch = s_row_char[s_focus_pos[0]][s_focus_pos[1]];
        draw_char_underline(s_focus_pos[0], s_focus_pos[1], old_ch, false);
    }

    s_focus_pos[0] = row;
    s_focus_pos[1] = index;

    char ch = s_row_char[row][index];
    draw_char_underline(row, index, ch, true);

    return RABI_ERR_OK;
}

void rabi_oled_clear_focus(void)
{
    if (s_focus_pos[0] < 0 || s_focus_pos[1] < 0) return;

    char ch = s_row_char[s_focus_pos[0]][s_focus_pos[1]];
    draw_char_underline(s_focus_pos[0], s_focus_pos[1], ch, false);

    s_focus_pos[0] = -1;
    s_focus_pos[1] = -1;
}

static void send_cmd(uint8_t cmd)
{
    set_chip_select(true);
    DL_GPIO_clearPins(GPIO_OLED_PORT, GPIO_OLED_DC_PIN);
    send_byte(cmd);
    set_chip_select(false);
}

static void send_data(const uint8_t *data, uint16_t length)
{
    set_chip_select(true);
    DL_GPIO_setPins(GPIO_OLED_PORT, GPIO_OLED_DC_PIN);

    for (uint16_t i = 0; i < length; i++)
    {
        send_byte(data[i]);
    }

    set_chip_select(false);
}

static void init_spi(void)
{
#if defined(GPIO_OLED_EN_PIN)
    DL_GPIO_setPins(GPIO_OLED_PORT, GPIO_OLED_EN_PIN);
#endif
    set_chip_select(false);

    DL_GPIO_clearPins(GPIO_OLED_PORT, GPIO_OLED_RES_PIN);
    delay_cycles(CPUCLK_FREQ / 100U);
    DL_GPIO_setPins(GPIO_OLED_PORT, GPIO_OLED_RES_PIN);
    delay_cycles(CPUCLK_FREQ / 100U);
}

static void init_cmd(void)
{
    send_cmd(0xAE); // 关闭显示
    send_cmd(0x20); // 寻址模式
    send_cmd(0x02); // 0x02 = 页面寻址模式
    send_cmd(0xB0); // 页面起始地址
    send_cmd(0x00); // 列低地址
    send_cmd(0x10); // 列高地址
    send_cmd(0x40); // 起始行
    send_cmd(0x81); // 对比度
    send_cmd(0xFF); // 最亮
    send_cmd(0xA0); // 段重映射: 左右反转 (根据排线方向可改为0xA0/A1)
    send_cmd(0xC0); // COM方向: 上下反转 (根据排线方向可改为0xC0/C8)
    send_cmd(0xA6); // 正常显示 (非反色)
    send_cmd(0xA8); // MUX Ratio
    send_cmd(0x3F); // 1/64 Duty (对应 128x64)
    send_cmd(0xD3); // 显示偏移
    send_cmd(0x00);
    send_cmd(0xD5); // 时钟分频
    send_cmd(0x80);
    send_cmd(0xD9); // 预充电
    send_cmd(0xF1);
    send_cmd(0xDA); // COM硬件配置
    send_cmd(0x12);
    send_cmd(0xDB); // VCOMH
    send_cmd(0x40);
    send_cmd(0x8D); // 电荷泵
    send_cmd(0x14); // 使能
    send_cmd(0xAF); // 开启显示
}

static void set_cursor(uint8_t page, uint8_t column)
{
    send_cmd(0xB0 | page);
    send_cmd(0x00 | (column & 0x0F));
    send_cmd(0x10 | (column >> 4));
}

static void draw_char_underline(uint8_t row, uint8_t index, char ch, bool underline)
{
    uint8_t ch_index = ch >= ' ' && ch <= '~' ? (ch - ' ') : ('#' - ' ');
    uint8_t top[8], bottom[8];

    for (int i = 0; i < 8; i++)
    {
        top[i] = rabi_font_terminus[ch_index][i];
        bottom[i] = rabi_font_terminus[ch_index][i + 8];

        if (underline)
        {
            bottom[i] |= 0x80;
        }
    }

    uint8_t hw_page = row * 2;
    uint8_t hw_col = ROW_PADDING_LEFT + (index * 8);

    set_cursor(hw_page, hw_col);
    send_data(top, 8);
    set_cursor(hw_page + 1, hw_col);
    send_data(bottom, 8);
}
