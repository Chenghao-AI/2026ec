# GPIO之Output功能
## GPIO-Output讲解
1、因为芯片制造工艺的提升，一颗芯片内部可以实现成千上万的功能，但因为管脚受限，通常各芯片的管脚均是多种功能复用。  
2、GPIO（通用输入输出）功能是各复用功能中最简单的功能组件，即程序直接控制管脚输出为高/低电平（输出），或者感知外部的高/低电平（输入）。  
3、作为通用输出功能，每个管脚有相应的属性需要设置：初始状态、输出结构等  
## 芯片管脚配置与使用
1、使用工程自带的*.syscfg文件，双击该文件启动system configuration配置M0芯片上的管脚使用  
2、在GPIO栏目，增加对应的管脚，做好命名、PinMux配置等  
3、C语言中，SYSCFG_DL_init()函数将初始化SysConfig配置的所有管脚功能，只要C代码include了ti_msp_dl_config.h头文件，我们均可以直接使用。  

## 例程A02：GPIO之Output实验

## 例程目的
#### 1. GPIO通用输入输出之通用输出测试验证
#### 2. 修改SysCfg文件以修改各输入输出管脚及属性

## 例程硬件资源
#### 1. 使用核心板上的LED灯，即PA0对应的LED灯
#### 2. 核心板插入底板之后，使用杜邦线将下面对应管脚相连

| Pin | Destination | Function(连线描述)(L1306与G3507采用相同的管脚编号) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| J6 PA10 | J10 LED灯 | 使用PA10控制底板LED灯，高有效，需要杜邦线连接 |
| J6 PA11 | J10 LED-RGB灯-R管脚 | 使用PA11控制底板LED-RGB的R，低有效，需要杜邦线连接 |
| J6 PA12 | J10 LED-RGB灯-G管脚 | 使用PA12控制底板LED-RGB的G，低有效，需要杜邦线连接 |
| J6 PA13 | J10 LED-RGB灯-B管脚 | 使用PA13控制底板LED-RGB的B，低有效，需要杜邦线连接 |

##### 整体功能描述
PA13.PA12.PA11控制LED-RGB，PA10控制板载LED，PA0控制核心板的LED；以上五个GPIO组成一个统一的组合控制输出。   
程序中将5个GPIO组成一个LedOutput函数，输入参数为0~31，对应5个LED的不同状态。  


## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
#### 2. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 3. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）
    c. 在“Discovered projects:”窗口勾选“gpio_output”选项
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
    i. 此时，可以看到M0核心板以及底板的LED和LED-RGB处于不同颜色的切换显示中。  
