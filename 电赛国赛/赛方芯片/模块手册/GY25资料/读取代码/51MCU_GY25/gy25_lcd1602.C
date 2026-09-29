//  GY25-51-1602
//  使用单片机：STC89C52 
//  显示：lcd1602
//  晶振：  11.0592 M(一定是11.0592m的)
//  注意：请参考说明书焊上GY25焊点，或者串口修改GY25波特率9600掉电保存
//  接线
//  GY25    51MCU
//   VCC-------5V
//   GND-------GND
//   TX--------RX(P3.0  PIN10)
//   RX--------TX(P3.1  PIN11)
//   LCD1602引脚请根据下面定义修改
//  功能：GY25跟89c52 串口通信，lcd1602显示
#include<REG52.H>	
#include<math.h>       //Keil library  
#include<stdio.h>      //Keil library	
#include<INTRINS.H>
#define uchar unsigned char
#define uint  unsigned int	

//   LCD1602引脚请根据下面定义修改
#define DataPort P2	   //LCD1602 数据端口	
sbit    LCM_RS=P0^7;   //LCD1602 控制端口		
sbit    LCM_RW=P0^6;   //LCD1602 控制端口	
sbit    LCM_EN=P0^5;   //LCD1602 控制端口
	
//********定义函数*****************************
void    delay(unsigned int k);
void    InitLcd();
void    WriteDataLCM(uchar dataW);
void    WriteCommandLCM(uchar CMD,uchar Attribc);
void    DisplayOneChar(uchar X,uchar Y,uchar DData);
void    SeriPushSend(uchar send_data);
//********定义变量*****************************
uchar   BUF[10];          //数据缓存区
uchar   cnt=0;           //接收数据的累计值
uchar   sign=0;
int YPR[3];
//********定义函数*****************************
void    delay(unsigned int k);
void    SeriPushSend(uchar send_data);
void 	  display(void);
//*********************************************
//串口中断
void serial_serve(void) interrupt 4	
{
    if(RI==1){         //中断标志
    RI=0;
	BUF[cnt]=SBUF;	
	if(cnt==0&&BUF[0]!=0xAA) return;      // 检查帧头     
	cnt++;        //接收计数
    if(cnt==8)                //
    {    
       cnt=0;                 //
       sign=1;
    } 
  }
	
}
//*********************************************
//串口初始化
//9600 bps @ 11.059 MHz 
void init_uart()
{
	TMOD=0x21;				
	TH1=0xfd;				
	TL1=0xfd;				
	SCON=0x50;
	PS=1;      //串口中断设为高优先级别
	TR0=1;	   //启动定时器			
	TR1=1;
	ET0=1;     //打开定时器0中断			
	ES=1;	
}

//**********延时函数***************
void delay(unsigned int k)	
{						
	unsigned int i,j;				
	for(i=0;i<k;i++)
	{			
	for(j=0;j<121;j++)			
	{;}
	}						
}						            
//*********串口数据发送******************
void  SeriPushSend(uchar send_data)
{
    SBUF=send_data;  
	while(!TI);TI=0;	  
}

//*********LCD1602初始化**********************
void InitLcd()				
{			
	WriteCommandLCM(0x38,1);	
	WriteCommandLCM(0x08,1);	
	WriteCommandLCM(0x01,1);
	WriteCommandLCM(0x06,1);	
	WriteCommandLCM(0x0c,1);
}
//**********检测忙信号************************
void WaitForEnable(void)	
{					
	DataPort=0xff;		
	LCM_RS=0;LCM_RW=1;_nop_();
	LCM_EN=1;_nop_();_nop_();
	while(DataPort&0x80);	
	LCM_EN=0;				
}					
//**********写命令至LCD***********************
void WriteCommandLCM(uchar CMD,uchar Attribc)
{					
	if(Attribc)WaitForEnable();	
	LCM_RS=0;LCM_RW=0;_nop_();
	DataPort=CMD;_nop_();	
	LCM_EN=1;_nop_();_nop_();LCM_EN=0;
}					
//**********写数据至LCD************************
void WriteDataLCM(uchar dataW)
{					
	WaitForEnable();		
	LCM_RS=1;LCM_RW=0;_nop_();
	DataPort=dataW;_nop_();	
	LCM_EN=1;_nop_();_nop_();LCM_EN=0;
}					
//*********写一个字符数据到指定的目标***********
void DisplayOneChar(uchar X,uchar Y,uchar DData)
{						
	Y&=1;						
	X&=15;						
	if(Y)X|=0x40;					
	X|=0x80;			
	WriteCommandLCM(X,0);		
	WriteDataLCM(DData);		
}
						            
//******************************************************
//*************************************
void dis_play(uchar A,uchar B,int num)	
{
	if(num<0)
	{
		num=-num;
		DisplayOneChar(A,B,('-'));
	}
	else
	    DisplayOneChar(A,B,('+'));

    DisplayOneChar(++A,B,(0x30|(num/10000)));	
	DisplayOneChar(++A,B,(0x30|(num%10000/1000)));
	DisplayOneChar(++A,B,(0x30|(num%1000/100)));
	DisplayOneChar(++A,B,(0x2e));
	DisplayOneChar(++A,B,(0x30|(num%100/10)));
//	DisplayOneChar(++A,B,(0x30|(num%10)));   //小数点后2位
}

//*******************数据接收并显示**********************
void display(void)
{
  int YPR[3];
  if(sign){ 
       sign=0;	 	
	    if(BUF[0]==0XAA&&BUF[7]==0X55){                         //帧头判断   
				 
          YPR[0]=(BUF[5]<<8|BUF[6]);  
          YPR[1]=(BUF[3]<<8|BUF[4]);
          YPR[2]=(BUF[1]<<8|BUF[2]);
			
		     dis_play(2,1,YPR[0]);
		     dis_play(10,1,YPR[1]);		
		     dis_play(2,0,YPR[2]);          			 
        }
   }  
}
//*******************数据接收并显示**********************
 
//***************************************
//主程序
void main()
{ 
   EA=0;  
   delay(200);	                                              //延时		
   InitLcd();                                                 //初始化LCD
   init_uart();                                               //初始化串口
   EA=1;                                                      //开总中断
   cnt=0;   
   DisplayOneChar(0,0,('Y'));
   DisplayOneChar(1,0,(':'));
   DisplayOneChar(0,1,('P'));
   DisplayOneChar(1,1,(':'));
   DisplayOneChar(8,1,('R'));
   DisplayOneChar(9,1,(':'));

   SeriPushSend(0XA5); 
   SeriPushSend(0X52); //发送欧拉角（默认50HZ）1帧读取命令。                                
  
  while(1){                                                   //循环  
                                      
   display();                                   
   }                                                          //end while
} 




