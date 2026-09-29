# OPA测试例程
## OPA使用原理及放大倍数修改

## 芯片管脚配置与使用
1、使用工程自带的*.syscfg文件，双击该文件启动system configuration配置M0芯片上的管脚使用  
    1.1、保留PA0控制核心板的LED  
    1.2、使用核心板缺省连接的串口（L1306核心板采用PA22/PA23，G3507核心板采用PA10/PA11）  
2、在GPIO栏目，保留PA0的设置；在UART增加一个UART1，并配置PA22/PA23或者PA10/PA11（以芯片具体型号来确定）、以及115200 8n1的串口配置，并打开接收中断。  
3、使用OPA1对信号进行放大，放大倍数缺省为2倍，并由UART输入数值进行修改（0/2/4/8/16/32倍）
4、C语言中，SYSCFG_DL_init()函数将初始化SysConfig配置的所有管脚功能，只要C代码include了ti_msp_dl_config.h头文件，我们均可以直接使用。  

## 例程B07：OPA小信号放大实验

## 例程目的
#### 1. 验证OPA数字可调信号放大实验
#### 2. 验证放大倍数修改

## 例程硬件资源
#### 1. 使用核心板上的LED灯，即PA0对应的LED灯
#### 2. 使用核心板上缺省的UART（通过CH340的USB端口与PC连接）
#### 3. 使用OPA1对输入信号进行放大、修改放大倍数等

（L1306核心板的配置）
| Pin | Destination | Function(连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| 板载PA22 | 板载UART RX | 使用PA22作为RX与板载CH340连接，无需连线 |
| 板载PA23 | 板载UART TX | 使用PA23作为TX与板载CH340连接，无需连线 |
| OPA1 IN+ | PA18 | 使用同相放大模式，并由UART修改放大倍数 |
| OPA1 OUT | PA16 | 输出为PA18输入的n倍，n缺省为2，可修改为0/2/4/8/16/32 |

（G3507核心板的配置）
| Pin | Destination | Function(连线描述) |
| --- | --- | --- |
| 板载PA0 | 板载LED灯 | 使用PA0控制板载LED灯，低有效，无需连线 |
| 板载PA11 | 板载UART RX | 使用PA11作为RX与板载CH340连接，无需连线 |
| 板载PA10 | 板载UART TX | 使用PA10作为TX与板载CH340连接，无需连线 |
| OPA1 IN+ | PB19 | 使用同相放大模式，并由UART修改放大倍数 |
| OPA1 OUT | PA16 | 输出为PB19输入的n倍，n缺省为2，可修改为0/2/4/8/16/32 |

##### 整体功能描述
按照硬件资源描述连接杜邦线，工程编译、下载、运行，可以看到  
    1、核心板LED初始状态为熄灭态，工作时，核心板LED每600毫秒闪烁一次    
    2、PC采用超级终端连接，可以看到每3s钟打印温度采样值和计算值（未标定，有偏差）      
    3、使用了开源嵌入式printf函数(https://github.com/mpaland/printf)  
    4、启用片内OPA1，对信号进行同相信号放大，放大倍数由UART输入值修改，缺省为2倍  
    5、UART可修改放大倍数为0/2/4/8/16/32倍，注意信号的偏置  

##### 同学们尝试
测试工程之后，同学们可以按照下面不同要求进行修改  
    1、修改OPA的工作模式，测试不同的配置方式    
    2、尝试增加OPA放大倍数修改方式  
    3、进一步使用OPA与其他外设的组合使用  

## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
#### 2. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 3. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）
    c. 在“Discovered projects:”窗口勾选“opa_uart”选项
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
