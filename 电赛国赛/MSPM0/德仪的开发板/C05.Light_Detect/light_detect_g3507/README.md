## Example Summary

Toggles One GPIO pin using HW toggle register, while several task print msg to UART.

## Peripherals & Pin Assignments

| Peripheral | Pin | Function |
| --- | --- | --- |
| GPIOA | PA0 | Standard Output-LED |
| GPIOB | PB26 | RGB LED的红灯 |
| GPIOB | PB27 | RGB LED的绿灯 |
| GPIOB | PB22 | RGB LED的蓝灯 |
| GPIOA | PA11 | UART RX on CoreBoard |
| GPIOA | PA10 | UART TX on CoreBoard |
| GPIOB | PB1 | 按键KEY1，控制偏置值增大 |
| GPIOB | PB2 | 按键KEY2，控制偏置值减小 |
| GPIOB | PB3 | 按键KEY3，控制增益值增大 |
| GPIOB | PB4 | 按键KEY4，控制增益值减小 |
| DAC0 | PA15 | DAC0的输出，内部直接送给OPA1，无需连线 |
| OPA1 | PA17 | OPA1的模拟信号-输入，采用光敏输出连接来测试 |
| OPA1 | --- | OPA1的模拟信号+输入来自DAC12的输出 |
| OPA1 | PA16 | OPA1的输出，内部连接OPA0，无需连线 |
| OPA0 | --- | OPA1的模拟信号-接地，采用正放大模式 |
| OPA0 | --- | OPA0的模拟信号+输入来自OPA1的输出 |
| OPA0 | PA22 | OPA0的输出，内部连接ADC0，无需连线 |
| ADC0 | --- | ADC输入来自OPA0的输出，无线连线 |
| GPIOA | PA28 | 采用杜邦线连接PA28与OLED的SDA线（J7接插件） |
| GPIOA | PA31 | 采用杜邦线连接PA31与OLED的SCL线（J7接插件） |
| SYSCTL | --- | --- |
| EVENT | --- | --- |

## 例程设计思路
1. 采用MSPM0G3507对光敏传感器进行采样，显示采样值；  
2. 充分利用G3507内部OPA，无需外部电路，做到可调偏置、可调增益的完整例程；  
3. 一级放大电路使用OPA1，其Sig+输入来自片内DAC12的输出，Sig-来自光敏电路的输出，OPA1采用RTAP模式，构成一个反向偏置电路；  
4. 二级放大电路使用OPA0，采用正向可调增益的放大模式，缺省为2倍放大模式；  
5. 片内DAC12输出将直接影响偏置电压，缺省为1.5V；  
6. 整体程序采用时间片轮询的程序框架，其中框架代码主要在slice.c文件；  
7. 任务代码主要在task_main.c，该文件集中几乎所有任务级函数；  
    7.1 按键检测采用连续多次采样来去抖，同时输入值（偏置值、放大倍数选择挡位）保持一秒不变，才实际设置OPA工作参数；  
    7.2 ADC保持2秒采样一次，采样结果直接显示在OLED屏；  
    7.3 应用任务还存在UART上的输入回环显示的任务、RGB灯/LED灯每500ms变化等其他业务；  
8. OPA0/OPA1/DAC12等外设工作模式均在light_detect.syscfg文件配置完成；  
    8.1 板级底层的OLED初始化和及封装代码，主要在softi2c.c、oled.c等文件；  
    8.2 printf及UART底层的实现及封装代码在printf.c、uart.c文件中；  
    8.2 所有底层代码封装、调用，均汇聚到hardware.c文件中，被上层业务调用；  
9. 目前仅实现采样数据直接显示，若用户需要精确细化该应用，需要做如下工作：  
    9.1 DAC12输出的各偏置值的标定，从而形成精确的偏置调整查找表；  
    9.2 数字可调增益的各放大倍数的精确标定，形成不同挡位的精确增益值；  
    9.3 光敏检测电路中的电阻值的标定；  
    9.4 根据上述标定工作，形成最后的流明转换公式。  

## Example Usage
Compile, load and run the example.  
1. LED和RGB LED每0.5秒变化一次  
2. ADC每2秒采样一次，ADC采样值在OLED屏上刷新一次  
3. 四个按键控制偏置值、放大挡位值，当输入1秒钟没有变化，才更新实际设置值  
4. 模拟信号从OPA1的负极输入，其正极采用DAC输出，放大倍数设置为-1，为偏置减除电路  
5. DAC的设置值由全局变量偏置值决定  
6. OPA1的输出直接输给OPA0的输入，可以数字调整放大倍数，由放大挡位值决定  

