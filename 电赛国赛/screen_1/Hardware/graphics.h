#ifndef GRAPHICS_H
#define GRAPHICS_H

#include <stdint.h>

/**
 * @file graphics.h
 * @brief ST7796 屏幕的通用二维绘图与英文/数字文本绘制接口。
 *
 * 本模块建立在 st7796.h 的底层像素接口之上，提供像素、任意直线、折线、
 * 圆、实心圆，以及整数、浮点数和单位文本等常用 UI 绘制能力。
 *
 * 坐标系约定：屏幕左上角为 (0, 0)，x 向右增大，y 向下增大；当前横屏
 * 有效范围为 x=0..479、y=0..319。几何图元使用 int16_t 坐标，因此允许
 * 传入负坐标，超出屏幕的部分会被裁剪或忽略；文本接口使用 uint16_t
 * 坐标，文本必须从屏幕内的非负位置开始。
 * 几何坐标应取屏幕附近的合理数值，避免使用接近 INT16_MIN/INT16_MAX 的
 * 极端端点参与裁剪运算。
 *
 * 颜色统一使用 RGB565 格式，可用 st7796.h 中的 RGB565(r, g, b) 宏生成。
 * 所有绘图函数均为同步阻塞调用：函数返回时，对应像素数据已经发送完毕。
 */

/**
 * @brief 一个二维有符号像素坐标点，供折线等接口保存顶点。
 */
typedef struct {
    int16_t x; /**< 点的横坐标；向右为正，允许位于屏幕范围之外。 */
    int16_t y; /**< 点的纵坐标；向下为正，允许位于屏幕范围之外。 */
} GraphicsPoint;

/**
 * @brief 绘制一个像素点。
 *
 * @param x 像素横坐标。有效可见范围为 0..ST7796_WIDTH-1；越界时不绘制。
 * @param y 像素纵坐标。有效可见范围为 0..ST7796_HEIGHT-1；越界时不绘制。
 * @param color 像素颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。
 *
 * @par 适用场景
 * 绘制散点、标记点，或实现其他自定义图元时作为最基础的像素操作。
 * 大面积填色应优先使用 ST7796_FillRect()，速度明显更快。
 */
void Graphics_DrawPixel(int16_t x, int16_t y, uint16_t color);

/**
 * @brief 绘制连接两个端点的一像素宽直线，并自动裁剪屏幕外部分。
 *
 * @param x0 起点横坐标，允许为负数或位于屏幕右侧。
 * @param y0 起点纵坐标，允许为负数或位于屏幕下方。
 * @param x1 终点横坐标，允许为负数或位于屏幕右侧。
 * @param y1 终点纵坐标，允许为负数或位于屏幕下方。
 * @param color 直线颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。若整条线位于屏幕外，则直接返回且不绘制。
 *
 * @note 水平线和垂直线会自动走底层快速接口；斜线逐像素绘制，长斜线的
 *       刷新速度低于水平线/垂直线。
 * @par 适用场景
 * 坐标轴、连线、指针、斜边，以及自行拼装三角形或其他几何图形。
 */
void Graphics_DrawLine(int16_t x0, int16_t y0, int16_t x1, int16_t y1,
                       uint16_t color);

/**
 * @brief 按数组顺序连接多个顶点，绘制一条不闭合折线。
 *
 * @param points 顶点数组首地址；每个元素均为 GraphicsPoint。不可为 NULL。
 * @param count 顶点数量；至少为 2 才会产生图形。
 * @param color 折线颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。points 为 NULL 或 count 小于 2 时不绘制。
 *
 * @note 函数不会复制或保存 points；只在本次调用期间读取数组。最后一个点
 *       不会自动连接回第一个点，如需闭合图形，请在数组末尾再次放入首点。
 * @par 适用场景
 * 采样波形的简单连线、趋势图、任意多边形轮廓和轨迹显示。大量等间距采样
 * 数据若需要自动缩放和网格，优先使用 plot.h 中的 Plot_DrawWaveform()。
 */
void Graphics_DrawPolyline(const GraphicsPoint *points, uint16_t count,
                           uint16_t color);

/**
 * @brief 绘制一像素宽的空心圆周。
 *
 * @param centerX 圆心横坐标，允许位于屏幕外。
 * @param centerY 圆心纵坐标，允许位于屏幕外。
 * @param radius 半径，单位为像素；负数无效，0 表示绘制圆心像素。
 * @param color 圆周颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。负半径时直接返回；超出屏幕的像素会被忽略。
 *
 * @par 适用场景
 * 仪表盘刻度圈、状态指示灯外框、旋钮、靶心或圆形装饰元素。
 */
void Graphics_DrawCircle(int16_t centerX, int16_t centerY, int16_t radius,
                         uint16_t color);

