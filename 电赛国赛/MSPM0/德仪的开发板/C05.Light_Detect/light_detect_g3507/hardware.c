/*
 * hardware.c
 *
 *  Created on: 2024年3月23日
 *      Author: junying
 */

#include "hardware.h"
#include "oled.h"

//OLED屏初始化
void panel_init(void)
{
    OLED_Init();
    OLED_ColorTurn(0);
    OLED_DisplayTurn(0);

    OLED_ShowChinese(0,0,0,16,1);//德
    OLED_ShowChinese(18,0,1,16,1);//研
    OLED_ShowChinese(36,0,2,16,1);//电
    OLED_ShowChinese(54,0,3,16,1);//科
    OLED_ShowChinese(72,0,6,16,1);//实
    OLED_ShowChinese(90,0,7,16,1);//验
    OLED_ShowChinese(108,0,8,16,1);//室
    OLED_ShowString(0,16,(u8 *)"Read Adc = 0000 ",16,1);
    OLED_ShowString(0,32,(u8 *)"Gain= 1 |In= 1  ",16,1);
    OLED_ShowString(0,48,(u8 *)"Thr=1500|In=1500",16,1);
    OLED_Refresh();
}

//定义ADC完成的标志
volatile bool gCheckADC;
//ADC外设初始化
void adc_init(void)
{
    //使能ADC的中断
    NVIC_EnableIRQ(ADC12_0_INST_INT_IRQN);
    //清除标志位
    gCheckADC = false;
    //ADC开始采样
    DL_ADC12_startConversion(ADC12_0_INST);
}

//读取ADC采样值
//返回值：false - 没有转换完成    true - 读取成功，结果在 *pVal
bool getAdcValue(uint16_t *pVal)
{
    if(gCheckADC == false)
        return false;
    *pVal = DL_ADC12_getMemResult(ADC12_0_INST, DL_ADC12_MEM_IDX_0);
    gCheckADC = false;
    DL_ADC12_enableConversions(ADC12_0_INST);
    DL_ADC12_startConversion(ADC12_0_INST);
    return true;
}

//设置DAC的偏置值，参数val是输出电源毫伏值（范围0~3300）
void dac_SetVal(uint32_t val)
{
    uint32_t DAC_value;
    if (val > 3300)
        val = 3300;
    DAC_value = (val *4095)/3300;

    DL_DAC12_output12(DAC0, DAC_value);
    DL_DAC12_enable(DAC0);
}

//设置OPA放大系数（输入参数为0~5）
void opa_ChgGain(uint8_t val)
{
    // OPA设置参数数据结构
    static DL_OPA_Config gMyConfig0 = {
        .pselChannel    = DL_OPA_PSEL_RTOP,
        .nselChannel    = DL_OPA_NSEL_RTAP,
        .mselChannel    = DL_OPA_MSEL_GND,
        .gain           = DL_OPA_GAIN_N1_P2,
        .outputPinState = DL_OPA_OUTPUT_PIN_ENABLED,
        .choppingMode   = DL_OPA_CHOPPING_MODE_ADC_AVERAGING,
    };

    if(val > 5) //超过最大值，则不处理
        return;
    gMyConfig0.gain = (((uint32_t) val) << OA_CFG_GAIN_OFS);
    //CurGain = val;

    DL_OPA_disable(OPA_0_INST);
    DL_OPA_init(OPA_0_INST, (DL_OPA_Config *) &gMyConfig0);
    DL_OPA_setGainBandwidth(OPA_0_INST, DL_OPA_GBW_HIGH);

    DL_OPA_enable(OPA_0_INST);
    return;
}

//Uart初始化
void Uart_Init(void)
{
    NVIC_ClearPendingIRQ(UART_0_INST_INT_IRQN);     //Clear the IRQ Flag
    NVIC_EnableIRQ(UART_0_INST_INT_IRQN);           //Enable the Received Interrupt
}

//设置RGB灯状态，参数n的后3bit是RGB的状态值（bit0-R bit1-G  bit2-B），0-灭 1-亮
void SetRGB(uint8_t n)
{
    SetRed(n & 0x01);
    SetGreen(n & 0x02);
    SetBlue(n & 0x04);
}

//Led初始化
void Led_Init(void)
{
    /* Default: LED1 OFF */
    SetLed(0);
    SetRGB(0);
}

//硬件系统初始化函数
void hardware_init(void)
{
    panel_init();
    adc_init();
    dac_SetVal(ShiftDefault);
    Uart_Init();
}

//ADC中断服务程序，完成则设置标志
void ADC12_0_INST_IRQHandler(void)
{
    switch (DL_ADC12_getPendingInterrupt(ADC12_0_INST)) {
        case DL_ADC12_IIDX_MEM0_RESULT_LOADED:
            gCheckADC = true;
            break;
        default:
            break;
    }
}
