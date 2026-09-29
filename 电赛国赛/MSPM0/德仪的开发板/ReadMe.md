# [TI MSPM0+(MSPM0L1306/MSPM0G3507)开源例程](https://gitee.com/NEagle/msp-lab-m0)
# 核心板+底板的例程目录

#### 介绍
本目录将集中MSPM0L1306的核心板、以及对应底板的例程。核心板产品图片见下图，其对应底板及相关产品见本文档最后的图片。
![M0L1306CoreBoard-S.png](./doc/M0L1306CoreBoard-S.png "MSPM0核心板实物图")

【2024-03-24】起，增加了MSPM0G3507的核心板、统一基座的资料。其中统一基座将兼容L1306和G3507两种核心板，后续例程将都从原有基座转移到统一基座上。  
##### [统一基座原理图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/SCH_MSPM0%E5%9F%BA%E5%BA%A7.pdf)  [统一基座丝印图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/PCB_MSPM0%E5%9F%BA%E5%BA%A7.pdf)

##### [核心板器件硬件原理图库及PCB封装库](./Hardware/)

##### MSPM0L1306核心板 管脚图
![M0L1306Core.png](./doc/M0L1306Core.png "MSPM0L1306核心板管脚图")

##### MSPM0G3507核心板 管脚图
![M0G3507Core.png](./doc/M0G3507Core.png "MSPM0G3507核心板管脚图")

#### 软件架构
软件架构说明  
    1、例程A** 是采用以裸程序框架，将M0例程作为单片机讲解的初级入门程序，即只涉及绝大多数单片机、处理器均具备的GPIO、中断、基本定时器组成的最简处理器例程  
    2、例程B** 是采用裸程序验证MSPM0L1306的各个具有特色的外设功能的例程  
    3、例程C** 是将站在系统角度，采用单片机时间片轮询的多任务框架的模块化程序、应用案例  
    3、例程D** 是使用RTOS（FreeRTOS）作为M0+的基础程序框架的例程代码  

#### 具体例程

##### 1、A01.LedFlash - LED闪烁例程（L1306 & G3507）[【C:2023-11-28，U:2024-04-03】](https://gitee.com/NEagle/msp-lab-m0/tree/master/A01.LedFlash) [【B站视频】](https://www.bilibili.com/video/BV1RH4y1J7JE/) 
##### 2、A02.GPIO_Output - GPIO输出例程（L1306 & G3507） [【C:2023-12-08，U:2024-04-27】](https://gitee.com/NEagle/msp-lab-m0/tree/master/A02.GPIO_Output)  
##### 3、A03.GPIO_Combine - GPIO组合输出例程（L1306 & G3507） [【C:2023-12-10，U:2024-04-27】](https://gitee.com/NEagle/msp-lab-m0/tree/master/A03.GPIO_Combine)  
##### 4、A04.GPIO_Key - GPIO之按键输入例程（L1306 & G3507） [【C:2023-12-10，U:2024-04-27】](https://gitee.com/NEagle/msp-lab-m0/tree/master/A04.GPIO_Key)  
##### 5、A05.Interrupt_key - 中断模式-按键中断例程（L1306 & G3507） [【C:2023-12-11，U:2024-04-27】](https://gitee.com/NEagle/msp-lab-m0/tree/master/A05.Interrupt_Key)  
##### 6、A06.Simple_Timer - 基本定时器（L1306 & G3507） [【C:2023-12-12，U:2024-04-28】](https://gitee.com/NEagle/msp-lab-m0/tree/master/A06.Simple_Timer)  
##### 7、A07.Multi_Tube - 扫描数码管（L1306 & G3507） [【C:2023-12-12，U:2024-04-28】](https://gitee.com/NEagle/msp-lab-m0/tree/master/A07.Multi_Tube)  
##### 8、B01.Pwm_Out - PWM控制LED例程（L1306 & G3507）[【C:2023-12-20，U:2024-04-29】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B01.Pwm_Out)
##### 9、B02.Capture_App - TIMx捕获例程（L1306 & G3507）[【C:2024-05-1】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B02.Capture_App)
##### 10、B03.Uart_Loopback - 串口回环测试例程（L1306 & G3507）[【C:2023-12-24，U:2024-04-29】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B03.Uart_Loopback)
##### 11、B04.I2C_OLED - I2C外设驱动OLED例程（L1306 & G3507）[【C:2024-01-11，U:2024-04-29】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B04.I2C_OLED)
##### 12、B04-1.SoftI2C_OLED - GPIO模拟I2C总线协议驱动OLED例程（L1306 & G3507）[【C:2024-01-12，U:2024-04-29】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B04-1.SoftI2C_OLED)
##### 13、B05.Spi_Bus - SPI FLASH读写测试例程（L1306 & G3507）[【C:2024-05-06】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B05.Spi_Bus)
##### 14、B06.Adc_Temp - ADC采样实现NTC温度检测（L1306 & G3507）[【C:2024-05-07】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B06.Adc_Temp)
##### 15、B07.Opa_Uart - UART修改OPA放大倍数实验（L1306 & G3507）[【C:2024-05-09】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B07.Opa_Uart)
##### 16、B08.Comp_Light - 片内模拟比较器实验（L1306 & G3507）[【C:2024-05-15】](https://gitee.com/NEagle/msp-lab-m0/tree/master/B08.Comp_Light)
##### 17、B09.拟增加硬件CRC校验模块例程
##### 18、C01.Time_Slice - 时间片轮询多任务系统例程（L1306 & G3507）[【C:2024-01-21，U:2024-04-03】](https://gitee.com/NEagle/msp-lab-m0/tree/master/C01.Time_Slice)
##### 19、C05.Light_Detect - 光敏检测例程（L1306 & G3507）[【C:2024-03-24，U:2024-04-03】](https://gitee.com/NEagle/msp-lab-m0/tree/master/C05.Light_Detect) [【B站视频】](https://www.bilibili.com/video/BV1fr42147Ly/)

#### 参考资源
##### 1、[L1306数据手册](https://www.ti.com.cn/cn/lit/ds/symlink/mspm0l1306.pdf)
##### 2、[技术参考手册/用户指南](https://www.ti.com.cn/cn/lit/ug/zhcuan6c/zhcuan6c.pdf)
##### 3、[SDK参考例程](https://dev.ti.com/tirex/global?id=MSPM0-SDK)
##### 4、[L1306底板原理图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/SCH_MSPM0%E5%BA%95%E6%9D%BF.pdf)
##### 5、[L1306核心板原理图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/SCH_MSPM0%E6%A0%B8%E5%BF%83%E6%9D%BF.pdf)
##### 6、[G3507核心板原理图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/SCH_MSPM0G3507%E6%A0%B8%E5%BF%83%E6%9D%BF.pdf)
##### 7、[G3507核心板丝印图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/PCB_MSPM0G3507%E6%A0%B8%E5%BF%83%E6%9D%BF.pdf)
##### 8、[统一基座原理图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/SCH_MSPM0%E5%9F%BA%E5%BA%A7.pdf)
##### 9、[统一基座丝印图](https://gitee.com/NEagle/msp-lab-m0/raw/master/doc/PCB_MSPM0%E5%9F%BA%E5%BA%A7.pdf)
##### 10、[淘宝链接](https://item.taobao.com/item.htm?abbucket=10&id=790044563339)

#### 更多产品图片
![M0L1306BaseBoard-S.png](./doc/M0L1306BaseBoard-S.png "MSPM0底板实物图")
![Product-S.png](./doc/Product-S.png "MSPM0核心板+底板实物图")


