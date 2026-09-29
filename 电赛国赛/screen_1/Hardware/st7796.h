#ifndef ST7796_H
#define ST7796_H

#include <stdint.h>

/**
 * @file st7796.h
 * @brief 4.0 英寸 ST7796 SPI 屏幕的底层初始化和矩形像素输出接口。
 *
 * 当前驱动把屏幕配置为 480x320 横屏：左上角是 (0,0)，x 向右增大，y 向下
 * 增大。所有颜色均使用 16 位 RGB565。接口通过 SPI 同步阻塞发送，函数返回时
 * 本次像素数据已经发送完成；本驱动不提供 SPI 错误状态返回。
 *
 * 推荐分层：本文件用于清屏、色块、横竖线、矩形框和像素块；任意斜线、圆、
 * 文字使用 graphics.h；带网格的波形和频谱使用 plot.h。
 */

/** @brief 当前横屏模式的逻辑宽度，单位为像素；有效 x 坐标为 0..479。 */
#define ST7796_WIDTH  (480U)

/** @brief 当前横屏模式的逻辑高度，单位为像素；有效 y 坐标为 0..319。 */
#define ST7796_HEIGHT (320U)

/**
 * @brief 将 8 位 RGB 三通道颜色压缩为一个 16 位 RGB565 颜色值。
 *
 * @param r 红色通道，通常取 0..255；保留高 5 位。
 * @param g 绿色通道，通常取 0..255；保留高 6 位。
 * @param b 蓝色通道，通常取 0..255；保留高 5 位。
 * @return 返回类型为 uint16_t：位 15..11 为 R，位 10..5 为 G，位 4..0 为 B。
 *
 * @note 这是宏而非函数。大于 255 的输入会按掩码截取相应位，不会自动饱和到
 *       255；竞赛代码中建议始终传入 0..255 的常量或已限幅变量。
 * @par 适用场景
 * 生成所有 ST7796、Graphics 和 Plot 接口所需的颜色，例如
 * `RGB565(255U, 0U, 0U)` 表示红色。
 */
#define RGB565(r, g, b) \
    ((uint16_t)((((uint16_t)(r) & 0xF8U) << 8) | \
                (((uint16_t)(g) & 0xFCU) << 3) | \
                (((uint16_t)(b) & 0xF8U) >> 3)))

/**
 * @brief 硬件复位并初始化 ST7796 控制器为 480x320 横屏 RGB565 模式。
 *
 * 函数依次完成 RESET 时序、寄存器和 Gamma 参数设置、退出睡眠、开启显示，
 * 最后使用 RGB565(5,12,22) 的深色背景清屏。
 *
 * @return 无（返回类型为 void）。本驱动没有读取屏幕应答，无法返回硬件是否
 *         在线；若接线或供电异常，函数仍会按既定时序结束。
 *
 * @pre 必须先调用 SYSCFG_DL_init()，使 SPI_LCD、CS、DC、RESET 引脚和系统
 *      时钟完成初始化。
 * @note 初始化包含约 290 ms 的阻塞等待，延时按当前工程 32 MHz CPU 时钟编写。
 *       若以后修改系统主频，需同步检查 st7796.c 中 lcd_delay_ms() 的换算。
 * @par 适用场景
 * 系统上电后调用一次。常见顺序为：SYSCFG_DL_init(); ST7796_Init();，随后再
 * 使用本文件或 graphics.h、plot.h 的绘图函数构建 UI。
 */
void ST7796_Init(void);

/**
 * @brief 用同一种颜色填满整个 480x320 屏幕。
 *
 * @param color 填充颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。
 *
 * @note 本函数等价于对整个屏幕调用 ST7796_FillRect()，需要通过 SPI 发送
 *       153600 个像素，因此是阻塞且相对耗时的操作。
 * @par 适用场景
 * 页面切换前清屏、建立统一 UI 背景，或快速验证屏幕初始化和颜色通道。
 */
void ST7796_FillScreen(uint16_t color);

