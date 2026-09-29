#include "TM1638.h"
#include <stdio.h>   // 解决 snprintf 警告
#include <string.h>  // 解决 strlen 警告
/* 0~F 共阴数码管段码表 */
const uint8_t TM1638_DIGIT_TAB[16] = {
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07,
    0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
};

/* 微秒级延时：168MHz主频下，count=30 约对应 1us */
static void TM1638_DelayUs(volatile uint32_t us)
{
    volatile uint32_t count = us * 30; // 恢复合理的微秒级延时
    while (count--) {
        __NOP();
    }
}

/* 引脚控制宏 */
#define STB_HIGH()   HAL_GPIO_WritePin(TM1638_STB_GPIO_PORT, TM1638_STB_PIN, GPIO_PIN_SET)
#define STB_LOW()    HAL_GPIO_WritePin(TM1638_STB_GPIO_PORT, TM1638_STB_PIN, GPIO_PIN_RESET)

#define CLK_HIGH()   HAL_GPIO_WritePin(TM1638_CLK_GPIO_PORT, TM1638_CLK_PIN, GPIO_PIN_SET)
#define CLK_LOW()    HAL_GPIO_WritePin(TM1638_CLK_GPIO_PORT, TM1638_CLK_PIN, GPIO_PIN_RESET)

#define DIO_HIGH()   HAL_GPIO_WritePin(TM1638_DIO_GPIO_PORT, TM1638_DIO_PIN, GPIO_PIN_SET)
#define DIO_LOW()    HAL_GPIO_WritePin(TM1638_DIO_GPIO_PORT, TM1638_DIO_PIN, GPIO_PIN_RESET)

#define READ_DIO()   HAL_GPIO_ReadPin(TM1638_DIO_GPIO_PORT, TM1638_DIO_PIN)

/**
  * @brief  写入一个字节数据 (LSB First)
  */
static void TM1638_WriteByte(uint8_t data)
{
    for (uint8_t i = 0; i < 8; i++) {
        CLK_LOW();
        TM1638_DelayUs(2);
        if (data & 0x01) {
            DIO_HIGH();
        } else {
            DIO_LOW();
        }
        data >>= 1;
        CLK_HIGH();
        TM1638_DelayUs(2);
    }
}

/**
  * @brief  读取一个字节数据 (LSB First)
  * @note   开漏输出模式下，只需要先将 DIO 置高，即可直接读取引脚
  */
static uint8_t TM1638_ReadByte(void)
{
    uint8_t data = 0;

    DIO_HIGH(); // 释放 DIO 总线，依靠上拉电阻拉高，等待 TM1638 驱动

    for (uint8_t i = 0; i < 8; i++) {
        data >>= 1;
        CLK_LOW();
        TM1638_DelayUs(2);
        CLK_HIGH();
        TM1638_DelayUs(2);
        if (READ_DIO() == GPIO_PIN_SET) {
            data |= 0x80;
        }
    }
    return data;
}

/**
  * @brief  发送命令字
  */
static void TM1638_WriteCmd(uint8_t cmd)
{
    STB_LOW();
    TM1638_WriteByte(cmd);
    STB_HIGH();
}

/**
  * @brief  初始化TM1638
  */
void TM1638_Init(void)
{
    STB_HIGH();
    CLK_HIGH();
    DIO_HIGH();

    /* 默认开启显示，设置亮度 level 3 (0x88 | 0x03) */
    TM1638_WriteCmd(0x8B);

    /* 清空所有显存 */
    TM1638_Clear();
}

/**
  * @brief  设置亮度
  * @param  brightness: 0~7
  */
void TM1638_SetBrightness(uint8_t brightness)
{
    if (brightness > 7) brightness = 7;
    TM1638_WriteCmd(0x88 | brightness);
}

/**
  * @brief  指定显存地址写入数据
  */
void TM1638_WriteData(uint8_t addr, uint8_t data)
{
    TM1638_WriteCmd(TM1638_CMD_DATA_SET | 0x04); // 固定地址模式 0x44
    STB_LOW();
    TM1638_WriteByte(TM1638_CMD_ADDR_SET | (addr & 0x0F));
    TM1638_WriteByte(data);
    STB_HIGH();
}

/**
  * @brief  控制单个LED (D1~D8)
  * @param  led_num: 1~8
  * @param  state: 0关，1开
  */
void TM1638_SetLED(uint8_t led_num, uint8_t state)
{
    if (led_num < 1 || led_num > 8) return;
    // LED显存位于奇数地址: 0x01, 0x03, 0x05, 0x07, 0x09, 0x0B, 0x0D, 0x0F
    uint8_t addr = 2 * (led_num - 1) + 1;
    TM1638_WriteData(addr, state ? 1 : 0);
}