/**
 * @brief 绘制指定颜色的实心圆。
 *
 * @param centerX 圆心横坐标，允许位于屏幕外。
 * @param centerY 圆心纵坐标，允许位于屏幕外。
 * @param radius 半径，单位为像素；负数无效，0 表示绘制圆心像素。
 * @param color 填充颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。负半径时直接返回；超出屏幕的部分会被裁剪。
 *
 * @par 适用场景
 * 实心状态灯、波形采样点、圆形按钮、指示器端点或示意图节点。
 */
void Graphics_FillCircle(int16_t centerX, int16_t centerY, int16_t radius,
                         uint16_t color);

/**
 * @brief 计算字符串按指定字号绘制后所占的像素宽度。
 *
 * @param text 以 '\0' 结尾的 C 字符串首地址；不可为 NULL。
 * @param scale 字体整数缩放倍数，只接受 1..4。单字符宽度为 6*scale 像素，
 *              其中包含字符后的 1 列间距。
 * @return 返回类型为 uint16_t。成功时返回整串文字的像素宽度；text 为 NULL
 *         或 scale 不在 1..4 时返回 0。
 *
 * @note 本函数只按字符数量计算宽度，不判断字符是否在字库中，也不判断结果
 *       是否能放入屏幕。
 * @par 适用场景
 * 计算标题居中位置、右对齐数值、规划卡片宽度或提前判断文本是否越界。
 */
uint16_t Graphics_TextWidth(const char *text, uint8_t scale);

/**
 * @brief 获取指定字号的统一字符高度。
 *
 * @param scale 字体整数缩放倍数，只接受 1..4。
 * @return 返回类型为 uint16_t。有效时返回 7*scale 像素；scale 不在 1..4
 *         时返回 0。
 *
 * @par 适用场景
 * 计算多行文本的行距、垂直居中位置，或为文字预留背景区域。
 */
uint16_t Graphics_TextHeight(uint8_t scale);

/**
 * @brief 使用内置 5x7 点阵字库绘制一个字符及其背景。
 *
 * @param x 字符外接矩形左上角横坐标。
 * @param y 字符外接矩形左上角纵坐标。
 * @param character 待绘制字符。支持 0..9、A..Z、a..z（按大写显示）、
 *                  空格以及 . , : - / + % = ( )；其他字符显示为空白。
 * @param scale 字体整数缩放倍数，只接受 1..4。绘制尺寸为
 *              (6*scale) x (7*scale) 像素。
 * @param foreground 字符笔画颜色，16 位 RGB565 格式。
 * @param background 字符空白区域颜色，16 位 RGB565 格式；本接口为不透明绘制。
 * @return 无（返回类型为 void）。字号无效或字符矩形不能完整放入屏幕时不绘制。
 *
 * @note 字符的实际字形宽 5 个点阵列，第 6 列作为字符间距，也会填充 background。
 *       函数内部使用模块共享的静态像素缓冲区，不占用大块调用栈，但因此不可
 *       重入，不要在中断和主循环中并发调用。
 * @par 适用场景
 * 绘制单个状态字母、按键标签、单位符号或需要精确逐字符布局的界面。
 */
void Graphics_DrawChar(uint16_t x, uint16_t y, char character,
                       uint8_t scale, uint16_t foreground,
                       uint16_t background);

/**
 * @brief 从指定位置开始，横向绘制一串英文、数字及受支持符号。
 *
 * @param x 第一个字符外接矩形左上角横坐标。
 * @param y 字符串外接矩形左上角纵坐标。
 * @param text 以 '\0' 结尾的 C 字符串首地址；不可为 NULL。
 * @param scale 字体整数缩放倍数，只接受 1..4。
 * @param foreground 文字颜色，16 位 RGB565 格式。
 * @param background 每个字符空白区域的背景颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。参数无效时不绘制；遇到右边界或下边界时
 *         停止，因此可能只显示字符串前半部分。
 *
 * @note 不支持自动换行和中文；小写英文字母会转换为大写字形。若要覆盖旧数值，
 *       应保持 background 与所在区域背景一致，或先清空目标矩形。
 * @par 适用场景
 * 标题、标签、测量状态、英文提示和已经格式化好的数值字符串。
 */
void Graphics_DrawText(uint16_t x, uint16_t y, const char *text,
                       uint8_t scale, uint16_t foreground,
                       uint16_t background);

/**
 * @brief 将一个有符号 32 位整数转换为十进制文本并绘制。
 *
 * @param x 数值文本左上角横坐标。
 * @param y 数值文本左上角纵坐标。
 * @param value 待显示的 int32_t 数值，支持负号及完整 32 位有符号范围。
 * @param scale 字体整数缩放倍数，只接受 1..4。
 * @param foreground 数值文字颜色，16 位 RGB565 格式。
 * @param background 文字背景颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。最终显示和越界规则与 Graphics_DrawText() 相同。
 *
 * @par 适用场景
 * 显示带正负号的 ADC 码、偏差、相位、坐标、计数结果等整数参数。
 */
