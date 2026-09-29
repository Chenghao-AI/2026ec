# 基本定时器功能
## 定时器工作原理及基本使用方法

## 芯片管脚配置与使用
1、使用工程自带的*.syscfg文件，双击该文件启动system configuration配置M0芯片上的管脚使用  
    1.1、自行修改syscfg，注意各输入GPIO的IOMUX属性配置的上拉电阻
    1.2、自行修改syscfg，注意各输入GPIO的中断使能
2、在GPIO栏目，增加对应的管脚，做好命名、PinMux配置等  
3、C语言中，SYSCFG_DL_init()函数将初始化SysConfig配置的所有管脚功能，只要C代码include了ti_msp_dl_config.h头文件，我们均可以直接使用。  

## 例程A06：基本定时器实验

## 例程目的
#### 1. 验证基本定时器的最简工作原理
#### 2. 验证基本定时器的配置、定时等基本操作方法

## 例程硬件资源
#### 1. 使用核心板上的LED灯，即PA0对应的LED灯
#### 2. 核心板插入底板之后，使用杜邦线将下面对应管脚相连

| Pin | Destination | Function(连线描述 L1306核心板) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| J6 PA14 | J14 KEY1 | PA14通过杜邦线连接按键KEY1 |
| J7 PA2 | J2 DP | 使用杜邦线连接MCU的PA2到扫描数码管的DP输入 |
| J7 PA3 | J2 DP | 使用杜邦线连接MCU的PA3到扫描数码管的G输入 |
| J7 PA4 | J2 DP | 使用杜邦线连接MCU的PA4到扫描数码管的F输入 |
| J7 PA5 | J2 DP | 使用杜邦线连接MCU的PA5到扫描数码管的E输入 |
| J7 PA6 | J2 DP | 使用杜邦线连接MCU的PA6到扫描数码管的D输入 |
| J7 PA7 | J2 DP | 使用杜邦线连接MCU的PA7到扫描数码管的C输入 |
| J7 PA8 | J2 DP | 使用杜邦线连接MCU的PA8到扫描数码管的B输入 |
| J7 PA9 | J2 DP | 使用杜邦线连接MCU的PA9到扫描数码管的A输入 |
| J6 PA10 | J5 位1 | 使用杜邦线连接MCU的PA10到扫描数码管的位1 |
| J6 PA11 | J5 位2 | 使用杜邦线连接MCU的PA11到扫描数码管的位2 |
| J6 PA12 | J5 位3 | 使用杜邦线连接MCU的PA12到扫描数码管的位3 |
| J6 PA13 | J5 位4 | 使用杜邦线连接MCU的PA13到扫描数码管的位4 |
| 定时器TIMG0 | 启用内部定时器 | 用定时器控制扫描数码管的扫描流程，每5ms中断一次 |

| Pin | Destination | Function(连线描述 G3507核心板) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| J6 PA8 | J14 KEY1 | PA14通过杜邦线连接按键KEY1 |
| J7 PA22 | J2 DP | 使用杜邦线连接MCU的PA2到扫描数码管的DP输入 |
| J7 PA21 | J2 DP | 使用杜邦线连接MCU的PA3到扫描数码管的G输入 |
| J7 PA18 | J2 DP | 使用杜邦线连接MCU的PA4到扫描数码管的F输入 |
| J7 PA17 | J2 DP | 使用杜邦线连接MCU的PA5到扫描数码管的E输入 |
| J7 PA16 | J2 DP | 使用杜邦线连接MCU的PA6到扫描数码管的D输入 |
| J7 PA15 | J2 DP | 使用杜邦线连接MCU的PA7到扫描数码管的C输入 |
| J7 PA14 | J2 DP | 使用杜邦线连接MCU的PA8到扫描数码管的B输入 |
| J7 PA13 | J2 DP | 使用杜邦线连接MCU的PA9到扫描数码管的A输入 |
| J6 PB6 | J5 位1 | 使用杜邦线连接MCU的PA10到扫描数码管的位1 |
| J6 PB7 | J5 位2 | 使用杜邦线连接MCU的PA11到扫描数码管的位2 |
| J6 PB8 | J5 位3 | 使用杜邦线连接MCU的PA12到扫描数码管的位3 |
| J6 PB9 | J5 位4 | 使用杜邦线连接MCU的PA13到扫描数码管的位4 |
| 定时器TIMG0 | 启用内部定时器 | 用定时器控制扫描数码管的扫描流程，每5ms中断一次 |

##### 整体功能描述
按照硬件资源描述连接杜邦线，工程编译、下载、运行，可以看到  
    1、核心板LED初始状态为熄灭态，扫描数码管为熄灭态  
    2、循环开始，即通过底层扫描流程，使得四位扫描数码管稳定显示“1234”缺省数值  
    3、当按键每按一次，四位扫描数码管内容增加1，该值为16进制组织方式  

##### 同学们尝试
测试工程之后，同学们可以按照下面不同要求进行修改  
    1、修改定时器配置：修改sysconfig修改定时器及其工作模式、定时时间、中断方式等，测试定时器修改对显示效果的影响  
    2、修改各连接管脚，根据对应连接方式，重新修改sysconfig的配置，使之工作正常  
    3、修改使用按键的中断方式，修改代码使之工作正常  
    4、增加不同的LED、独立数码管等其他外设，组合出更多不同的显示内容，如动态刷新显示学号等  

## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
#### 2. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 3. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）
    c. 在“Discovered projects:”窗口勾选“multi_tube”选项
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
