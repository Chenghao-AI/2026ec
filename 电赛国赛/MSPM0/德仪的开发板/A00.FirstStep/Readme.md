# 开篇环境建设

## CCS开发方法

1、本例程库首选采用CCS软件开发，所有例程使用CCS12.50版本  
2、需要额外安装MSP M0+的SDK，所有例程依赖MSPM0 SDK1.20.01.06  
3、上述软件安装完成后，例程导入后即可编译，无需依赖其他软件（CCS内置SysConfig软件）  
4、采用其他更新版本的CCS软件版本、SDK版本，经不完全测试，没有发现问题  
5、编译生成的TXT文件，可以通过BSL工具直接下载，BSL下载软件点击[这里](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  

#### 基于CCS的仿真方法

1、目前基于CCS软件，仅测试过采用XDS-110仿真器进行仿真、下载、运行  
2、无论是独立XDS-110，还是基于LauchPad的板载XDS-110，与M0核心板的连接方式如下所示  

| 核心板管脚 | XDS-110管脚 | 其他说明 |
| --- | --- | --- |
| SWK管脚 | TCK管脚 | - |
| SWD管脚 | TMS管脚 | - |
| GND地线 | GND地线 | - |

## Keil uVision开发方法

1、本例程库大多数例程配备Keil工程，在Keil uVision 5.35版本经过测试  
2、Keil uVision需要安装芯片支持包，如L1306或者G3507的芯片支持包，下载可点击[这里](https://pan.baidu.com/s/1mPzG4ZCiwa21g7wX61cbCw?pwd=vfq2)  
3、基于Keil开发，需要依赖除了上述的SDK1.20.01.06之外，需要独立SysConfig软件，本例程库依赖SysConfig1.18.0，且直接生成TXT目标文件  
4、如果更换了SDK版本、或者SysConfig版本，则请参考[Keil工程设置](https://gitee.com/NEagle/msp-lab-m0/tree/master/tools/keil)，对相关位置进行修改  
5、Keil软件可以支持DAPLink，或者XDS-110进行仿真、下载、运行  

## 硬件资料

1、原理图及丝印，请参考[这里](https://gitee.com/NEagle/msp-lab-m0/tree/master/doc)  
2、核心板模组库，请参考[这里](https://gitee.com/NEagle/msp-lab-m0/tree/master/Hardware)

## 其他资源

#### 1、B站视频更新如下：

[A01.开发环境视频](https://www.bilibili.com/video/BV1RH4y1J7JE/?vd_source=699f64b6495e0564a76d4b0fce0764ac)  
[C05.光强检测综合例程视频](https://www.bilibili.com/video/BV1fr42147Ly/?spm_id_from=333.788)  

#### 2、开发板采购

[淘宝链接](https://item.taobao.com/item.htm?abbucket=10&id=790044563339)  
