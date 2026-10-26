/* Temporary read-only SPD probe. Runs in reserved PS RAM while the main app
 * is halted. Restores GPIO state and I2C switch; never touches AD9361 SPI. */
typedef unsigned int u32;
typedef unsigned char u8;
#define R(a) (*(volatile u32 *)(a))
#define GPIO 0xe000a000U
#define SCL (1U<<18)
#define SDA (1U<<19)
struct result {u32 done,status,mux,address,original_mux,lines;u8 spd[256];};
volatile struct result out __attribute__((section(".result")));
static void delay(void){for(volatile unsigned i=0;i<2000;i++)__asm__ volatile("nop");}
static void dir(u32 pins,int low){u32 d=R(GPIO+0x244);R(GPIO+0x244)=low?(d|pins):(d&~pins);__asm__ volatile("dsb sy":::"memory");delay();}
static int bit(u32 pin){return !!(R(GPIO+0x64)&pin);}
static void clock_hi(void){dir(SCL,0);for(unsigned i=0;i<1000&&!bit(SCL);i++)delay();if(!bit(SCL))out.status|=0x100;}
static void start(void){dir(SDA,0);clock_hi();dir(SDA,1);dir(SCL,1);}
static void stop(void){dir(SDA,1);clock_hi();dir(SDA,0);}
static int send(u8 b){for(unsigned i=0;i<8;i++){dir(SDA,!(b&0x80));clock_hi();dir(SCL,1);b<<=1;}dir(SDA,0);clock_hi();int ack=!bit(SDA);dir(SCL,1);return ack;}
static u8 recv(int ack){u8 b=0;dir(SDA,0);for(unsigned i=0;i<8;i++){clock_hi();b=(b<<1)|bit(SDA);dir(SCL,1);}dir(SDA,ack);clock_hi();dir(SCL,1);dir(SDA,0);return b;}
static int read_one(u8 addr,u8 *v){start();if(!send((addr<<1)|1)){stop();return 0;}*v=recv(0);stop();return 1;}
static int write_one(u8 addr,u8 v){start();int ok=send(addr<<1)&&send(v);stop();return ok;}
void spd_probe(void){
 u32 d=R(GPIO+0x244),e=R(GPIO+0x248),data=R(GPIO+0x44);u8 old=0;
 out.done=0;out.status=0;out.mux=0;out.address=0;out.lines=R(GPIO+0x64);
 R(GPIO+0x244)=d&~(SCL|SDA);R(GPIO+0x0c)=0xfff30000U;R(GPIO+0x248)=e|SCL|SDA;
 for(unsigned m=0x74;m<=0x75;m++)if(read_one(m,&old)){out.mux=m;out.original_mux=old;break;}
 if(!out.mux){out.status|=1;goto cleanup;}
 if(!write_one(out.mux,8)){out.status|=2;goto restore_mux;}
 for(unsigned a=0x50;a<=0x57;a++){
  start();int ok=send(a<<1)&&send(0);stop();if(!ok)continue;
  start();if(!send((a<<1)|1)){stop();continue;}out.address=a;
  for(unsigned i=0;i<256;i++)out.spd[i]=recv(i<255);stop();break;
 }
 if(!out.address)out.status|=4;
restore_mux:
 if(!write_one(out.mux,old))out.status|=8;
cleanup:
 R(GPIO+0x244)&=~(SCL|SDA);R(GPIO+0x0c)=0xfff30000U|((data>>16)&12);R(GPIO+0x248)=e;R(GPIO+0x244)=d;
 out.done=0x53504431U;
 for(u32 a=(u32)&out;a<(u32)(&out+1);a+=32)__asm__ volatile("mcr p15, 0, %0, c7, c10, 1"::"r"(a):"memory");
 __asm__ volatile("dsb sy":::"memory");
 while(1)__asm__ volatile("nop");
}
