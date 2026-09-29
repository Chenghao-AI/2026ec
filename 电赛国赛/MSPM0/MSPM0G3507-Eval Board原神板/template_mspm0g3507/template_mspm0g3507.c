
#include "ti_msp_dl_config.h"

#define DELAY (20000000)    // 使用外部晶振20MHz的时钟直供CPU频率时，延迟1秒对应的周期数大约就是20M

void LedOutput(unsigned char val)
{
    if(val & 0x1)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_Red_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_Red_PIN);
    if(val & 0x2)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_Green_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_Green_PIN);
    if(val & 0x4)
        DL_GPIO_clearPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_Blue_PIN);
    else
        DL_GPIO_setPins(GPIO_LEDS_PORT, GPIO_LEDS_LED_Blue_PIN);
}

int main(void)
{
    /* 由于时钟树中设置了时钟信号输出，将HFCLK输出到管脚
       可以在PA31上观测到晶振同频率的方波为20MHz 
       但是注意到这里我们手写的代码根本没有关于此功能的语句
    */
    unsigned char cnt = 0;
    SYSCFG_DL_init();

    /* 默认关闭所有灯 */
    LedOutput(0); 

    while (1) {
        /* LED 会周期性地按照下列色彩变化
           灭-红-绿-黄-蓝-洋红-青-白
        */
        delay_cycles(DELAY);
        LedOutput(cnt++);   //LEDs changed on bit
    }
}
