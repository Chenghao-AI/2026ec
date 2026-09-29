# 光敏采样例程
## 设计原理
1. 采用时间片轮询的系统框架代码  
2. 使用DAC控制偏置电压，与OPA1构成偏置减除电路  
3. 使用OPA0作为可调挡位放大电路  
4. ADC值直接显示在OLED屏，并在UART打印  
5. UART实现了printf函数，并实现UART回环测试功能  

## 芯片管脚配置与使用
1、使用工程自带的*.syscfg文件，双击该文件启动system configuration配置M0芯片上的管脚使用  
    1.1、保留PA0控制核心板的LED  
    1.2、使用核心板缺省连接的串口（G3507核心板采用PA10/PA11）  
2、详细管脚连接参见工程目录的Readme.md    
3、C语言中，SYSCFG_DL_init()函数将初始化SysConfig配置的所有管脚功能，只要C代码include了ti_msp_dl_config.h头文件，我们均可以直接使用。  

## 例程C05：光敏检测实验

## 例程目的
#### 1. 验证使用时间片轮询多任务系统的程序框架程序
#### 2. 验证并使用M0+的内部DAC、OPA、ADC等模拟器件

## 例程硬件资源
详见工程目录的Readme文档  

##### 整体功能描述
    按照硬件资源描述连接杜邦线，工程编译、下载、运行，可以看到  
    1、PC采用超级终端连接，采用115200 8n1配置模式，接收系统任务输出      
    2、系统内有六个应用任务，周期性被执行  
        a、任务一：每10秒钟打印任务，即每10秒钟向UART打印一条语句，提示任务一在执行；  
        b、任务二：每30秒钟打印任务，即每30秒钟向UART打印一条语句，提示任务二在执行；  
        c、任务三：按键检测任务，每20ms执行一次，四个按键调整两个全局变量的目标，从而调整偏置值、挡位值；  
        d、任务四：UART输入检测任务，每100ms执行一次，当有完整的一句语句在UART输入（回车结束），则UART回显该语句；  
        e、任务五：LED轮询显示任务，每500ms执行一次；  
        f、任务六：ADC读值任务，每2秒执行数值读取，该值为2秒之前的测量值，读完启动下一次ADC采样；  
    3、使用了开源嵌入式printf函数(https://github.com/mpaland/printf)  
    4、【注意】为了串口正确显示中文，请使用GBK/GB18030打开对应c文件  

##### 同学们尝试
    测试工程之后，同学们可以按照下面不同要求进行修改  
    1、自行增加修改应用任务，从而在该框架下完成可能的嵌入式任务修改    
    2、如在UART接收数据中，实现各种命令处理    
    3、调整OPA以及ADC/DAC的各种设置，从而形成不同的功能  
    4、其他系统中各种外设任务的集成  

## 例程软件工具
#### 1. 将使用BSL下载工具，[网盘地址](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
#### 2. CCS12.5及以上版本 [下载链接](https://www.ti.com.cn/tool/cn/CCSTUDIO)
#### 3. 安装MSPM0 SDK 1.20以上版本 [下载链接](https://www.ti.com/tool/MSPM0-SDK)

## 测试方法
#### 1. CCS导入工程
    a. CCS软件菜单->Project->Import CCS Projects...
    b. 点击“Browse...”按钮，选择下载的本目录位置（注意：建议路径不含中文字符）
    c. 在“Discovered projects:”窗口勾选“time_slice”选项
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
