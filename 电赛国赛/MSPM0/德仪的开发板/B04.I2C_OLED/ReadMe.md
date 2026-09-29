# 硬件I2C外设驱动OLED例程
## 硬件I2C外设及OLED原理

## 芯片管脚配置与使用
1、使用工程自带的*.syscfg文件，双击该文件启动system configuration配置M0芯片上的管脚使用  
    1.1、保留PA0控制核心板的LED  
    1.2、使用核心板缺省连接的串口（PA22/PA23）  
    1.3、使用PA10/PA11连接OLED的SDA/SCL管脚
2、syscfg配置
    2.1、在GPIO栏目，保留PA0的设置；
    2.2、在UART增加一个UART1，并配置PA22/PA23、以及115200 8n1的串口配置
    2.3、在I2C增加一个I2C配置，使用管脚PA10/PA11（I2C0），并配置中断使能  
3、C语言中，SYSCFG_DL_init()函数将初始化SysConfig配置的所有管脚功能，只要C代码include了ti_msp_dl_config.h头文件，我们均可以直接使用。  

## 例程B04：I2C-OLED实验
在OLED上循环显示不同的内容：英文字符、中文字符、不同大小字体、走屏显示等  
在UART打印各阶段指示信息  

## 例程目的
#### 1. 验证I2C配置方式（含中断配置模式）
#### 2. 验证采用I2C外设驱动OLED的方法

## 例程硬件资源
#### 1. 使用核心板上的LED灯，即PA0对应的LED灯
#### 2. 使用核心板上缺省的UART（通过CH340的USB端口与PC连接）
#### 3. 使用杜邦线将PA10/PA11连接OLED的SDA/SCL管脚

| Pin | Destination | Function(L1306连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| 板载PA22 | 板载UART RX | 使用PA22作为RX与板载CH340连接，无需连线 |
| 板载PA23 | 板载UART TX | 使用PA23作为TX与板载CH340连接，无需连线 |
| UART1 | 启用芯片UART1 | 使用 115200 8n1 UART工作模式 |
| 板载PA10 | 底板OLED SDA | 采用杜邦线连接PA10与OLED的SDA线（J1接插件） |
| 板载PA11 | 底板OLED SCL | 采用杜邦线连接PA10与OLED的SCL线（J1接插件） |
| I2C0 | 启用芯片I2C0 | 使用 100KHz、FIFO BURST 工作模式 |

| Pin | Destination | Function(G3507连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| 板载PA11 | 板载UART RX | 使用PA11作为RX与板载CH340连接，无需连线 |
| 板载PA10 | 板载UART TX | 使用PA10作为TX与板载CH340连接，无需连线 |
| UART1 | 启用芯片UART1 | 使用 115200 8n1 UART工作模式 |
| 板载PA28 | 底板OLED SDA | 采用杜邦线连接PA28与OLED的SDA线（J1接插件） |
| 板载PA31 | 底板OLED SCL | 采用杜邦线连接PA31与OLED的SCL线（J1接插件） |
| I2C0 | 启用芯片I2C0 | 使用 100KHz、FIFO BURST 工作模式 |

##### 整体功能描述
按照硬件资源描述连接杜邦线，工程编译、下载、运行，可以看到  
    1、核心板LED初始状态为熄灭态，工作时，完成一个循环，LED变化一次    
    2、PC采用超级终端连接，可以看到每完成一阶段工作，打印一行字符    
    3、使用了开源嵌入式printf函数(https://github.com/mpaland/printf)  
    4、在OLED上循环显示背景图片、英文字符、中文字符、循环走屏等  

##### 同学们尝试
测试工程之后，同学们可以按照下面不同要求进行修改  
    1、修改I2C的工作模式、管脚，测试不同的配置方式    
    2、修改OLED不同的OLED显示内容、字体、刷新方式等  
    3、尝试OLED的显示模式，不使用等待方式来提高显示效率等修改  

## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)
#### 2. OLED字模生成工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)
#### 3. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 4. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）
    c. 在“Discovered projects:”窗口勾选“pwm_out”选项
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
    j. 注意：因生成代码尺寸较大，下载时需要较多的等待时间  
