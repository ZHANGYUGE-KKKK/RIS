/* Temporary DDR diagnostic for the verified original application ELF.
 * Capture stays disarmed. SPI settings changed by the four PN trials are
 * restored and read back, including on a failed trial. No RF reset/reinit.
 */
#include "drivers/ad9361.h"
#include "drivers/rx_9361.h"
#include "xtime_l.h"
#define RADIO ((ad9361_device *)0x00148030U)
#define RX ((rx_9361_device *)0x00148868U)
#define READ ((typeof(&ad9361_reg_read))0x00100c48U)
#define WRITE ((typeof(&ad9361_reg_write))0x00100d04U)
#define PN_CHECK ((typeof(&rx_9361_check_pn))0x00104648U)
#define TIME ((void (*)(XTime *))0x00125e50U)
#define SLEEP ((void (*)(u32))0x00124ed8U)
#define MAP ((void (*)(u32,u32))0x001247bcU)
#define FLUSH ((void (*)(void))0x001242acU)
#define REG(a) (*(volatile u32 *)(a))
#define CORE 0x82000000U
volatile u32 header[128] __attribute__((section(".header")));
volatile u32 spi[1024] __attribute__((section(".spi")));
volatile u32 rows[4][32] __attribute__((section(".rows")));
static const u16 changed[] = {0x006,0x010,0x03d,0x03e,0x3f4,0x3f5,0x3f6};
static int get(u16 a,u32 *v) {
    u8 b=0; int r=READ(RADIO,a,&b); *v=b; return r;
}
static int put(u16 a,u32 v) {
    u32 b=0; if(WRITE(RADIO,a,v)||get(a,&b)||b!=v)return -1; return 0;
}
static int restore(void) {
    int r=0;
    if(put(0x3f4,0))r=-1;
    for(u32 i=0;i<sizeof(changed)/sizeof(changed[0]);++i)
        if(changed[i]!=0x3f4 && put(changed[i],spi[changed[i]]))r=-2;
    if(put(0x3f4,spi[0x3f4]))r=-3;
    return r;
}
int audit_entry(u32 action) {
    MAP(0x02500000U,0x11de2U);
    if(REG(0x80020000)!=0 || (REG(0x80020008)&4U) ||
       REG(CORE+0x1008)!=0x41445258U)return -10;
    int status=0;
    if(action==0) {
        for(u32 i=0;i<128;++i)header[i]=0;
        for(u32 i=0;i<1024;++i)spi[i]=0xffffffffU;
        header[0]=0x53504941U;
        for(u32 a=0;a<0x60;++a) {
            u32 v; if(get(a,&v))return -11; spi[a]=v;
        }
        const u16 extra[]={0x247,0x287,0x292,0x293,0x294,0x2ab,0x2ac,0x3f4,0x3f5,0x3f6};
        for(u32 i=0;i<sizeof(extra)/sizeof(extra[0]);++i) {
            u32 v; if(get(extra[i],&v))return -12;spi[extra[i]]=v;
        }
        header[8]=REG(CORE+0x40);header[9]=REG(CORE+0x44);
        for(u32 i=0;i<7;++i)header[16+i]=REG(CORE+0x800+4*i);
        for(u32 i=0;i<4;++i)header[24+i]=REG(CORE+0x418+0x40*i);
        header[1]=1;
    } else if(header[0]!=0x53504941U || header[1]!=1) return -13;
    else if(action==1) {
        if(put(0x3f4,0)||put(0x3f5,0)||put(0x3f6,0)||put(0x3f4,9))status=-14;
        for(u32 n=0;n<4&&!status;++n) {
            volatile u32 *r=rows[n];
            for(u32 j=0;j<32;++j)r[j]=0;
            r[0]=n;r[1]=spi[0x010]^(n&1U);r[2]=(n&2U)?0xff:spi[0x03d];
            r[3]=(n&2U)?((spi[0x03e]&0xf0U)|0xf):spi[0x03e];r[4]=spi[0x006];
            if(put(0x010,r[1])||put(0x03d,r[2])||put(0x03e,r[3])){status=-15;break;}
            SLEEP(2000);
            XTime a,b; TIME(&a);u32 edges=REG(CORE+0x1004);
            SLEEP(5000);r[12]=(REG(CORE+0x1004)-edges)&0xffffffU;
            TIME(&b);r[13]=(u32)(b-a);
            r[5]=(u32)PN_CHECK(RX,10000);
            for(u32 ch=0;ch<4;++ch)r[6+ch]=REG(CORE+0x404+0x40*ch);
            r[10]=RX->sample_delta;r[11]=RX->edge_delta;
            r[14]=REG(CORE+0x5c);r[15]=REG(CORE+0x54);r[16]=REG(CORE+0x58);
            header[6]=n+1;
            if((s32)r[5]==0)++header[7];
        }
        header[5]=(u32)restore();
        if(header[5])status=-16;
    } else if(action==2) status=restore();
    else return -17;
    header[2]=action;header[3]=(u32)status;
    header[10]=REG(0x80020000);header[11]=REG(0x80020008);
    FLUSH();return status;
}
