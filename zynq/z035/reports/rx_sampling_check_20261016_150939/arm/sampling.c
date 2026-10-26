/* Temporary PS-DDR experiment; calls the existing application drivers.
 * ARM and DMA remain stopped. Every changed setting is saved and restored. */
#include "drivers/ad9361.h"
#include "drivers/rx_9361.h"
#include "xtime_l.h"
#define RADIO ((ad9361_device *)0x00148030U)
#define RX ((rx_9361_device *)0x00148868U)
#define READ ((typeof(&ad9361_reg_read))0x00100c48U)
#define WRITE ((typeof(&ad9361_reg_write))0x00100d04U)
#define SET_DELAY ((typeof(&rx_9361_set_delay))0x001044d0U)
#define SET_UNIFORM ((typeof(&rx_9361_set_uniform_delay))0x001045bcU)
#define PN_CHECK ((typeof(&rx_9361_check_pn))0x00104648U)
#define TIME ((void (*)(XTime *))0x00125e50U)
#define SLEEP ((void (*)(u32))0x00124ed8U)
#define MAP ((void (*)(u32,u32))0x001247bcU)
#define FLUSH ((void (*)(void))0x001242acU)
#define REG(a) (*(volatile u32 *)(a))
#define CORE 0x82000000U
#define ROW_WORDS 24U
#define MAX_ROWS 2048U
volatile u32 sampling_header[128] __attribute__((section(".header")));
volatile u32 sampling_spi[1024] __attribute__((section(".spi")));
volatile u32 sampling_rows[MAX_ROWS][ROW_WORDS] __attribute__((section(".rows")));

static int read_reg(u32 addr, u32 *value)
{
    u8 byte;
    int status=READ(RADIO,addr,&byte);
    *value=byte;
    return status;
}
static int write_verify(u32 addr,u32 value)
{
    u32 actual;
    if (WRITE(RADIO,addr,value) || read_reg(addr,&actual) || actual!=value) return -1;
    return 0;
}
static int restore_delays(void)
{
    for (u32 i=0;i<7;++i) if (SET_DELAY(RX,i,sampling_header[11+i])) return -1;
    return 0;
}
static int enable_prbs(void)
{
    if (write_verify(0x3f4,0) || write_verify(0x3f5,0) ||
        write_verify(0x3f6,0) || write_verify(0x3f4,9)) return -1;
    SLEEP(1000);
    return 0;
}
static int point(u32 group,u32 arg0,u32 arg1,u32 prbs)
{
    u32 n=sampling_header[6];
    if (n>=MAX_ROWS) return -1;
    volatile u32 *r=sampling_rows[n];
    for (u32 i=0;i<ROW_WORDS;++i) r[i]=0;
    r[0]=group;r[1]=arg0;r[2]=arg1;
    SLEEP(200);
    XTime start,finish;
    TIME(&start);
    u32 edges=REG(CORE+0x1004), samples=REG(CORE+0x1000);
    SLEEP(5000);
    r[7]=(REG(CORE+0x1004)-edges)&0xffffffU;
    r[8]=(REG(CORE+0x1000)-samples)&0xffffffU;
    TIME(&finish);r[9]=(u32)(finish-start);
    for (u32 i=0;i<256;++i) if (!(REG(CORE+0x5c)&1U)) ++r[4];
    r[5]=256;
    r[3]=prbs ? (u32)PN_CHECK(RX,1000) : (u32)-999;
    r[6]=REG(CORE+0x5c);r[10]=REG(CORE+0x54);r[11]=REG(CORE+0x58);
    for (u32 i=0;i<4;++i) r[12+i]=REG(CORE+0x404+0x40*i);
    r[16]=REG(CORE+0x44);r[17]=REG(CORE+0x800);r[18]=REG(CORE+0x818);
    u32 value;
    if (read_reg(0x006,&value)) return -2;r[19]=value;
    if (read_reg(0x010,&value)) return -2;r[20]=value;
    if (read_reg(0x009,&value)) return -2;r[21]=value;
    r[22]=REG(0x80020008);
    sampling_header[6]=n+1;
    if (prbs && (s32)r[3]==0) ++sampling_header[7];
    return 0;
}

