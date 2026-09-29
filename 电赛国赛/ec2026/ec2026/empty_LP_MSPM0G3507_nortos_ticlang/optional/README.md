# optional：比赛现场可选的“预制菜”模块

这个目录保存可能用到、但不应与当前题目强绑定的器件接口和示例驱动。模块可以
留在工程里备用；未被入口或业务代码引用时，链接器通常会移除未使用的函数。

## 当前模块

- `rabi_gpio_serial.*`：只发送的轻量 GPIO 串行框架，适合非标准 DATA/CLK/LATCH
  时序；不等同于硬件 SPI，也不支持读回；
- `rabi_ad9850.*`：基于上述框架的 AD9850 40-bit 串行示例，只保留固定频率、
  输出开关和可选外部幅值控制，不包含调制功能；`AD9850_UI_QUICKSTART.md`
  给出了与 `examples/ad9850_ui/main.c` 独立入口对应的接线、电平转换、SysConfig
  和示波器联调步骤。
- `rabi_spi.*`：MSPM0 硬件 SPI 的 8-bit Controller 阻塞事务，支持手动 CS、
  全双工传输以及同一 CS 窗口内的“命令后读取”；
- `rabi_i2c.*`：MSPM0 硬件 I2C Controller 轮询事务，支持普通读写和 repeated-start
  写后读；
- `rabi_pwm.*`：基于 TIMA/TIMG Edge-Aligned 模式的启停、频率和占空比控制。
- `rabi_adc_oneshot.*`：ADC12 软件触发的单通道单次轮询读取；
- `rabi_adc_scan.*`：ADC12 软件触发的一次多 Memory 顺序扫描；
- `rabi_dma.*`：DMA 软件块复制，以及“外设到 RAM / RAM 到外设”的基础模板；
- `rabi_adc_dma.*`：ADC FIFO 打包样本并通过 DMA 搬入连续缓冲区的组合示例。
- `rabi_irq_defer.*`：ISR 置位、主循环取走的 32-bit 延后标志，包含 GPIO/DRDY/
  故障中断接入范例；
- `rabi_hw_timer.*`：TIMA/TIMG 周期和 One Shot 定时器，ISR 饱和累计到期次数；
- `rabi_pulse_capture.*`：Timer Combined Capture 测频率和占空比，包含
  TIMER_ERR_01 规避和无信号超时。
- `rabi_pid.*`：固定采样周期的位置式 PID，带输出/积分限幅、条件抗饱和、
  测量微分和微分低通，可直接接 UI 的 KP/KI/KD 与 PWM 千分比。
- `rabi_dac.*`：DAC12 单点原码、毫伏和千分比输出，带初始化自校准入口；
- `rabi_dac_wave.*`：DAC12 FIFO + DMA 波表，支持内置采样节拍或 Timer Event
  节拍、单次或循环输出。
- `rabi_filter.*`：滑动平均、EMA、中值滤波、输出变化率限制和迟滞判断；
- `rabi_signal.*`：ADC 样本块的均值、RMS、去直流 RMS、峰峰值和带迟滞测频，
  支持多通道交错缓冲区 stride。

使用某个模块前，先阅读其头文件顶部的接线、SysConfig、时序和最小示例。具体
器件的 GPIO 宏由配置结构体从业务层传入，所以模块本身不依赖固定的引脚命名。

新增陌生芯片时，优先复制 `rabi_ad9850.*` 的分层方式，而不是修改
`rabi_gpio_serial.*`：通用层只负责输出波形，器件层负责寄存器、帧格式和业务 API。

比赛代码中的中断统一遵守“ISR 只清标志、复制数据或记账，主循环做显示、通信和
计算”。毫秒 UI/按键任务用 `rabi_tick`，更精确的控制节拍和超时用
`rabi_hw_timer`，测外部脉冲用 `rabi_pulse_capture`，普通 GPIO/比较器/DRDY 通知用
`rabi_irq_defer`。头文件顶部都给出了 SysConfig 和最小接入示例。