/**
  * @brief  控制全部8个LED
  * @param  led_mask: Bit0对应D1, Bit7对应D8
  */
void TM1638_SetAllLEDs(uint8_t led_mask)
{
    for (uint8_t i = 0; i < 8; i++) {
        TM1638_SetLED(i + 1, (led_mask >> i) & 0x01);
    }
}

/**
  * @brief  在指定位置显示段码 (0~7位，从左至右)
  */
void TM1638_DisplaySeg(uint8_t pos, uint8_t seg)
{
    if (pos > 7) return;
    // 数码管显存位于偶数地址: 0x00, 0x02, 0x04, 0x06, 0x08, 0x0A, 0x0C, 0x0E
    TM1638_WriteData(2 * pos, seg);
}

/**
  * @brief  在指定位置显示十六进制数字 (0~F)
  */
void TM1638_DisplayHex(uint8_t pos, uint8_t num, uint8_t show_dp)
{
    if (pos > 7 || num > 15) return;
    uint8_t seg = TM1638_DIGIT_TAB[num];
    if (show_dp) seg |= 0x80; // 点亮dp (最高位)
    TM1638_DisplaySeg(pos, seg);
}

/**
  * @brief  显示整数 (右对齐)
  */
/**
  * @brief  显示整数 (右对齐)
  */
void TM1638_DisplayInt(int32_t num)
{
    char buf[16]; // 将缓冲区由 10 扩大到 16，彻底消除 -Wformat-truncation 警告
    int len;

    // 清空数码管
    for (uint8_t i = 0; i < 8; i++) {
        TM1638_DisplaySeg(i, 0x00);
    }

    if (num < 0) {
        snprintf(buf, sizeof(buf), "-%ld", (long)-num);
    } else {
        snprintf(buf, sizeof(buf), "%ld", (long)num);
    }

    len = strlen(buf);
    if (len > 8) len = 8; // 最长显示 8 字符

    uint8_t start_pos = 8 - len;
    for (uint8_t i = 0; i < len; i++) {
        if (buf[i] == '-') {
            TM1638_DisplaySeg(start_pos + i, 0x40); // '-' 的段码
        } else if (buf[i] >= '0' && buf[i] <= '9') {
            TM1638_DisplayHex(start_pos + i, buf[i] - '0', 0);
        }
    }
}

/**
  * @brief  清空显示和LED
  */
void TM1638_Clear(void)
{
    TM1638_WriteCmd(TM1638_CMD_DATA_SET); // 自动地址递增模式 0x40
    STB_LOW();
    TM1638_WriteByte(TM1638_CMD_ADDR_SET); // 设置起始地址 0xC0
    for (uint8_t i = 0; i < 16; i++) {
        TM1638_WriteByte(0x00);
    }
    STB_HIGH();
}

/**
  * @brief  读取按键状态
  * @note   TM1638读取4字节数据，按键映射关系如下:
  *         S1: Byte0 bit0, S2: Byte1 bit0, S3: Byte2 bit0, S4: Byte3 bit0
  *         S5: Byte0 bit4, S6: Byte1 bit4, S7: Byte2 bit4, S8: Byte3 bit4
  * @retval 按键位图 (Bit0 -> S1, Bit7 -> S8)
  */
uint8_t TM1638_ReadKeys(void)
{
    uint8_t c[4];
    uint8_t key_mask = 0;

    STB_LOW();
    TM1638_WriteByte(TM1638_CMD_READ_KEYS); // 发送读按键命令 0x42

    TM1638_DelayUs(2); // TM1638要求的时序等待

    for (uint8_t i = 0; i < 4; i++) {
        c[i] = TM1638_ReadByte();
    }
    STB_HIGH();

    // 解析按键按位状态
    for (uint8_t i = 0; i < 4; i++) {
        if (c[i] & 0x01) {
            key_mask |= (1 << i);       // S1 ~ S4 (Bit 0 ~ Bit 3)
        }
        if (c[i] & 0x10) {
            key_mask |= (1 << (i + 4)); // S5 ~ S8 (Bit 4 ~ Bit 7)
        }
    }

    return key_mask;
}

/**
  * @brief  获取按下的单键编号 (1~8)，无按键返回0
  */
uint8_t TM1638_GetKeyNum(void)
{
    uint8_t mask = TM1638_ReadKeys();
    if (mask == 0) return 0;

    for (uint8_t i = 0; i < 8; i++) {
        if (mask & (1 << i)) {
            return (i + 1); // 返回 1 ~ 8
        }
    }
    return 0;
}
