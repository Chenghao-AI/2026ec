文件说明：

1、STM32F103VE_LT7580_bootloader_nor_8080

这个例程是基于STM32F103VE主控板的SD卡把图片素材烧录到LT7580的外挂SPI Nor FLASH的例程。

SPI FLASH烧录操作步骤：

（1）在SD根目录下新建SPI_FLASH文件夹。
（2）把图片素材文件夹里面的SPI_FLASH_CS1拷贝到SPI_FLASH文件夹里面。
（3）主控板上电，等待SPI FLASH升级完成。
（4）拔出SD卡。

2、STM32F103VE_LT7580_demo_1024x600_nor_8080

这个是基于STM32F103VE的DEMO演示例程。

3、图片素材

这个是DEMO例程所需要用到的素材文件。
