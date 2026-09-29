#ifndef KEYPAD_H
#define KEYPAD_H

#include <stdint.h>

/**
 * @file keypad.h
 * @brief 4x4 无源矩阵键盘的扫描、消抖和“新按下”事件接口。
 *
 * 当前键号按实体面板的自然顺序定义：第一行 S1..S4，第二行 S5..S8，
 * 第三行 S9..S12，第四行 S13..S16。Keypad_GetPress() 返回的数值与丝印
 * 编号一致，例如按下 S1 返回 1，按下 S16 返回 16。
 *
 * 本驱动采用“逐列输出低电平、读取上拉行输入”的轮询扫描方式，不使用
 * GPIO 中断。调用者应在主循环中周期性调用 Keypad_GetPress()。
 */

/**
 * @brief 表示当前没有产生新的有效按键事件。
 *
 * Keypad_GetPress() 返回 0 时，可能是没有按键、按键仍在消抖、按键一直
 * 被按住、刚刚松开，或检测到多个键同时按下。有效按键编号只会是 1..16。
 */
#define KEYPAD_NONE (0U)

/**
 * @brief 初始化矩阵键盘驱动的列线电平和软件消抖状态。
 *
 * 函数把 C1..C4 全部置为高电平，并清空候选键、稳定键和消抖计数。
 * GPIO 方向、行输入上拉和引脚复用由 SysConfig 生成代码完成。
 *
 * @return 无（返回类型为 void）。
 *
 * @pre 必须先调用 SYSCFG_DL_init()，确保 KEYPAD_COLS 与 KEYPAD_ROWS
 *      对应 GPIO 已完成硬件初始化。
 * @par 适用场景
 * 系统上电初始化时调用一次；若运行中重新接线或希望清除当前按键状态，也可
 * 再调用一次重新开始消抖。常见顺序为：SYSCFG_DL_init(); Keypad_Init();。
 */
void Keypad_Init(void);

/**
 * @brief 扫描键盘并返回一次经过消抖的“新按下”事件。
 *
 * 每次调用都会依次扫描 4 列和 4 行。只有同一个原始键连续 4 次扫描保持一致，
 * 且它不同于上次已经确认的稳定状态时，函数才返回一次该键编号。按住不放不会
 * 连续重复返回；必须先稳定松开，再次按下后才会产生下一次事件。
 *
 * @return 返回类型为 uint8_t：
 *         - 1..16：本次确认了对应 S1..S16 的一次新按下事件；
 *         - KEYPAD_NONE（0）：本次没有新的有效按下事件。
 *
 * @note 为获得约 20 ms 的常用机械按键消抖时间，建议每约 5 ms 调用一次。
 *       若调用周期为 T，则确认按键大约需要 4*T；调用太慢会使响应迟钝，调用
 *       太快会缩短消抖时间。当前主循环可在每次扫描后执行 delay_cycles(160000)
 *       （32 MHz 时约 5 ms）。
 * @note 驱动不支持组合键：若同一扫描周期识别出多个不同按键，为避免矩阵键盘
 *       鬼键误判，本次返回 KEYPAD_NONE。
 * @note 这是事件接口，不是电平状态接口。不要用“返回 0”判断某个键一定已松开。
 * @note 函数会修改内部消抖状态，不可重入；不要同时在中断和主循环中调用。
 * @par 适用场景
 * 主循环中的页面切换、菜单选择、参数加减和一次性命令触发，例如：
 * @code
 * uint8_t key = Keypad_GetPress();
 * if (key == 1U) {
 *     ShowSpectrumPage();
 * } else if (key == 2U) {
 *     ShowWaveformPage();
 * }
 * @endcode
 */
uint8_t Keypad_GetPress(void);

#endif
