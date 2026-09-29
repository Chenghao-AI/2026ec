## 摘要

**这是一个基于Keil开发MSPM0G3507的项目模板**

* 注意运行SysConfig需要打开相应的syscfg文件，再去菜单中点击添加的SysConfig插件功能，就能够自动调用系统里安装的SysConfig软件进行可视化配置，配置介绍后关闭SysConfig软件并保存。

* 注意driverlib.a文件是否路径正确

* 注意C/C++(AC6)中的Include Pathes是否正确适配你的开发环境

* 注意如果需要断点调试代码，C/C++(AC6)中的Optimization必须选择在-O0，即最低优化程度，否则很可能有些语句被优化而无法按照设想的成功设置断点暂停！

* 注意User中的Before Build和After Build两个脚本指令的地址适配你的开发环境

* 注意Target中不能勾选“Use MicroLIB”

* 注意Debug中要选择“CMSIS-DAP”，并且在Debugger的Setting中，Flash and Download中禁止勾选“Reset and Run”！经测试该Reset会使得系统时钟树自动降频一半，原因暂时不明

## 模板工程的功能

该项目的管脚配置及功能如下

* 开启了SWD调试口，可以硬件调试

* 利用外部20MHz的晶振做系统时钟来源，系统时钟设置为20MHz

* 利用外部32.768kHz的RTC晶振作为RTC时钟来源

* 时钟信号输出使能，在PA31上输出了系统时钟

* 控制PB20、PB21和PB22，使得板载RGB灯按照大约1s的间隔，按照“灭-红-绿-黄-蓝-洋红-青-白”的顺序循环切换