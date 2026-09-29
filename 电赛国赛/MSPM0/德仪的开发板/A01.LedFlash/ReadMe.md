## 例程A01：核心板闪灯

## 例程目的
#### 1. 使用该例程验证CCS导入工程、编译、并生成txt目标文件
#### 2. 使用BSL下载工具下载生成的txt文件到核心板
#### 3. 可以用XDS110直接下载仿真调测
	XDS110的TMS连接目标核心板的SWD、XDS110的TCK连接目标核心板的SWK  
#### 4. 可以用Keil+DAPLink编译仿真调测
	Keil需要5.20以上版本，并安装支持MSPM0L1306或者MSPM0G3507的芯片Pack包。  
	本目录Keil工程依赖项：  
		a. TI SDK msp0_sdk_1_20_01_06版本，并需要确保该SDK安装在C:\ti\目录下；  
		b. TI sysconfig_1.18.0，并确保安装在C:\ti\目录下；  
	上述依赖项，若安装目录不同，则需要自行修改工程里面的头文件搜索路径和本开源工程根目录\tools\keil\syscfg.bat里面的搜索路径。  

## 例程视频链接
##### [B站链接](https://www.bilibili.com/video/BV1RH4y1J7JE/?vd_source=699f64b6495e0564a76d4b0fce0764ac)

## 例程硬件资源
#### 1. （L1306）仅使用核心板上的LED灯，即PA0对应的LED灯（因此即可核心板独立工作，也可以将核心板插入到底板上工作）
#### 2. （G3507）使用核心板上的LED1（独立LED）和RGB-LED，将四个LED分别作为CNT计数值的低4bit来控制显示与否。

## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
#### 2. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 3. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...  
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）  
    c. 在“Discovered projects:”窗口勾选“led_flash”选项  
    d. 点击“Finish”按钮  
#### 2. 编译工程，并生成TXT目标文件
    a. CCS菜单->Project->Build Project  
#### 3. BSL下载TXT目标文件
    a. 使用USB Type-C线将M0核心板连接电脑USB口  
    b. 确保电脑已经安装CH340驱动（可以通过Windows设备属性查看此时能看到CH340的串口号）驱动链接：https://www.wch.cn/downloads/CH341SER_EXE.html  
    c. 运行BSL下载工具软件“MSPM0_BSL_GUI.exe”  
    d. 在窗口“Application firmware file:”选择工程Debug目录下的生成的TXT目标文件  
    e. 在窗口“Password file:”选择随BSL下载工具目录的BSL_Password32_Default.txt文件  
    f. 操作M0核心板按钮，使之进入BSL下载状态  
        i/ 先按BSL按钮，并持续按住  
        ii/ 再按Reset按钮  
        iii/ 释放Reset按钮  
        iv/ 等待一秒之后，释放BSL按钮  
    g. 当M0核心板进入BSL下载状态，在1秒内点击BSL下载软件的“Download”按钮  
    h. 等待一段时间，打印窗口显示下载成功  
    i. 此时，可以看到M0核心板的绿色LED在按照1Hz频率进行闪烁/变化  
