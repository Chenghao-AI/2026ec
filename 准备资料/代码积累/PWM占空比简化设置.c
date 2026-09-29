#include "ti_msp_dl_config.h"

uint32_t period = CPUCLK_FREQ /1000;

void Set_Duty(float duty, uint8_t channel)
{
    uint32_t CompareValue;
    CompareValue = period*(1-duty);
    if(channel == 0)
    {
        DL_TimerG_setCaptureCompareValue(PWM_0_INST, CompareValue, DL_TIMER_CC_0_INDEX);
    }
    else if (channel == 1)
    {
        DL_TimerG_setCaptureCompareValue(PWM_0_INST, CompareValue, DL_TIMER_CC_1_INDEX);
    }
}

void Set_Freq(uint32_t freq)
{
    period = PWM_0_INST_CLK_FREQ / freq;
    DL_Timer_setLoadValue(PWM_0_INST,period);
}

int main(void)
{
    SYSCFG_DL_init();
    
    DL_TimerG_startCounter(PWM_0_INST);
 

    while (1) {
        if(!DL_GPIO_readPins(GPIO_Button_PORT ,GPIO_Button_PIN_S2_PIN )){
        Set_Freq(500);
        Set_Duty(0.35,0);
        Set_Duty(0.45,1);
        }
        else{
        Set_Freq(1000);
        Set_Duty(0.75,0);
        Set_Duty(0.6,1);
        }
        }
    }