/**
 * @brief 从指定左上角开始填充一个纯色实心矩形。
 *
 * @param x 矩形左上角横坐标，只能为非负值。
 * @param y 矩形左上角纵坐标，只能为非负值。
 * @param width 矩形宽度，单位为像素；0 表示不绘制。
 * @param height 矩形高度，单位为像素；0 表示不绘制。
 * @param color 填充颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。起点越界或尺寸为 0 时直接返回。
 *
 * @note 若矩形右边或下边超出屏幕，函数会把宽度/高度裁剪到屏幕边界；由于
 *       坐标类型是 uint16_t，不支持从左边或上边以负坐标开始绘制。
 * @par 适用场景
 * 清除局部旧内容、绘制卡片底色、色条、粗线、按钮背景和任意矩形色块。
 */
void ST7796_FillRect(uint16_t x, uint16_t y, uint16_t width,
                     uint16_t height, uint16_t color);

/**
 * @brief 绘制一条从 (x,y) 向右延伸的一像素高水平线。
 *
 * @param x 水平线左端横坐标。
 * @param y 水平线纵坐标。
 * @param width 水平线长度，单位为像素；0 表示不绘制。
 * @param color 线条颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。边界行为继承 ST7796_FillRect()。
 *
 * @note 右端超出屏幕时会裁剪；x 或 y 已越界时不绘制。
 * @par 适用场景
 * 分隔线、坐标横轴、下划线、进度条以及拼装矩形或表格。
 */
void ST7796_DrawHLine(uint16_t x, uint16_t y, uint16_t width,
                      uint16_t color);

/**
 * @brief 绘制一条从 (x,y) 向下延伸的一像素宽垂直线。
 *
 * @param x 垂直线横坐标。
 * @param y 垂直线上端纵坐标。
 * @param height 垂直线长度，单位为像素；0 表示不绘制。
 * @param color 线条颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。边界行为继承 ST7796_FillRect()。
 *
 * @note 下端超出屏幕时会裁剪；x 或 y 已越界时不绘制。
 * @par 适用场景
 * 分隔线、坐标纵轴、游标、刻度线以及拼装矩形或表格。
 */
void ST7796_DrawVLine(uint16_t x, uint16_t y, uint16_t height,
                      uint16_t color);

/**
 * @brief 绘制一像素线宽的空心矩形边框。
 *
 * @param x 矩形外框左上角横坐标。
 * @param y 矩形外框左上角纵坐标。
 * @param width 矩形外框总宽度，包含左右边线；必须至少为 2。
 * @param height 矩形外框总高度，包含上下边线；必须至少为 2。
 * @param color 边框颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。width 或 height 小于 2 时不绘制。
 *
 * @note 若要得到完整闭合边框，应保证 x+width<=ST7796_WIDTH 且
 *       y+height<=ST7796_HEIGHT。超界时四条边各自裁剪或忽略，远端边可能消失，
 *       函数不会在裁剪后的新边界上补画闭合线。
 * @par 适用场景
 * UI 卡片、按钮、绘图区、参数框和调试区域的矩形轮廓。
 */
void ST7796_DrawRect(uint16_t x, uint16_t y, uint16_t width,
                     uint16_t height, uint16_t color);

/**
 * @brief 把内存中的一块 RGB565 像素数组原样绘制到屏幕矩形区域。
 *
 * @param x 目标区域左上角横坐标。
 * @param y 目标区域左上角纵坐标。
 * @param width 目标区域及像素数组每行的宽度，单位为像素；必须大于 0。
 * @param height 目标区域及像素数组的行数，单位为像素；必须大于 0。
 * @param pixels 像素数组首地址；不可为 NULL，且至少含 width*height 个
 *               uint16_t RGB565 元素。数组按行优先排列：先从左到右，再从上到下。
 * @return 无（返回类型为 void）。空指针、零尺寸或区域不能完整放入屏幕时
 *         直接返回且不绘制。
 *
 * @note 本函数不执行裁剪。调用期间 pixels 指向的内存必须保持有效；发送顺序为
 *       每个 RGB565 像素的高字节在前、低字节在后。函数为同步阻塞调用。
 * @par 适用场景
 * 批量输出图标、小图片、离屏缓冲区、字体位图，或像 plot.c 那样逐行高速刷新。
 */
void ST7796_DrawRGB565(uint16_t x, uint16_t y, uint16_t width,
                       uint16_t height, const uint16_t *pixels);

#endif
