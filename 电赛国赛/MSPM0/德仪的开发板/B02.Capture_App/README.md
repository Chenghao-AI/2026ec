# 信号测量捕获的例程
## 定时器高级功能之捕获功能原理及使用

## 芯片管脚配置与使用
1、使用工程自带的*.syscfg文件，双击该文件启动system configuration配置M0芯片上的管脚使用  
    1.1、使用定时器的捕获功能（TIMG6的组合减计数捕获模式），对信号进行周期和占空比进行测量  
    1.2、为了方便测试，本例程使用定时器TIMG0的PWM输出一个占空比周期性调整的信号，提供捕获管脚信号输入    
    1.3、核心板LED在每捕获完成一次，LED翻转一次    
    1.4、每完成一次捕获，周期数、占空比值打印到UART输出  
2、在GPIO、Capture、PWM栏目，增加对应的管脚，做好命名、PinMux配置等  
3、C语言中，SYSCFG_DL_init()函数将初始化SysConfig配置的所有管脚功能，只要C代码include了ti_msp_dl_config.h头文件，我们均可以直接使用。  

## 例程B02：信号捕获例程实验

## 例程目的
#### 1. 验证定时器作为捕获功能的工作原理
#### 2. 验证本机PWM信号输出，通过杜邦线连接捕获管脚输入的环路测试

## 例程硬件资源
#### 1. 使用核心板上的LED灯，即PA0对应的LED灯，每成功捕获一次，LED翻转一次
#### 2. 核心板插入底板之后，使用杜邦线将下面对应管脚相连

| Pin | Destination | Function(L1306 连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| J6 PA14 | 信号输出 | 使用定时器TIMG1的减计数模式，生成PWM信号，每大约8秒，变化一次占空比 |
| J6 PA12 | 信号输入 | 使用定时器TIMG0的组合减计数模式，对输入信号进行捕获测量（周期数、占空比） |
| 板载PA22 | UART RX | 板载UART0的RXD信号，UART0作为捕获结果输出 |
| 板载PA23 | UART TX | 板载UART0的TXD信号，UART0作为捕获结果输出 |

| Pin | Destination | Function(G3507 连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| J6 PA12 | 信号输出 | 使用定时器TIMG0的减计数模式，生成PWM信号，每大约8秒，变化一次占空比 |
| J6 PA21 | 信号输入 | 使用定时器TIMG6的组合减计数模式，对输入信号进行捕获测量（周期数、占空比） |
| 板载PA11 | UART RX | 板载UART0的RXD信号，UART0作为捕获结果输出 |
| 板载PA10 | UART TX | 板载UART0的TXD信号，UART0作为捕获结果输出 |

##### 整体功能描述
按照硬件资源描述连接杜邦线，工程编译、下载、运行，可以看到  
    1、板卡的信号输出与信号输入需要相连，才能看到捕获结果输出，可以本板自己相连，也可以测量其他信号  
    2、核心板LED为指示捕获成功标志，每成功捕获一次，LED翻转一次      
    3、目前板载PWM信号输出的频率在1Hz左右（不精确），占空比是每八个周期变化一次      
    4、捕获输入采用组合捕获模式，同时捕获周期数和占空比数，打印的周期数的单位为32MHz的Clock数，以及占空比值（百分比）  
    5、PWM每切换一次占空比，第一个周期内的占空比因前后两个周期合并，导致占空比/周期数据是不准确的  
    6、目前采用最精确的时钟（不分频），进行信号测量，使用两个全局变量累计溢出值  

##### 同学们尝试
测试工程之后，同学们可以按照下面不同要求进行修改  
    1、修改定时器配置：修改sysconfig修改捕获信号通道、捕获模式、中断模式等调整，深入掌握TIMx的捕获功能      
    2、修改各连接管脚，根据对应连接方式，重新修改sysconfig的配置，使之工作正常  
    3、尝试对外部信号进行捕获测量，但需要注意的是输入信号的电平幅度符合TTL要求  
    4、尝试对捕获结果在数码管、OLED屏进行显示    

## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
#### 2. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 3. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）
    c. 在“Discovered projects:”窗口勾选“capture_app”选项
    d. 点击“Finish”按钮
#### 2. 编译工程，并生成TXT目标文件
    a. CCS菜单->Project->Build Project
#### 3. BSL下载TXT目标文件
    a. 使用USB Type-C线将M0核心板连接电脑USB口  
    b. 确保电脑已经安装CH340驱动（可以通过Windows设备属性查看此时能看到CH340的串口号）[驱动链接](https://www.wch.cn/downloads/CH341SER_EXE.html)  
    c. 运行BSL下载工具软件“MSPM0_BSL_GUI.exe”  
    d. 在窗口“Application firmware file:”选择工程Debug目录下的生成的TXT目标文件  
    e. 在窗口“Password file:”选择随BSL下载工具目录的BSL_Password32_Default.txt文件  
    f. 操作M0核心板按钮，使之进入BSL下载状态  
        i/ 同时按下BSL按钮和Reset按钮  
        ii/ 释放Reset按钮  
        iii/ 等待一秒之后，再释放BSL按钮  
    g. 当M0核心板进入BSL下载状态，在1秒内点击BSL下载软件的“Download”按钮  
    h. 等待一段时间，打印窗口显示下载成功  
    i. 此时，可以看到系统按照整体功能描述的模式运行  
