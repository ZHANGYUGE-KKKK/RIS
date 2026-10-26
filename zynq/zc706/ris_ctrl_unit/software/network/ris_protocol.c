#include "ris_protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

static int number(const char *s,u32 *value)
{
    char *end;
    unsigned long n;
    if (!s || *s<'0' || *s>'9') return 0;
    errno=0; n=strtoul(s,&end,10);
    if (errno || *end || n>0xffffffffUL) return 0;
    *value=(u32)n; return 1;
}
static int hex(char c)
{
    if (c>='0' && c<='9') return c-'0';
    if (c>='a' && c<='f') return c-'a'+10;
    if (c>='A' && c<='F') return c-'A'+10;
    return -1;
}
static int byte(const char *s,u8 *value)
{
    int a,b;
    if (!s || strlen(s)!=2 || (a=hex(s[0]))<0 || (b=hex(s[1]))<0) return 0;
    *value=(u8)((a<<4)|b); return 1;
}
int ris_protocol_execute(ris_controller *dev,char *line,char *reply,size_t capacity,u32 *blink_ms)
{
    char *tokens[6],*save,*token;
    unsigned count=0,i;
    u32 id=0,index=0,bit=0,value=0,status,errors;
    u8 image[50],data=0;
    u64 mask=0,frames;
    int rc=-7,restart=0,valid=1;
    char image_hex[101];
    for (token=strtok_r(line," \t",&save);token;token=strtok_r(NULL," \t",&save)) {
        if (count==6) {valid=0; break;}
        tokens[count++]=token;
    }
    if (count<2 || !number(tokens[0],&id) || id==0) valid=0;
    for (i=0;i<50;++i) image[i]=(u8)(ris_read(dev,RIS_REG_IMAGE+(i/4)*4)>>((i%4)*8));
    if (valid) {
        const char *op=tokens[1];
        if (strcmp(op,"STATUS")==0 && count==2) rc=0;
        else if (strcmp(op,"STOP")==0 && count==2) {*blink_ms=0; rc=ris_fast_stop(dev);}
        else if (strcmp(op,"FAST")==0 && count==3 && number(tokens[2],&value) && (value==1 || value==3 || value==5)) {
            *blink_ms=0; rc=ris_fast_start(dev,value);
        }
        else if (strcmp(op,"FASTHZ")==0 && count==3 && number(tokens[2],&value) && value>=1 && value<=5000000) {
            *blink_ms=0; rc=ris_fast_start_hz(dev,value);
        }
        else if (strcmp(op,"FASTTICKS")==0 && count==3 && number(tokens[2],&value) && value>=RIS_FAST_MIN_TICKS && value<=RIS_FAST_MAX_TICKS) {
            *blink_ms=0; rc=ris_fast_start_ticks(dev,value);
        }
        else if (strcmp(op,"BLINK")==0 && count==3 && number(tokens[2],&value) && value>=100 && value<=60000) {
            rc=ris_fast_stop(dev);
            if (!rc) rc=ris_output_enable(dev,1);
            if (!rc) {*blink_ms=value; restart=1;}
        } else if (strcmp(op,"OE")==0 && count==3 && number(tokens[2],&value) && value<=1) {
            if (!value) *blink_ms=0;
            rc=ris_output_enable(dev,(int)value);
        } else {
            if (strcmp(op,"ALL")==0 && count==3 && number(tokens[2],&value) && value<=1) {
                memset(image,value ? 0xff : 0,sizeof(image)); mask=0x3ffffffffffffULL;
            } else if (strcmp(op,"CHIP")==0 && count==4 && number(tokens[2],&index) && index<50 && byte(tokens[3],&data)) {
                image[index]=data; mask=1ULL<<index;
            } else if (strcmp(op,"GROUP")==0 && count==4 && number(tokens[2],&index) && index<10 && byte(tokens[3],&data)) {
                for (i=index*5;i<index*5+5;++i) image[i]=data;
                mask=31ULL<<(index*5);
            } else if (strcmp(op,"BIT")==0 && count==5 && number(tokens[2],&index) && index<50 && number(tokens[3],&bit) && bit<8 && number(tokens[4],&value) && value<=1) {
                image[index]=(u8)((image[index]&~(1u<<bit)) | (value<<bit)); mask=1ULL<<index;
            } else if (strcmp(op,"FRAME")==0 && count==3 && strlen(tokens[2])==100) {
                for (i=0;i<50;++i) {
                    int a=hex(tokens[2][i*2]),b=hex(tokens[2][i*2+1]);
                    if (a<0 || b<0) break;
                    image[i]=(u8)((a<<4)|b);
                }
                if (i==50) mask=0x3ffffffffffffULL;
            }
            if (mask) {
                *blink_ms=0;
                rc=ris_fast_stop(dev);
                if (!rc && strcmp(op,"BIT")==0) {
                    image[index]=(u8)(ris_read(dev,RIS_REG_IMAGE+(index/4)*4)>>((index%4)*8));
                    image[index]=(u8)((image[index]&~(1u<<bit)) | (value<<bit));
                }
                if (!rc) rc=ris_apply_pattern(dev,image,mask);
                if (!rc) rc=ris_output_enable(dev,1);
            }
        }
    }
    if (rc && rc!=-7) {*blink_ms=0; (void)ris_output_enable(dev,0);}
    for (i=0;i<50;++i) {
        static const char digits[]="0123456789ABCDEF";
        u8 v=(u8)(ris_read(dev,RIS_REG_IMAGE+(i/4)*4)>>((i%4)*8));
        image_hex[i*2]=digits[v>>4]; image_hex[i*2+1]=digits[v&15];
    }
    image_hex[100]=0; status=ris_read(dev,RIS_REG_STATUS);
    errors=ris_read(dev,RIS_REG_ERROR_FLAGS); frames=ris_frame_count(dev);
    snprintf(reply,capacity,"{\"device\":\"RIS706\",\"version\":1,\"id\":%lu,\"ok\":%s,\"rc\":%d,\"status\":%lu,\"errors\":%lu,\"frames\":%llu,\"oe\":%s,\"blink_ms\":%lu,\"slots\":%lu,\"fast_supported\":%s,\"fast_mhz\":%lu,\"fast_variable\":%s,\"fast_ticks\":%lu,\"fast_edges\":%lu,\"image\":\"%s\"}\n",
        (unsigned long)id,(!rc && !errors) ? "true" : "false",rc,(unsigned long)status,
        (unsigned long)errors,(unsigned long long)frames,(status&128) ? "true" : "false",
        (unsigned long)*blink_ms,(unsigned long)ris_read(dev,RIS_REG_FRAME_SLOTS),
        dev->fast_supported ? "true" : "false",(unsigned long)ris_fast_mhz(dev),
        dev->fast_supported ? "true" : "false",(unsigned long)ris_fast_ticks(dev),
        (unsigned long)(dev->fast_supported ? ris_read(dev,RIS_REG_FAST_EDGES) : 0),image_hex);
    return restart;
}
