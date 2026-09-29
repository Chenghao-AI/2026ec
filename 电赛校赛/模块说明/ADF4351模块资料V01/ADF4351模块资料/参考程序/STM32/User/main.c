//---------------------------------------------------------------
// 		程序描述:
//		STM32__ADF4351测试程序V1.0
//		作   者：凌智电子
// 		开始日期：	2019-02-07
// 		完成日期：	2019-07-09
// 		修改日期：	2019-07-09
//		当前版本：	V1.0
//		历史版本：
//			 V1.0：基本的ADF4351控制，输出频率（35M--4.4G）
// 
// 		调试工具： 凌智STM32F103核心板V2.2、1602液晶屏、LZE_ST_LINK2
//		说明：
//				（1) :调试使用的系统时钟频率Fsysclk=72MHz;
//				（2）:
//							K1:选择要更改频率的位数
//							K2:频率加
//							K3:频率减
//---------------------------------------------------------------
#include <stm32f10x.h>
#include "CharLCD.h"
#include "key.h"
#include "Delay.h"
#include "PeripheralInit.h"
#include "adf4351.h"
#include "stdio.h"
//-----------------------------------------------------------------
//               IO 连接说明
//-----------------------------------------------------------------
//    ADF4351                  STM32
//		 CLK ---------------------PD8
//     DATA---------------------PD10
//     LE  ---------------------PD12
//     CE  ---------------------PD14
//     GND ---------------------GND
//-----------------------------------------------------------------

void Display(u32 FF);																	// 显示F函数
u8 buf[5];
s32 F=350;																						// 初始频率F=35M
static u16 a,b,c,d,e;																	// 获取频率的每一位

//	提取键值   更改频率标志位    显示与更改频率位
u8  key_numb,        k       ,       numb=0;														
//-----------------------------------------------------------------------------
//  主函数
//-----------------------------------------------------------------------------
int main(void)
{
	PeripheralInit();																										// 外设初始化
	ADF4351_Init(F);																										// 设置初始频率
	WriteString ( 1, 1 , (unsigned char *)"THE Fout IS :");  						// LCD1602显示
	WriteString ( 2, 8 , (unsigned char *)"4400.0MHz");
	Display(F);																													// 显示F函数

	while(1)
	{
		key_numb=Key_Scan();																							// 读取键值
		if(key_numb==1)																										// 当按键key1按下时
		{
				numb++;
				switch(numb)
				{
						case 1 : {
												WrCLcdC(0x80+0x40+12);												// 指定位置
												WrCLcdC(0x0f);																// 开光标闪烁
											}break;
						case 2 : {
												WrCLcdC(0x80+0x40+10);								
											}break;
						case 3 : {
												WrCLcdC(0x80+0x40+9);								
											}break;
						case 4 : {
												WrCLcdC(0x80+0x40+8);								
											}break;
						case 5 : {
												WrCLcdC(0x80+0x40+7);								
											}break;
						case 6 : {
												numb=0;
												WrCLcdC(0x0c);																// 关闭光标闪烁						
											}break;
						default :	break;
					}							
		}
		if(key_numb==4)
		{
			numb=0;
			WrCLcdC(0x0c);																									// 关闭光标闪烁
		}
		if(numb!=0)
		{
			if(key_numb==2)																									// 当KEY2被按下
			{
				k=1;
				if(numb==1)																		
				{
					F++;																												// 频率加0.1M
					if(F>44000)
					{
						F=350;
					}
					Display(F);					
					WrCLcdC(0x80+0x40+12);
				}
				else if(numb==2)
				{
					F+=10;																											// 频率加1M
					if(F>44000)
					{
						F=350;
					}
					Display(F);
					WrCLcdC(0x80+0x40+10);
				}
				else if(numb==3)
				{
					F+=100;																											// 频率加10M
					if(F>44000)
					{
						F=350;
					}
					Display(F);
					WrCLcdC(0x80+0x40+9);
				}
				else if(numb==4)
				{
					F+=1000;																										// 频率加100M
					if(F>44000)
					{
						F=350;
					}
					Display(F);
					WrCLcdC(0x80+0x40+8);
				}
				else if(numb==5)
				{
					F+=10000;																										// 频率加1000M
					if(F>44000)
					{
						F=350;
					}
					Display(F);
					WrCLcdC(0x80+0x40+7);
				}
			}
			if(key_numb==3)																									// 当KEY3被按下
			{
				k=1;
				if(numb==1)
				{
					F--;																												// 频率减0.1M
					if(F<350)
					{
						F=44000;
					}
					Display(F);
					WrCLcdC(0x80+0x40+12);
				}
				else if(numb==2)
				{
					F-=10;																											// 频率减1M
					if(F<350)
					{
						F=44000;
					}
					Display(F);
					WrCLcdC(0x80+0x40+10);
				}
				else if(numb==3)
				{
					F-=100;																											// 频率减10M
					if(F<350)
					{
						F=44000;
					}
					Display(F);
					WrCLcdC(0x80+0x40+9);
				}
				else if(numb==4)
				{
					F-=1000;																										// 频率减100M
					if(F<350)
					{
						F=44000;
					}
					Display(F);
					WrCLcdC(0x80+0x40+8);
				}
				else if(numb==5)
				{
					F-=10000;																										// 频率减1000M
					if(F<350)
					{
						F=44000;
					}
					Display(F);
					WrCLcdC(0x80+0x40+7);
				}
			}
		}
			if(k==1)																												// 当更改频率时，写入数据
			{
			k=0;
			if (F>=690&&F<=1370)	 ADF4351_Wdata(0x0050443c);  // if,else if中得语句是判断此时频率得范围		  
	 		else if (F>1370&&F<=2740) ADF4351_Wdata(0x0040443c); // 根据频率的范围确定我们要更新此时寄存器4（RF diver）的值
			else if (F>2740&&F<=5490) ADF4351_Wdata(0x0030143c);
			else if (F>5490&&F<=10990) ADF4351_Wdata(0x0020143c); 
			else if (F>10990&&F<=21990) ADF4351_Wdata(0x0010143c); 
     	else if (F>21990)  ADF4351_Wdata(0x0000143c); 
			else ADF4351_Wdata(0x0060443c);	
														        	
			ADF4351_Wdata(0x00000000|F<<15); 	   // 把要输出频率的字写入寄存器0，改变输出频率
			}
	}
}

//-----------------------------------------------------------------
//函数名称:void Display(u32 FF)
//函数功能:显示频率函数
//入口参数:无
//出口参数:无
//-----------------------------------------------------------------

void Display(u32 FF) 															
{

	a=FF/10000;
	b=FF/1000%10;
	c=FF/100%10;
	d=FF/10%10;
	e=FF%10;
	WrCLcdC (0x80+0x40+7);
	WrCLcdD (0x30+a);
	WrCLcdD (0x30+b);
	WrCLcdD (0x30+c);
	WrCLcdD (0x30+d);
	WrCLcdC (0x80+0x40+12);
	WrCLcdD (0x30+e);
}
//-----------------------------------------------------------------------------
// End Of File
//-----------------------------------------------------------------------------










