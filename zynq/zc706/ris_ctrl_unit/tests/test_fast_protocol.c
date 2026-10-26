#include "ris_protocol.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static u8 image[50];
static u32 fast, ticks, enabled=1;
u32 ris_read(const ris_controller *d,u32 address) {
    u32 v=0,n;
    (void)d;
    if(address==RIS_REG_STATUS)return 0x42u|(enabled ? 128u : 0u);
    if(address==RIS_REG_FRAME_SLOTS)return 16;
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
int ris_fast_stop(ris_controller *d){(void)d;if(ticks)memset(image,255,50);fast=0;ticks=0;return 0;}
int ris_fast_start(ris_controller *d,u32 mhz){return ris_fast_start_hz(d,mhz*1000000);}
int ris_output_enable(ris_controller *d,int en){(void)d;enabled=en;if(!en){fast=0;ticks=0;}return 0;}
int ris_apply_pattern(ris_controller *d,const u8 value[50],u64 mask){(void)d;for(unsigned n=0;n<50;n++)if(mask&(1ULL<<n))image[n]=value[n];return 0;}
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
    puts("PASS: FAST 1/3/5, unsupported preset, STOP hold, BIT takeover preserves seven other bits, BLINK takeover, OE, 512-byte response bound");
    return 0;
}