void Graphics_DrawInt(uint16_t x, uint16_t y, int32_t value,
                      uint8_t scale, uint16_t foreground,
                      uint16_t background);

/**
 * @brief 将一个无符号 32 位整数转换为十进制文本并绘制。
 *
 * @param x 数值文本左上角横坐标。
 * @param y 数值文本左上角纵坐标。
 * @param value 待显示的 uint32_t 数值，支持完整 0..4294967295 范围。
 * @param scale 字体整数缩放倍数，只接受 1..4。
 * @param foreground 数值文字颜色，16 位 RGB565 格式。
 * @param background 文字背景颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。最终显示和越界规则与 Graphics_DrawText() 相同。
 *
 * @par 适用场景
 * 显示频率、时间、样本数、计数器、序号或其他非负整型测量结果。
 */
void Graphics_DrawUInt(uint16_t x, uint16_t y, uint32_t value,
                       uint8_t scale, uint16_t foreground,
                       uint16_t background);

/**
 * @brief 将浮点数按指定小数位四舍五入后绘制为十进制文本。
 *
 * @param x 数值文本左上角横坐标。
 * @param y 数值文本左上角纵坐标。
 * @param value 待显示的 float 数值，可为正数或负数。
 * @param decimals 小数位数；大于 4 时自动按 4 位处理，0 表示只显示整数部分。
 * @param scale 字体整数缩放倍数，只接受 1..4。
 * @param foreground 数值文字颜色，16 位 RGB565 格式。
 * @param background 文字背景颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。最终显示和越界规则与 Graphics_DrawText() 相同。
 *
 * @note 数值按最后一位四舍五入；绝对值大于 429000 时显示 "OVF"。本接口使用
 *       float 运算，若实时刷新频率很高，可先在业务层转为整数以减少运算量。
 *       应只传入有限浮点数，不要传入 NaN 或正负无穷。
 * @par 适用场景
 * 显示电压、频率换算值、增益、占空比、温度等需要固定小数位的测量量。
 */
void Graphics_DrawFloat(uint16_t x, uint16_t y, float value,
                        uint8_t decimals, uint8_t scale,
                        uint16_t foreground, uint16_t background);

/**
 * @brief 绘制“有符号整数 + 空格 + 单位”的组合文本。
 *
 * @param x 组合文本左上角横坐标。
 * @param y 组合文本左上角纵坐标。
 * @param value 待显示的 int32_t 数值。
 * @param unit 以 '\0' 结尾的单位字符串，如 "Hz"、"mV"；可为 NULL 或空串，
 *             此时只显示数值。字库支持范围与 Graphics_DrawText() 相同。
 * @param scale 字体整数缩放倍数，只接受 1..4。
 * @param foreground 组合文本颜色，16 位 RGB565 格式。
 * @param background 组合文本背景颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。最终显示和越界规则与 Graphics_DrawText() 相同。
 *
 * @note 内部组合缓冲区为 32 字节；过长单位会被安全截断。函数会在非空单位前
 *       自动插入一个空格，调用者无需在 unit 开头手动加空格。
 * @par 适用场景
 * 一行显示频率、计数、电压整数值等，例如 "50000 Hz" 或 "200 mV"。
 */
void Graphics_DrawIntWithUnit(uint16_t x, uint16_t y, int32_t value,
                              const char *unit, uint8_t scale,
                              uint16_t foreground, uint16_t background);

/**
 * @brief 绘制“浮点数 + 空格 + 单位”的组合文本。
 *
 * @param x 组合文本左上角横坐标。
 * @param y 组合文本左上角纵坐标。
 * @param value 待显示的 float 数值。
 * @param decimals 小数位数；大于 4 时自动按 4 位处理。
 * @param unit 以 '\0' 结尾的单位字符串，如 "kHz"、"VPP"；可为 NULL 或空串，
 *             此时只显示数值。字库支持范围与 Graphics_DrawText() 相同。
 * @param scale 字体整数缩放倍数，只接受 1..4。
 * @param foreground 组合文本颜色，16 位 RGB565 格式。
 * @param background 组合文本背景颜色，16 位 RGB565 格式。
 * @return 无（返回类型为 void）。最终显示和越界规则与 Graphics_DrawText() 相同。
 *
 * @note 内部组合缓冲区为 32 字节；过长单位会被安全截断。非空单位前会自动
 *       添加空格；浮点格式、四舍五入及 "OVF" 规则同 Graphics_DrawFloat()。
 * @par 适用场景
 * 一行显示带小数的工程量，例如 "50.00 kHz"、"0.200 V" 或 "12.5 %"。
 */
void Graphics_DrawFloatWithUnit(uint16_t x, uint16_t y, float value,
                                uint8_t decimals, const char *unit,
                                uint8_t scale, uint16_t foreground,
                                uint16_t background);

#endif
