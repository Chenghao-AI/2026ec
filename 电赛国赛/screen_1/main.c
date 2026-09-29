#include "ti_msp_dl_config.h"
#include "signal_display.h"
#include "graphics.h"
#include "st7796.h"

/**
 * @file main.c
 * @brief 使用 ST7796 底层驱动和 Graphics 通用图元绘制的频谱仪 UI 示例。
 *
 * 本文件故意不调用 ui.h 和 plot.h，用于演示如何在比赛现场仅依靠：
 * 1. st7796.h：屏幕初始化、清屏和实心矩形；
 * 2. graphics.h：文字、数值、任意直线、折线和圆形；
 * 从空白屏幕组织一个完整的 480 x 320 仪器界面。
 */

#define COLOR_BACKGROUND RGB565(4U, 11U, 20U)
#define COLOR_HEADER     RGB565(7U, 31U, 49U)
#define COLOR_PANEL      RGB565(10U, 28U, 44U)
#define COLOR_PANEL_ALT  RGB565(13U, 40U, 59U)
#define COLOR_GRID       RGB565(28U, 59U, 76U)
#define COLOR_AXIS       RGB565(103U, 139U, 157U)
#define COLOR_CYAN       RGB565(31U, 211U, 238U)
#define COLOR_TEAL       RGB565(27U, 139U, 154U)
#define COLOR_GOLD       RGB565(255U, 188U, 69U)
#define COLOR_GREEN      RGB565(56U, 211U, 134U)
#define COLOR_WHITE      RGB565(239U, 247U, 251U)
#define COLOR_MUTED      RGB565(132U, 164U, 179U)

/* 频谱绘图区。(x,y) 是左上角，width/height 是像素尺寸。 */
#define GRAPH_X      (5U)   /* 频谱区左边界 X 坐标 */
#define GRAPH_Y      (114U)  /* 频谱区上边界 Y 坐标 */
#define GRAPH_WIDTH  (230U)  /* 频谱区宽度：X=16...463 */
#define GRAPH_HEIGHT (168U)  /* 频谱区高度：Y=118...277 */
#define GRAPH_BOTTOM (258U)  /* 频柱状线的基线，下方留给横轴标注 */

/**
 * @brief 绘制顶部数据卡片。
 *
 * 卡片使用固定的 Y=58、宽140、高48；调用者通过 x 决定水平位置。
 * 卡片左侧绘制4像素宽的强调色条，然后绘制标签和数值。
 *
 * @param x       卡片左上角 X 坐标。本页使用16、170、324放置三张卡片。
 * @param label   卡片标签字符串，例如 "CENTER"。
 * @param value   卡片主数值字符串，例如 "50.000 KHZ"。
 * @param accent  RGB565 强调色，用于卡片左侧色条。
 */
static void draw_data_card(uint16_t x, const char *label,
                           const char *value, uint16_t accent)
{
    ST7796_FillRect(x, 58U, 140U, 48U, COLOR_PANEL_ALT);
    ST7796_FillRect(x, 58U, 4U, 48U, accent);
    Graphics_DrawText((uint16_t)(x + 12U), 65U, label, 1U,
                      COLOR_MUTED, COLOR_PANEL_ALT);
    Graphics_DrawText((uint16_t)(x + 12U), 83U, value, 2U,
                      COLOR_WHITE, COLOR_PANEL_ALT);
}

/**
 * @brief 绘制屏幕顶部标题栏和运行状态。
 *
 * 标题栏占用 Y=0...47，包含主标题、硬件子标题、绿色状态点和 RUN 文字。
 * 该函数无参数，页面内容由函数内常量决定。
 */
static void draw_header(void)
{
    ST7796_FillRect(0U, 0U, ST7796_WIDTH, 48U, COLOR_HEADER);
    ST7796_FillRect(0U, 46U, ST7796_WIDTH, 2U, COLOR_CYAN);

    Graphics_DrawText(16U, 10U, "CIRCUIT CHARACTERISTICS ANALYZER", 2U,
                      COLOR_WHITE, COLOR_HEADER);
    Graphics_DrawText(17U, 31U, "MSPM0G3507 / ST7796", 1U,
                      COLOR_MUTED, COLOR_HEADER);

    Graphics_FillCircle(431, 17, 4, COLOR_GREEN);
    Graphics_DrawText(442U, 14U, "RUN", 1U,
                      COLOR_GREEN, COLOR_HEADER);
}

/**
 * @brief 绘制频谱图背景、坐标网格、中心轴和边框。
 *
 * 水平方向分为10份，对应0...100 kHz；垂直方向分为5份。
 * 中央的第5条垂线用更亮的坐标轴颜色，对应50 kHz。
 */
static void draw_graph1_grid(void)
{
    uint16_t division;

    ST7796_FillRect(GRAPH_X, GRAPH_Y, GRAPH_WIDTH, GRAPH_HEIGHT,
                    COLOR_PANEL);

    /* Ten horizontal frequency divisions. */
    for (division = 0U; division <= 20U; division++) {
        int16_t x = (int16_t)(GRAPH_X +
                    ((uint32_t)division * (GRAPH_WIDTH - 1U)) / 20U);
        Graphics_DrawLine(x, (int16_t)GRAPH_Y,
                          x, (int16_t)(GRAPH_Y + GRAPH_HEIGHT - 1U),
                          COLOR_GRID);
    }

    /* Five magnitude divisions. */
    for (division = 0U; division <= 12U; division++) {
        int16_t y = (int16_t)(GRAPH_Y +
                    ((uint32_t)division * (GRAPH_HEIGHT - 1U)) / 12U);
        Graphics_DrawLine((int16_t)GRAPH_X, y,
                          (int16_t)(GRAPH_X + GRAPH_WIDTH - 1U), y,
                          COLOR_GRID);
    }

    ST7796_DrawRect(GRAPH_X, GRAPH_Y, GRAPH_WIDTH, GRAPH_HEIGHT,
                    COLOR_TEAL);
}

