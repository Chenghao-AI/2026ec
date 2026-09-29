//-----------------------------------------------------------------
// 源文件名: adf4351.c
//-----------------------------------------------------------------

#include "ADF4351.h"

// R为参考分频器的数值。板载25M晶振，鉴相频率卡在0.1MHz，故R为125
uint32_t R = 125;

// 内部私有微秒延时
static void adf4351_delay_us(uint32_t us)
{
    uint32_t delay = us * (SystemCoreClock / 4000000U);
    while(delay--);
}

// GPIO 引脚初始化
void GPIO_ADF4351_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    __HAL_RCC_GPIOD_CLK_ENABLE();

    // 配置推挽输出 (PD1, PD2, PD3, PD4)
    GPIO_InitStruct.Pin = GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3 | GPIO_PIN_4;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
    HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

    // 配置 MUX 锁定检测线为浮空输入 (PD0)
    GPIO_InitStruct.Pin = GPIO_PIN_0;
    GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

    ADF_CLK_Clr;
    ADF_DATA_Clr;
    ADF_LE_Set;
    ADF_CE_Set;
}

// 软件模拟 SPI 写入 32 位控制字
void ADF4351_Wdata(uint32_t date)
{
    uint8_t i;
    ADF_CLK_Clr;
    ADF_LE_Clr;
    adf4351_delay_us(1);

    for(i = 0; i < 32; i++)
    {
        if(date & 0x80000000)
            ADF_DATA_Set;
        else
            ADF_DATA_Clr;

        date <<= 1;
        adf4351_delay_us(1);

        ADF_CLK_Set;
        adf4351_delay_us(1);
        ADF_CLK_Clr;
    }

    adf4351_delay_us(1);
    ADF_LE_Set;
    adf4351_delay_us(1);
}

// 基础初始化：仅配置引脚并使能芯片
void ADF4351_Init(void)
{
    GPIO_ADF4351_Init();
    ADF_CE_Set;
    adf4351_delay_us(5);
    ADF_CLK_Clr;
    ADF_LE_Set;
    ADF_DATA_Clr;
}

//-----------------------------------------------------------------
// 函数功能: 核心算法 - 输入任意频率，自动计算并配置锁相环
// 参数说明: target_freq_mhz -> 目标输出频率 (例如: 40.0 或 105.4)
//-----------------------------------------------------------------
void ADF4351_SetFrequency(double target_freq_mhz)
{
    uint32_t rf_div = 1;
    uint32_t rf_div_select = 0; // 对应 R4 寄存器中的二进制编码

    // 1. 自动判断核心 VCO 频率范围，选择物理硬分频比 [cite: 28, 1393]
    // 确保内部 VCO 始终安全工作在 2200 MHz 至 4400 MHz 区间
    if (target_freq_mhz >= 2200.0) {
        rf_div = 1;
        rf_div_select = 0; // 000 -> 1分频 [cite: 1190]
    } else if (target_freq_mhz >= 1100.0) {
        rf_div = 2;
        rf_div_select = 1; // 001 -> 2分频 [cite: 1190]
    } else if (target_freq_mhz >= 550.0) {
        rf_div = 4;
        rf_div_select = 2; // 010 -> 4分频 [cite: 1190]
    } else if (target_freq_mhz >= 275.0) {
        rf_div = 8;
        rf_div_select = 3; // 011 -> 8分频 [cite: 1190]
    } else if (target_freq_mhz >= 137.5) {
        rf_div = 16;
        rf_div_select = 4; // 100 -> 16分频 [cite: 1190]
    } else if (target_freq_mhz >= 68.75) {
        rf_div = 32;
        rf_div_select = 5; // 101 -> 32分频 [cite: 1190]
    } else {
        rf_div = 64;
        rf_div_select = 6; // 110 -> 64分频 [cite: 1190]
    }

    // 2. 逆推内部压控振荡器 (VCO) 的实际谐振工作频率
    double vco_freq = target_freq_mhz * rf_div;

    // 3. 计算鉴频鉴相器 $f_{PFD}$ 的工作时钟 (当前固定为 25MHz / 125 = 0.2MHz)
    double f_pfd = 25.0 / (double)R;

    // 4. 计算整数分频器所需的 $INT$ 参数值 (加入 0.5 四舍五入防止浮点转换精度丢失)
    uint32_t int_val = (uint32_t)(vco_freq / f_pfd + 0.5);

    // 5. 动态合成 6 组 32 位全寄存器控制字 [cite: 642]
    uint32_t reg5 = 0x00580005; // R5: 设定数字锁定监测模式 [cite: 1296]

    // R4: 动态融入计算出的硬分频控制位（DB22:DB20）
    uint32_t reg4 = 0x0000A43C | (rf_div_select << 20);

    uint32_t reg3 = 0x006004B3; // R3: 消除漏电荷，设定防反冲脉冲
    uint32_t reg2 = 0x0D003FC2 | (R << 14); // R2: 灌入参考分频比参数 R
    uint32_t reg1 = 0x08008011; // R1: 维持 8/9 双模预分频模式 [cite: 1316]

    // R0: 动态融入算出来的硬件整数分频系数（DB30:DB15）[cite: 1307]
    uint32_t reg0 = 0x00000000 | (int_val << 15);

    // 6. 严格执行官方规定的倒序序列依次灌入芯片
    ADF4351_Wdata(reg5);
    ADF4351_Wdata(reg4);
    ADF4351_Wdata(reg3);
    ADF4351_Wdata(reg2);
    ADF4351_Wdata(reg1);
    ADF4351_Wdata(reg0); // 写入 R0 的瞬间触发寄存器双缓冲生效，芯片开始锁频 [cite: 577]
}
