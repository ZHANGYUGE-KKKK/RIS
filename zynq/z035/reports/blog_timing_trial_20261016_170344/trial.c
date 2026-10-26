/* Bounded LVDS-compatible timing experiment motivated by the supplied blog.
 * Do not copy its CMOS register values. Save/read-back/restore every changed
 * setting. Only valid timing fields and existing IDELAY control are changed.
 * Absolute calls are valid only for the separately verified original ELF.
 */
#include "drivers/ad9361.h"
#include "drivers/rx_9361.h"
#include "xtime_l.h"
#define RADIO ((ad9361_device *)0x00148030U)
#define RX ((rx_9361_device *)0x00148868U)
#define READ ((typeof(&ad9361_reg_read))0x00100c48U)
#define WRITE ((typeof(&ad9361_reg_write))0x00100d04U)
#define SET_DELAY ((typeof(&rx_9361_set_delay))0x001044d0U)
#define PN_CHECK ((typeof(&rx_9361_check_pn))0x00104648U)
#define TIME ((void (*)(XTime *))0x00125e50U)
#define SLEEP ((void (*)(u32))0x00124ed8U)
#define MAP ((void (*)(u32,u32))0x001247bcU)
#define FLUSH ((void (*)(void))0x001242acU)
#define REG(a) (*(volatile u32 *)(a))
#define CORE 0x82000000U
volatile u32 header[128] __attribute__((section(".header")));
volatile u32 spi[1024] __attribute__((section(".spi")));
volatile u32 rows[256][32] __attribute__((section(".rows")));
static const u16 changed[]={0x006,0x010,0x011,0x3f4,0x3f5,0x3f6};
static int get(u16 a,u32 *v) {
    u8 b=0;int r=READ(RADIO,a,&b);*v=b;return r;
}
static int put(u16 a,u32 v) {
    u32 b=0;if(WRITE(RADIO,a,v)||get(a,&b)||b!=v)return -1;return 0;
}
static int restore(void) {
    int result=0;
    if(put(0x3f4,0))result=-1;
    for(u32 i=0;i<sizeof(changed)/sizeof(changed[0]);++i)
        if(changed[i]!=0x3f4 && put(changed[i],spi[changed[i]]))result=-2;
    if(put(0x3f4,spi[0x3f4]))result=-3;
    for(u32 i=0;i<7;++i)
        if(SET_DELAY(RX,i,header[16+i]) || REG(CORE+0x800+4*i)!=header[16+i])result=-4;
    return result;
}
static int point(u32 inv,u32 pattern,u32 delay,u32 slip,u32 observe,u32 kind) {
    u32 n=header[6];if(n>=256)return -20;
    volatile u32 *r=rows[n];for(u32 j=0;j<32;++j)r[j]=0;
    r[0]=n;r[1]=inv;r[2]=pattern;r[3]=delay;r[4]=slip;r[24]=observe;r[25]=kind;
    SLEEP(2000);
    XTime a,b;TIME(&a);u32 edge=REG(CORE+0x1004);
    SLEEP(5000);r[12]=(REG(CORE+0x1004)-edge)&0xffffffU;TIME(&b);r[13]=(u32)(b-a);
    r[5]=observe?(u32)PN_CHECK(RX,observe):(u32)-999;
    for(u32 ch=0;ch<4;++ch)r[6+ch]=REG(CORE+0x404+0x40*ch);
    r[10]=RX->sample_delta;r[11]=RX->edge_delta;
    r[14]=REG(CORE+0x54);r[15]=REG(CORE+0x58);r[16]=REG(CORE+0x5c);
    r[17]=REG(0x80020008);r[22]=REG(CORE+0x800);r[23]=REG(CORE+0x818);
    const u16 registers[]={0x010,0x011,0x006,0x012};
    for(u32 i=0;i<4;++i) {u32 v;if(get(registers[i],&v))return -21;r[18+i]=v;}
    u32 v;if(get(0x05e,&v))return -22;r[26]=v;
    if(get(0x3f4,&v))return -22;r[27]=v;
    if(r[21]!=spi[0x012] || REG(0x80020000)!=0 || (r[17]&4U))return -23;
    header[6]=n+1;if(observe && (s32)r[5]==0)++header[7];
    return 0;
}
int trial_entry(u32 action) {
    MAP(0x02700000U,0x11de2U);
    if(REG(0x80020000)!=0 || (REG(0x80020008)&4U) || REG(CORE+0x1008)!=0x41445258U)return -10;
    int status=0;
    if(action==0) {
        for(u32 i=0;i<128;++i)header[i]=0;
        for(u32 i=0;i<1024;++i)spi[i]=0xffffffffU;
        header[0]=0x424c4f47U;
        for(u32 a=0;a<0x60;++a) {u32 v;if(get(a,&v))return -11;spi[a]=v;}
        for(u32 a=0x3f4;a<=0x3f6;++a) {u32 v;if(get(a,&v))return -12;spi[a]=v;}
        for(u32 i=0;i<7;++i)header[16+i]=REG(CORE+0x800+4*i);
        header[8]=REG(CORE+0x40);header[9]=REG(CORE+0x44);header[1]=1;
    } else if(header[0]!=0x424c4f47U || header[1]!=1)return -13;
    else if(action==1) {
        if(spi[0x012]!=0x10 || spi[0x010]!=0xc8 || spi[0x011]!=0 || spi[0x006]!=0x0f)return -14;
        if(put(0x3f4,0)||put(0x3f5,0)||put(0x3f6,0)||put(0x3f4,9))status=-15;
        for(u32 i=0;i<3&&!status;++i)status=point(0,0,spi[6],0,10000,0);
        const u32 delays[]={0x0f,0x04,0x88};
        for(u32 pat=0;pat<4&&!status;++pat) {
            for(u32 lane=0;lane<7;++lane) {
                u32 use10=(pat==1&&lane==0)||(pat==2&&lane<6)||pat==3;
                if(SET_DELAY(RX,lane,use10?10:header[16+lane])){status=-16;break;}
            }
            for(u32 inv=0;inv<2&&!status;++inv)
                for(u32 d=0;d<3&&!status;++d)
                    for(u32 slip=0;slip<4&&!status;++slip) {
                        if(put(0x010,spi[0x010]^inv)||put(0x006,delays[d])||
                           put(0x011,(spi[0x011]&~3U)|slip)){status=-17;break;}
                        status=point(inv,pat,delays[d],slip,10000,1);
                        if(!status && (s32)rows[header[6]-1][5]==0)
                            status=point(inv,pat,delays[d],slip,100000,2);
                    }
        }
        header[5]=(u32)restore();if(header[5])status=-18;
        if(!status)status=point(0,0,spi[6],spi[0x011]&3U,0,3);
    } else if(action==2) {header[5]=(u32)restore();status=(s32)header[5];}
    else return -19;
    header[2]=action;header[3]=(u32)status;
    header[10]=REG(0x80020000);header[11]=REG(0x80020008);
    FLUSH();return status;
}
