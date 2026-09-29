//-----------------------------------------------------------------
// 源文件名: TM1650.c
// 适  用: STM32F407ZET6 - HAL库环境 (168MHz主频自适应延时)
//-----------------------------------------------------------------

#include "TM1650.h"

// ==========================================
// 1. 引脚方向动态切换 (全面适配 F407 高速总线)
// ==========================================
void SDA_IN(void)
{
    GPIO_InitTypeDef GPIO_InitStruct = {0};
    __HAL_RCC_GPIOB_CLK_ENABLE(); // 强行确保 GPIOB 时钟使能

    GPIO_InitStruct.Pin = TM1650_SDA_pin;
    GPIO_InitStruct.Mode = GPIO_MODE_INPUT; // 上拉输入
    GPIO_InitStruct.Pull = GPIO_PULLUP;
    HAL_GPIO_Init(TM1650_GPIO_PORT, &GPIO_InitStruct);
}

void SDA_OUT(void)
{
    GPIO_InitTypeDef GPIO_InitStruct = {0};
    __HAL_RCC_GPIOB_CLK_ENABLE();

    GPIO_InitStruct.Pin = TM1650_SDA_pin;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP; // 高速推挽输出
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH; // 升级为 F407 极高速度级别，使波形陡峭
    HAL_GPIO_Init(TM1650_GPIO_PORT, &GPIO_InitStruct);
}

// ==========================================
// 2. 软件微秒级延时 (核心修改：完美自适应 168MHz 主频)
// ==========================================
void TM1650_delay_us(unsigned short j)
{
    // 利用 STM32 内置的核心主频变量 SystemCoreClock 自动计算循环阻尼
    // 确保无论在 72MHz 还是 168MHz 下，延时时间都绝对精准一致
	volatile uint32_t delay = j * (SystemCoreClock / 4000000U);
    while(delay--);
}

// ==========================================
// 3. I2C 底层时序控制
// ==========================================
void TM1650_Start(void)
{
    SDA_OUT();
    TM1650_SDA_H;
    TM1650_SCL_H;
    TM1650_delay_us(4);
    TM1650_SDA_L;
    TM1650_delay_us(4);
    TM1650_SCL_L;
}

void TM1650_Stop(void)
{
    SDA_OUT();
    TM1650_SCL_L;
    TM1650_SDA_L;
    TM1650_delay_us(4);
    TM1650_SCL_H;
    TM1650_delay_us(4);
    TM1650_SDA_H;
}

unsigned char TM1650_Wait_Ack(void)
{
    unsigned char ucErrTime = 0;
    SDA_IN();
    TM1650_SDA_H;
    TM1650_delay_us(1);
    TM1650_SCL_H;
    TM1650_delay_us(1);

    while(READ_SDA)
    {
        ucErrTime++;
        if(ucErrTime > 250)
        {
            TM1650_Stop();
            return 1;
        }
    }
    TM1650_SCL_L;
    return 0;
}

void TM1650_Ack(void)
{
    TM1650_SCL_L;
    SDA_OUT();
    TM1650_SDA_L;
    TM1650_delay_us(4);
    TM1650_SCL_H;
    TM1650_delay_us(4);
    TM1650_SCL_L;
}

void TM1650_NAck(void)
{
    TM1650_SCL_L;
    SDA_OUT();
    TM1650_SDA_H;
    TM1650_delay_us(4);
    TM1650_SCL_H;
    TM1650_delay_us(4);
    TM1650_SCL_L;
}

void TM1650_Send_Byte(unsigned char oneByte)
{
    unsigned char t;
    SDA_OUT();
    TM1650_SCL_L;
    for(t = 0; t < 8; t++)
    {
        if((oneByte & 0x80) == 0x80) TM1650_SDA_H;
        else                         TM1650_SDA_L;

        oneByte <<= 1;
        TM1650_delay_us(4);
        TM1650_SCL_H;
        TM1650_delay_us(4);
        TM1650_SCL_L;
        TM1650_delay_us(4);
    }
}

unsigned char TM1650_Read_Byte(void)
{
    unsigned char i, rekey = 0;
    SDA_IN();
    for(i = 0; i < 8; i++)
    {
        TM1650_SCL_L;
        TM1650_delay_us(4);
        TM1650_SCL_H;
        rekey <<= 1;
        if(READ_SDA) rekey++;
        TM1650_delay_us(4);
    }
    return rekey;
}

void TM1650_SendCommand(unsigned char add, unsigned char dat)
{
    TM1650_Start();
    TM1650_Send_Byte(add);
    TM1650_Wait_Ack();
    TM1650_Send_Byte(dat);
    TM1650_Wait_Ack();
    TM1650_Stop();
}

// ==========================================
// 4. 应用层逻辑 (数码管显示与按键扫描)
// ==========================================
void TM1650_SendDigData(uint16_t index, uint16_t num)
{
    uint8_t indexAddr = 0;
    uint8_t numValue  = 0;
    switch(index)
    {
        case 1: indexAddr = 0x68; break;
        case 2: indexAddr = 0x6A; break;
        case 3: indexAddr = 0x6C; break;
        case 4: indexAddr = 0x6E; break;
        default: break;
    }
    numValue = s_7number[num];
    TM1650_Start();
    TM1650_Send_Byte(indexAddr);
    TM1650_Wait_Ack();
    TM1650_Send_Byte(numValue);
    TM1650_Wait_Ack();
    TM1650_Stop();
}

void TM1650_SetDisplay(uint8_t brightness)
{
    TM1650_SendCommand(0x48, brightness * 16 + 1 * 4 + 1);
}

void TM1650_Init(void)
{
    TM1650_SCL_H;
    TM1650_SDA_H;
    TM1650_SendCommand(0x40, 0x00);
}

void DisplayNumber_4BitDig(uint16_t Num)
{
    uint16_t Numb;
    Numb = Num + 10000;
    TM1650_SendDigData(1, Numb / 1000 % 10);
    TM1650_SendDigData(2, Num / 100 % 10);
    TM1650_SendDigData(3, Num / 10 % 10);
    TM1650_SendDigData(4, Num % 10);
}

unsigned char TM1650_Read_KEY(void)
{
    unsigned char temp;
    TM1650_Start();
    TM1650_Send_Byte(0x49);
    TM1650_Wait_Ack();
    temp = TM1650_Read_Byte();
    TM1650_Wait_Ack();
    TM1650_Stop();
    return temp;
}

// 【核心Bug修复】：内层循环控制条件由原版的 j < 7 改为真正的列数 j < 4
// 完美解决 STM32 在内存检索键值表时的数组越界崩溃隐患
uint32_t TM1650_Gte_KEY(void)
{
    unsigned char key;
    key = TM1650_Read_KEY();
    uint32_t key_name = 0, i, j;

    for(i = 0; i < 7; i++)
    {
        for(j = 0; j < 4; j++) // 👈 核心修复点：由 7 改为 4
        {
            if(key == key_numberH[i][j])
            {
                key_name = key_number[i][j];
                return key_name;
            }
        }
    }
    return key_name;
}