static void draw_graph2_grid(void)
{
    uint16_t division;

    ST7796_FillRect(245U,GRAPH_Y, GRAPH_WIDTH, GRAPH_HEIGHT,
                    COLOR_PANEL);

    /* Ten horizontal frequency divisions. */
    for (division = 0U; division <= 20U; division++) {
        int16_t x = (int16_t)(245U+
                    ((uint32_t)division * (GRAPH_WIDTH - 1U)) / 20U);
        Graphics_DrawLine(x, (int16_t)GRAPH_Y,
                          x, (int16_t)(GRAPH_Y + GRAPH_HEIGHT - 1U),
                          COLOR_GRID);
    }

    /* Five magnitude divisions. */
    for (division = 0U; division <= 12U; division++) {
        int16_t y = (int16_t)(GRAPH_Y +
                    ((uint32_t)division * (GRAPH_HEIGHT - 1U)) / 12U);
        Graphics_DrawLine((int16_t)245U, y,
                          (int16_t)(245U + GRAPH_WIDTH - 1U), y,
                          COLOR_GRID);
    }

    ST7796_DrawRect(245U, GRAPH_Y, GRAPH_WIDTH, GRAPH_HEIGHT,
                    COLOR_TEAL);
}

/**
 * @brief 在频谱图内绘制幅度刻度和频率刻度文字。
 *
 * 左侧显示0 dB、-40 dB、-80 dB，底部显示0、50、100 kHz。
 */
static void draw_graph_labels(void)
{
    Graphics_DrawText(8U, 118U, "0dB", 1U,
                      COLOR_MUTED, COLOR_PANEL);
    Graphics_DrawText(202U, 118U, "20kHz", 1U,
                      COLOR_MUTED, COLOR_PANEL);
    Graphics_DrawText(8U, 272U, "G", 1U,
                      COLOR_MUTED, COLOR_PANEL);   
    Graphics_DrawText(228U, 130U, "F", 1U,
                      COLOR_MUTED, COLOR_PANEL);                                         
    Graphics_DrawLine(5, 128, 234, 128, COLOR_GOLD);
    Graphics_DrawLine(5, 128, 5, 281, COLOR_GOLD);                  

    Graphics_DrawText(248U, 201U, "0", 1U,
                      COLOR_MUTED, COLOR_PANEL);
    Graphics_DrawText(248U, 117U, "V", 1U,
                      COLOR_MUTED, COLOR_PANEL);                  
    Graphics_DrawText(455U, 189U, "2ms", 1U,
                      COLOR_MUTED, COLOR_PANEL);   
    Graphics_DrawText(467U, 202U, "T", 1U,
                      COLOR_MUTED, COLOR_PANEL);                                
    Graphics_DrawLine(245, 198, 474, 198, COLOR_GOLD);
    Graphics_DrawLine(245, 114, 245, 281, COLOR_GOLD);
}

/**
 * @brief 绘制页面底部仪器参数栏。
 *
 * 底栏占用 Y=289...319，当前显示 RBW、衰减、参考电平和保持状态。
 */
static void draw_footer(void)
{
    ST7796_FillRect(0U, 289U, ST7796_WIDTH, 31U, COLOR_HEADER);
    Graphics_DrawText(80U, 301U, "LFREQ 300Hz", 1U,
                      COLOR_CYAN, COLOR_HEADER);
    Graphics_DrawText(200U, 301U, "THFREQ 19kHz", 1U,
                      COLOR_MUTED, COLOR_HEADER);
    Graphics_DrawText(325U, 301U, "NUM 3", 1U,
                      COLOR_GREEN, COLOR_HEADER);
}

/**
 * @brief 按正确的覆盖顺序绘制完整频谱仪页面。
 *
 * 绘制顺序为：全局背景 -> 标题栏 -> 数据卡片 -> 图表网格 -> 频谱数据
 * -> 坐标文字 -> 底部栏。后绘制的内容会覆盖先绘制的像素，因此背景必须最先绘制。
 */
static void draw_spectrum_page(void)
{
    ST7796_FillScreen(COLOR_BACKGROUND);
    draw_header();

    draw_data_card(60U,  "FREQ", "50.000 KHZ", COLOR_CYAN);
    draw_data_card(280U, "Vpp",   "200 MV",     COLOR_GOLD);

    draw_graph1_grid();
    draw_graph2_grid();
    draw_graph_labels();
    draw_footer();
}

/**
 * @brief 程序入口。
 *
 * 执行顺序：
 * 1. SYSCFG_DL_init() 根据 SysConfig 初始化时钟、GPIO 和 SPI1；
 * 2. ST7796_Init() 复位并初始化屏幕；
 * 3. draw_spectrum_page() 绘制一次完整页面；
 * 4. CPU 进入等待中断状态，屏幕显存会持续保留图像。
 *
 * @return 嵌入式程序不返回，保留 int 签名以符合 C 语言入口约定。
 */
int main(void)
{
    SYSCFG_DL_init();
    ST7796_Init();
    draw_spectrum_page();

    while (1) {
        __WFI();
    }
}