int sampling_entry(u32 action,u32 arg0,u32 arg1)
{
    MAP(0x02300000U,0x11de2U);
    sampling_header[2]=1;sampling_header[3]=action;
    int status=0;
    if (action==0) {
        for (u32 i=0;i<128;++i) sampling_header[i]=0;
        sampling_header[0]=0x53414d50U;
        for (u32 i=0;i<1024;++i) sampling_spi[i]=0xffffffffU;
        if (REG(0x80020000)!=0 || (REG(0x80020008)&0x04U)) return -10;
        for (u32 a=0;a<0x60;++a) {
            u32 v;if (read_reg(a,&v)) return -11;sampling_spi[a]=v;
        }
        for (u32 a=0x3f4;a<=0x3f6;++a) {
            u32 v;if (read_reg(a,&v)) return -12;sampling_spi[a]=v;
        }
        for (u32 i=0;i<7;++i) sampling_header[11+i]=REG(CORE+0x800+4*i);
        sampling_header[8]=REG(CORE+0x44);sampling_header[9]=REG(CORE+0x40);
        sampling_header[10]=REG(0x80020000);
        sampling_header[21]=COUNTS_PER_SECOND;
        sampling_header[1]=1;
        for (u32 i=0;i<10 && !status;++i) status=point(0,i,0,0);
    } else {
        if (sampling_header[0]!=0x53414d50U || sampling_header[1]!=1) return -13;
        if (REG(0x80020000)!=0 || (REG(0x80020008)&0x04U)) return -14;
        if (action==1) {
            status=enable_prbs();
            u32 best=0,best_low=257;
            for (u32 f=0;f<32 && !status;++f) {
                status=SET_UNIFORM(RX,0,f);
                if (!status) status=point(1,f,0,1);
                u32 low=sampling_rows[sampling_header[6]-1][4];
                if (low<best_low) {best_low=low;best=f;}
            }
            sampling_header[22]=best;sampling_header[23]=best_low;
        } else if (action==2) {
            /* Full device clock/data matrix, both DATA_CLK polarities. */
            status=restore_delays();
            for (u32 inv=0;inv<2 && !status;++inv) {
                status=write_verify(0x010,sampling_spi[0x010]^inv);
                for (u32 c=0;c<16 && !status;++c)
                    for (u32 d=0;d<16 && !status;++d) {
                        status=write_verify(0x006,(c<<4)|d);
                        if (!status) status=point(2,inv,(c<<4)|d,1);
                    }
            }
            if (write_verify(0x010,sampling_spi[0x010]) ||
                write_verify(0x006,sampling_spi[0x006])) status=-15;
        } else if (action==3) {
            /* Independent FPGA data/frame delay matrix. */
            for (u32 f=0;f<32 && !status;++f)
                for (u32 d=0;d<32 && !status;++d) {
                    status=SET_UNIFORM(RX,d,f);
                    if (!status) status=point(3,f,d,1);
                }
            if (restore_delays()) status=-16;
        } else if (action==4) {
            status=SET_UNIFORM(RX,arg1,arg0);
            if (!status) status=point(4,arg0,arg1,1);
        } else if (action==5) {
            status=restore_delays();
            if (write_verify(0x010,sampling_spi[0x010]^arg0) ||
                write_verify(0x006,arg1)) status=-17;
            if (!status) status=point(5,arg0,arg1,1);
        } else if (action==6) {
            status=enable_prbs();
            if (!status) status=point(6,0,0,1);
        } else if (action==7) {
            /* Restore every register changed by this experiment. */
            if (write_verify(0x010,sampling_spi[0x010]) ||
                write_verify(0x006,sampling_spi[0x006]) || restore_delays() ||
                write_verify(0x3f4,0) || write_verify(0x3f5,sampling_spi[0x3f5]) ||
                write_verify(0x3f6,sampling_spi[0x3f6]) ||
                write_verify(0x3f4,sampling_spi[0x3f4])) status=-18;
            sampling_header[5]=status;
            for (u32 i=0;i<7;++i)
                if (REG(CORE+0x800+4*i)!=sampling_header[11+i]) sampling_header[5]=-19;
            if (REG(CORE+0x44)!=sampling_header[8] || REG(0x80020000)!=sampling_header[10])
                sampling_header[5]=-20;
            status=sampling_header[5];
            if (!status) status=point(7,0,0,0);
        } else status=-21;
    }
    sampling_header[4]=status;sampling_header[2]=100;
    FLUSH();return status;
}
