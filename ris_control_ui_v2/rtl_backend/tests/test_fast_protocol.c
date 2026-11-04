#include "ris_protocol.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static u8 image[50];
static u32 fast, ticks, enabled=1, mt_running, mt_period=300;
u32 ris_read(const ris_controller *d,u32 address) {
    u32 v=0,n;
    (void)d;
    if(address==RIS_REG_STATUS)return 0x42u|(enabled ? 128u : 0u);
    if(address==RIS_REG_FRAME_SLOTS)return 16;
    if(address==RIS_REG_MT_STATUS)return mt_running;
    if(address==RIS_REG_MT_PERIOD)return mt_period;
    if(address==RIS_REG_FAST_EDGES)return 0xffffffffu;
    if(address>=RIS_REG_IMAGE && address<RIS_REG_IMAGE+52) {
        for(n=0;n<4 && address-RIS_REG_IMAGE+n<50;n++)v|=(u32)image[address-RIS_REG_IMAGE+n]<<(8*n);
    }
    return v;
}
u64 ris_frame_count(const ris_controller *d){(void)d;return UINT64_MAX;}
u32 ris_fast_mhz(const ris_controller *d){(void)d;return fast;}
u32 ris_fast_ticks(const ris_controller *d){(void)d;return ticks;}
int ris_fast_start_ticks(ris_controller *d,u32 value){assert(d->fast_supported);ticks=value;fast=ticks==150 ? 1 : ticks==50 ? 3 : ticks==30 ? 5 : 0;enabled=1;memset(image,0,50);return 0;}
int ris_fast_start_hz(ris_controller *d,u32 hz){return ris_fast_start_ticks(d,(150000000u+hz/2)/hz);}
int ris_fast_stop(ris_controller *d){(void)d;mt_running=0;if(ticks)memset(image,255,50);fast=0;ticks=0;return 0;}
int ris_fast_start(ris_controller *d,u32 mhz){return ris_fast_start_hz(d,mhz*1000000);}
int ris_output_enable(ris_controller *d,int en){(void)d;enabled=en;if(!en){fast=0;ticks=0;}return 0;}
int ris_apply_pattern(ris_controller *d,const u8 value[50],u64 mask){(void)d;for(unsigned n=0;n<50;n++)if(mask&(1ULL<<n))image[n]=value[n];return 0;}
void ris_mt_cancel_upload(ris_controller *d){d->mt_loaded=d->mt_expected=0;}
int ris_mt_begin(ris_controller *d,u32 count,u32 start,u32 period,u32 delay){
    if(!d->mt_supported || !count || count>2048 || start>=count || period<60 || period>300000000 || delay>0x7fffffff)return -3;
    ris_fast_stop(d);d->mt_expected=count;d->mt_loaded=0;d->mt_checksum=2166136261u;mt_period=period;return 0;
}
int ris_mt_segment(ris_controller *d,u32 index,u32 level,u32 duration){
    if(!d->mt_expected || index!=d->mt_loaded || index>=d->mt_expected || level>1 || duration<30 || duration>0x7fffffff)return -3;
    d->mt_checksum=(d->mt_checksum^((level<<31)|duration))*16777619u;
    d->mt_loaded++;d->mt_last_level=level;return 0;
}
int ris_mt_start(ris_controller *d,u32 loop,u32 sum){
    if(loop>1 || !d->mt_expected || d->mt_loaded!=d->mt_expected || sum!=d->mt_checksum || (!loop && d->mt_last_level))return -3;
    mt_running=1;ticks=fast=0;ris_mt_cancel_upload(d);return 0;
}
static void execute(ris_controller *d,const char *command,char reply[512],u32 *blink) {
    char line[160];strcpy(line,command);
    ris_protocol_execute(d,line,reply,512,blink);
    assert(strlen(reply)<511 && reply[strlen(reply)-1]=='\n');
}
int main(void) {
    ris_controller dev={.fast_supported=1};
    u32 blink=2000;char reply[512];
    execute(&dev,"1 FAST 5",reply,&blink);
    assert(fast==5 && blink==0 && strstr(reply,"\"fast_mhz\":5") && strstr(reply,"\"ok\":true"));
    execute(&dev,"2 FAST 2",reply,&blink);
    assert(fast==5 && strstr(reply,"\"rc\":-7"));
    execute(&dev,"3 BIT 0 0 0",reply,&blink);
    assert(!fast && image[0]==254);for(unsigned n=1;n<50;n++)assert(image[n]==255);
    execute(&dev,"4 FAST 3",reply,&blink);execute(&dev,"5 STOP",reply,&blink);
    assert(!fast && enabled);for(unsigned n=0;n<50;n++)assert(image[n]==255);
    execute(&dev,"6 FAST 1",reply,&blink);execute(&dev,"7 BLINK 100",reply,&blink);
    assert(!fast && blink==100 && strstr(reply,"\"fast_edges\":4294967295"));
    execute(&dev,"8 OE 0",reply,&blink);assert(!enabled && !blink);
    execute(&dev,"9 FASTHZ 2400000",reply,&blink);
    assert(ticks==63 && strstr(reply,"\"fast_ticks\":63") && strstr(reply,"\"fast_variable\":true"));
    execute(&dev,"10 FASTTICKS 150000000",reply,&blink);assert(ticks==150000000);
    const char *bad[]={"11 FASTHZ 0","12 FASTHZ 5000001","13 FASTHZ -1","14 FASTHZ NaN","15 FASTTICKS 29","16 FASTTICKS 150000001","17 FASTTICKS 30.1"};
    for(unsigned n=0;n<sizeof(bad)/sizeof(bad[0]);n++){
        execute(&dev,bad[n],reply,&blink);assert(ticks==150000000 && strstr(reply,"\"rc\":-7"));
    }
    execute(&dev,"18 STOP",reply,&blink);assert(!ticks);
    dev.mt_supported=1;
    execute(&dev,"19 MTBEGIN 2 0 300 30",reply,&blink);assert(dev.mt_expected==2 && !dev.mt_loaded);
    execute(&dev,"20 MTSEG 0 1 150",reply,&blink);assert(dev.mt_loaded==1);
    execute(&dev,"21 MTSTART 1 0",reply,&blink);assert(!mt_running);
    execute(&dev,"22 MTSEG 1 0 150",reply,&blink);assert(dev.mt_loaded==2);
    char start[80];snprintf(start,sizeof(start),"23 MTSTART 1 %u",dev.mt_checksum);
    execute(&dev,start,reply,&blink);assert(mt_running && strstr(reply,"\"mt_running\":true"));
    execute(&dev,"24 STOP",reply,&blink);assert(!mt_running);
    execute(&dev,"25 MTBEGIN 2049 0 300 0",reply,&blink);assert(strstr(reply,"\"ok\":false"));
    execute(&dev,"26 MTBEGIN 2 0 300 0",reply,&blink);
    execute(&dev,"27 MTSEG 1 1 30",reply,&blink);assert(!dev.mt_loaded);
    execute(&dev,"28 MTSEG 0 1 29",reply,&blink);assert(!dev.mt_loaded);
    execute(&dev,"29 MTBEGIN 2 0 300000000 0",reply,&blink);
    execute(&dev,"30 MTSEG 0 1 30",reply,&blink);
    execute(&dev,"31 STOP",reply,&blink);assert(!dev.mt_loaded && !dev.mt_expected);
    puts("PASS: FAST, STOP hold, BIT/BLINK takeover, OE; MT upload/order/checksum/bounds/cancel; 512-byte response bound");
    return 0;
}
