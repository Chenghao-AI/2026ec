# GPIO之组合输出功能
## 数码管显示原理

## 芯片管脚配置与使用
1、使用工程自带的*.syscfg文件，双击该文件启动system configuration配置M0芯片上的管脚使用  
2、在GPIO栏目，增加对应的管脚，做好命名、PinMux配置等  
3、C语言中，SYSCFG_DL_init()函数将初始化SysConfig配置的所有管脚功能，只要C代码include了ti_msp_dl_config.h头文件，我们均可以直接使用。  

## 例程A03：GPIO之组合输出实验

## 例程目的
#### 1. 验证组合输出控制数码管显示的原理
#### 2. 初步理解不同字库定义对不同类型数码管以及MCU与数码管的连接关系的对应

## 例程硬件资源
#### 1. 使用核心板上的LED灯，即PA0对应的LED灯
#### 2. 核心板插入底板之后，使用杜邦线将下面对应管脚相连

| Pin | Destination | Function(L1306系统连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| J7 PA2 | J3 共阴独立数码管输入A | PA2通过杜邦线控制数码管字段A |
| J7 PA3 | J3 共阴独立数码管输入B | PA3通过杜邦线控制数码管字段B |
| J7 PA4 | J3 共阴独立数码管输入C | PA4通过杜邦线控制数码管字段C |
| J7 PA5 | J3 共阴独立数码管输入D | PA5通过杜邦线控制数码管字段D |
| J7 PA6 | J3 共阴独立数码管输入E | PA6通过杜邦线控制数码管字段E |
| J7 PA7 | J3 共阴独立数码管输入F | PA7通过杜邦线控制数码管字段F |
| J7 PA8 | J3 共阴独立数码管输入G | PA8通过杜邦线控制数码管字段G |
| J7 PA9 | J3 共阴独立数码管输入DP | PA9通过杜邦线控制数码管字段DP |


| Pin | Destination | Function(G3507系统连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| J7 PA13 | J3 共阴独立数码管输入A | PA2通过杜邦线控制数码管字段A |
| J7 PA14 | J3 共阴独立数码管输入B | PA3通过杜邦线控制数码管字段B |
| J7 PA15 | J3 共阴独立数码管输入C | PA4通过杜邦线控制数码管字段C |
| J7 PA16 | J3 共阴独立数码管输入D | PA5通过杜邦线控制数码管字段D |
| J7 PA17 | J3 共阴独立数码管输入E | PA6通过杜邦线控制数码管字段E |
| J7 PA18 | J3 共阴独立数码管输入F | PA7通过杜邦线控制数码管字段F |
| J7 PA21 | J3 共阴独立数码管输入G | PA8通过杜邦线控制数码管字段G |
| J7 PA22 | J3 共阴独立数码管输入DP | PA9通过杜邦线控制数码管字段DP |

##### 整体功能描述
按照硬件资源描述连接杜邦线，工程编译、下载、运行，可以看到  
    1、核心板LED每秒变动一次（0.5Hz）  
    2、共阴独立数码管每秒钟变动一次，从0 ~ F，再 0. ~ F.，共32种不同显示模式  

##### 同学们尝试
测试工程之后，同学们可以按照下面不同要求进行修改  
    1、修改管脚：修改sysconfig修改不同的管脚连接，并调整杜邦线连接，实现同样的功能  
    2、修改显示内容：调整字库数组DispLib，以循环显示不同的文字，如‘1’显示不同，或者完全不同的字模，思考如何构建新的字模  

## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
#### 2. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 3. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）
    c. 在“Discovered projects:”窗口勾选“gpio_combine”选项
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
