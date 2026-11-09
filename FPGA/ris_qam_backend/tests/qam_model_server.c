/* Host-only AXI register model. Runs the real C driver and protocol parser.
 * Timing/ODDR correctness remains covered by the independent RTL benches.
 */
#include "ris_protocol.h"
#include "xil_io.h"
#include "xtime_l.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

static u32 regs[1024],patterns[2048][13],events[32768],symbols[270];
static u8 payload[4096],physical[50];
static unsigned frame_words,event_words,symbol_words,payload_bytes,prefix_words;
static ris_controller device;
static u32 blink;
static u64 timer;
void XTime_GetTime(XTime *t){*t=timer++;}
static unsigned off(UINTPTR address){return (unsigned)(address-RIS_BASE_ADDRESS);}
u32 Xil_In32(UINTPTR address){return regs[off(address)/4];}
static void held_from(unsigned id){unsigned i;for(i=0;i<13;++i)regs[(RIS_QAM_HELD_FRAME+i*4)/4]=patterns[id][i];
    for(i=0;i<50;++i)physical[i]=(u8)(patterns[id][i/4]>>(8*(i%4)));}
static void finish(void){
    if(regs[RIS_QAM_STATUS/4]&RIS_QAM_RUNNING){u32 desc=symbols[payload[payload_bytes-1]];
        held_from(events[(desc&65535u)+(desc>>16)-1]&65535u);regs[RIS_QAM_STATUS/4]=RIS_QAM_OWNED;}
}
void Xil_Out32(UINTPTR address,u32 value){
    unsigned a=off(address),i;regs[a/4]=value;
    if(a==RIS_REG_RESULT_POP)regs[RIS_REG_QUEUE_LEVEL/4]=0;
    if(a==RIS_REG_COMMIT){u32 op=regs[RIS_REG_OP_FLAGS/4]&255u;
        regs[RIS_REG_LAST_ACCEPTED/4]=regs[RIS_REG_RESULT_ID/4]=regs[RIS_REG_CMD_ID/4];
        regs[RIS_REG_RESULT_CODE/4]=1;regs[RIS_REG_QUEUE_LEVEL/4]=256;
        if(op==RIS_OP_SOFT_RESET){regs[RIS_REG_STATUS/4]=0x42;regs[RIS_REG_ERROR_FLAGS/4]=0;}
        if(op==RIS_OP_OUTPUT_ENABLE)regs[RIS_REG_STATUS/4]|=128;
        if(op==RIS_OP_OUTPUT_DISABLE)regs[RIS_REG_STATUS/4]&=~128u;
        if(op==RIS_OP_APPLY){u64 mask=regs[RIS_REG_MASK_LO/4]|((u64)regs[RIS_REG_MASK_HI/4]<<32);
            for(i=0;i<50;++i)if(mask&(1ULL<<i)){
                unsigned s=(i%4)*8,b=(regs[(RIS_REG_STAGE+i/4*4)/4]>>s)&255;
                u32 *w=&regs[(RIS_REG_IMAGE+i/4*4)/4];*w=(*w&~(255u<<s))|(b<<s);
                if(!(regs[RIS_QAM_STATUS/4]&RIS_QAM_OWNED))physical[i]=b;
            }regs[RIS_REG_FRAME_COUNT_LO/4]++;
        }
    }
    if(a==RIS_REG_FAST_CONTROL){
        if(value==8){regs[RIS_REG_FAST_STATUS/4]=1;regs[RIS_REG_FAST_TICKS_ACTIVE/4]=0;regs[RIS_REG_MT_STATUS/4]=0;}
        else if(!value){regs[RIS_REG_FAST_STATUS/4]&=~4u;regs[RIS_REG_FAST_TICKS_ACTIVE/4]=0;regs[RIS_REG_MT_STATUS/4]&=~1u;}
        else if(value==9){regs[RIS_REG_FAST_STATUS/4]=7;regs[RIS_REG_FAST_TICKS_ACTIVE/4]=regs[RIS_REG_FAST_TICKS_CONFIG/4];}
        else if(value==10 || value==11){regs[RIS_REG_FAST_STATUS/4]=7;regs[RIS_REG_MT_STATUS/4]=3;}
    }
    if(a==RIS_QAM_MODE)regs[a/4]=value==64 ? 64 : 256;
    if(a==RIS_QAM_CONTROL){
        if(value==16){regs[RIS_QAM_MODE/4]=256;regs[RIS_QAM_SLOT_TICKS/4]=60;frame_words=event_words=symbol_words=payload_bytes=prefix_words=0;
            regs[RIS_QAM_PREFIX_COUNT/4]=regs[RIS_QAM_PREAMBLE_ROWS/4]=0;
            regs[RIS_QAM_FRAME_COUNT/4]=regs[RIS_QAM_EVENT_COUNT/4]=regs[RIS_QAM_SYMBOL_COUNT/4]=regs[RIS_QAM_PAYLOAD_COUNT/4]=0;}
        else if(value==0)regs[RIS_QAM_STATUS/4]&=~(RIS_QAM_RUNNING|RIS_QAM_PREFLIGHT|RIS_QAM_PENDING);
        else if(value==8){
            for(i=0;i<50;++i)assert(physical[i]==((regs[(RIS_REG_IMAGE+i/4*4)/4]>>(8*(i%4)))&255));
            regs[RIS_QAM_STATUS/4]=0;
        } else if(value==1 || value==2){
            unsigned err=0;regs[RIS_QAM_ERROR/4]=0;
            for(i=0;i<256+prefix_words && !err;++i){unsigned j,sum=0,first=symbols[i]&65535u,count=symbols[i]>>16;
                if(!count || first+count>event_words){err=1;break;}
                for(j=first;j<first+count;++j){if((events[j]&65535u)>=frame_words/13 || (!(events[j]>>16) || (regs[RIS_QAM_MODE/4]==64 && (events[j]>>16)<29))){err=2;break;}sum+=events[j]>>16;}
                if(!err && sum!=regs[RIS_QAM_PERIOD_SLOTS/4])err=3;
            }
            if(err){regs[RIS_QAM_ERROR/4]=err;regs[RIS_QAM_STATUS/4]=16;}
            else{held_from(events[symbols[prefix_words ? 256 : payload[0]]&65535u]&65535u);regs[RIS_QAM_STATUS/4]=3;}
        }
    }
    if(a==RIS_QAM_FRAME_DATA){assert(frame_words<2048*13);patterns[frame_words/13][frame_words%13]=value;frame_words++;
        regs[RIS_QAM_FRAME_COUNT/4]=(frame_words/13)|((frame_words%13)<<12);}
    if(a==RIS_QAM_EVENT_DATA){assert(event_words<32768);events[event_words++]=value;regs[RIS_QAM_EVENT_COUNT/4]=event_words;}
    if(a==RIS_QAM_SYMBOL_DATA){assert(symbol_words<256);symbols[symbol_words++]=value;regs[RIS_QAM_SYMBOL_COUNT/4]=symbol_words;}
    if(a==RIS_QAM_PREFIX_DATA){assert(prefix_words<14);symbols[256+prefix_words++]=value;regs[RIS_QAM_PREFIX_COUNT/4]=prefix_words;}
    if(a==RIS_QAM_PAYLOAD_DATA){assert(payload_bytes<4096);payload[payload_bytes++]=value;regs[RIS_QAM_PAYLOAD_COUNT/4]=payload_bytes;}
}
int main(void){
    char line[160],reply[2048];
    setbuf(stdout,NULL);
    regs[RIS_REG_ID/4]=RIS_DEVICE_ID;regs[RIS_REG_FAST_ID/4]=RIS_FAST_DEVICE_ID;regs[RIS_REG_MT_ID/4]=RIS_MT_DEVICE_ID;
    regs[RIS_QAM_ID/4]=RIS_QAM_ID_VALUE;regs[RIS_REG_FAST_STATUS/4]=1;regs[RIS_REG_STATUS/4]=0x42;
    regs[RIS_REG_FRAME_SLOTS/4]=16;regs[RIS_REG_MT_PERIOD/4]=300;
    regs[RIS_QAM_SLOT_TICKS/4]=60;regs[RIS_QAM_REPEATS/4]=3;regs[RIS_QAM_PERIOD_SLOTS/4]=256;
    regs[RIS_QAM_FRAME_CAPACITY/4]=2048;regs[RIS_QAM_EVENT_CAPACITY/4]=32768;regs[RIS_QAM_BYTE_CAPACITY/4]=4096;
    regs[RIS_QAM_PREFIX_ID/4]=RIS_QAM_PREFIX_ID_VALUE;regs[RIS_QAM_PREFIX_CAPACITY/4]=14;
    regs[RIS_QAM64_ID/4]=RIS_QAM64_ID_VALUE;regs[RIS_QAM_MODE/4]=256;regs[RIS_QAM64_MIN_EVENT/4]=29;
    regs[RIS_QAM_MIN_TICKS/4]=60;regs[RIS_QAM_CLOCK_HZ/4]=300000000;
    assert(ris_initialize(&device,RIS_BASE_ADDRESS)==0);
    while(fgets(line,sizeof(line),stdin)){
        line[strcspn(line,"\r\n")]=0;
        if(!strcmp(line,"_FINISH")){finish();puts("OK");continue;}
        if(!strcmp(line,"_NEW_SESSION")){ris_mt_cancel_upload(&device);ris_qam_cancel_upload(&device);puts("OK");continue;}
        ris_protocol_execute(&device,line,reply,sizeof(reply),&blink);fputs(reply,stdout);
    }
    return 0;
}
