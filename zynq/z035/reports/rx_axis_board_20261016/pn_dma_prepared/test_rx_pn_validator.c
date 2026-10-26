#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
typedef uint32_t u32; typedef uint16_t u16; typedef int16_t s16; typedef int32_t s32;
typedef struct {s16 i1,q1,i2,q2;} dma_9361_sample;
#define RX_9361_OK 0
#define RX_9361_ERR_PN -4
volatile struct {
    u32 magic, done, stage;
    s32 result, restore_status;
    u32 samples, bytes, completed_packets, dma_status, bd_status, capture_status;
    u32 sign_errors, iq_overlap_errors[2], pn_sequence_errors[2];
    u32 seed[2], saved_taps[7], first_words[16];
} rx_pn_dma_report;


static u16 rx_pn_reverse12(u16 value)
{
    u32 bit;
    u16 result = 0U;
    for (bit = 0U; bit < 12U; ++bit)
        result |= ((value >> bit) & 1U) << (11U-bit);
    return result;
}

static u16 rx_pn_next(u16 state)
{
    u32 bit, feedback = ((state >> 1) ^ (state >> 2)) & 1U;
    for (bit = 4U; bit < 16U; ++bit) feedback ^= (state >> bit) & 1U;
    return (u16)((state << 1) | feedback);
}

static int rx_pn_validate_samples(const dma_9361_sample *samples, u32 count)
{
    u32 n, channel, component;
    u16 predicted[2] = {0U, 0U}, observed, i_word, q_reversed;
    s16 values[4];
        for (n = 0U; n < count; ++n) {
            memcpy(values, &samples[n], sizeof(values));
            for (component = 0U; component < 4U; ++component)
                if (values[component] < -2048 || values[component] > 2047)
                    ++rx_pn_dma_report.sign_errors;
            if (n < 8U) {
                rx_pn_dma_report.first_words[n*2U] = (u16)values[0] | ((u32)(u16)values[1] << 16);
                rx_pn_dma_report.first_words[n*2U+1U] = (u16)values[2] | ((u32)(u16)values[3] << 16);
            }
            for (channel = 0U; channel < 2U; ++channel) {
                i_word = (u16)values[channel*2U] & 0x0FFFU;
                q_reversed = rx_pn_reverse12((u16)values[channel*2U+1U] & 0x0FFFU);
                if ((i_word & 0xFFU) != (q_reversed >> 4))
                    ++rx_pn_dma_report.iq_overlap_errors[channel];
                observed = (u16)((i_word << 4) | (q_reversed & 0xFU));
                if (!n) {
                    rx_pn_dma_report.seed[channel] = observed;
                    predicted[channel] = observed;
                    if (!observed) ++rx_pn_dma_report.pn_sequence_errors[channel];
                } else {
                    predicted[channel] = rx_pn_next(predicted[channel]);
                    if (observed != predicted[channel])
                        ++rx_pn_dma_report.pn_sequence_errors[channel];
                }
            }
        }
        if (rx_pn_dma_report.sign_errors || rx_pn_dma_report.iq_overlap_errors[0] ||
            rx_pn_dma_report.iq_overlap_errors[1] || rx_pn_dma_report.pn_sequence_errors[0] ||
            rx_pn_dma_report.pn_sequence_errors[1]) return RX_9361_ERR_PN;
    return RX_9361_OK;
}


static dma_9361_sample good[4096], mutated[4096];
static uint16_t reverse_by_nibbles(uint16_t x) {
    static const unsigned char lut[16]={0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15};
    return (lut[x&15]<<8)|(lut[(x>>4)&15]<<4)|lut[(x>>8)&15];
}
static int16_t signed12(uint16_t x) { return (x&0x800)?(int16_t)(x|0xf000):x; }
static void check(const char *name,int expected) {
    memset((void*)&rx_pn_dma_report,0,sizeof(rx_pn_dma_report));
    int result=rx_pn_validate_samples(mutated,4096);
    assert((result==0)==expected);
    printf("PASS %s result=%d sign=%u iq=%u/%u pn=%u/%u\n",name,result,
       rx_pn_dma_report.sign_errors,rx_pn_dma_report.iq_overlap_errors[0],rx_pn_dma_report.iq_overlap_errors[1],
       rx_pn_dma_report.pn_sequence_errors[0],rx_pn_dma_report.pn_sequence_errors[1]);
}
int main(void) {
    uint16_t state[2]={0xace1,0xb7e3};
    for(unsigned n=0;n<4096;n++) {
        int16_t *v=(int16_t*)&good[n];
        for(unsigned ch=0;ch<2;ch++) {
            v[ch*2]=signed12(state[ch]>>4);
            v[ch*2+1]=signed12(reverse_by_nibbles(state[ch]&0xfff));
            state[ch]=(state[ch]<<1)|__builtin_parity((unsigned)(state[ch]&0xfff6));
        }
    }
    memcpy(mutated,good,sizeof good); check("clean4096tuples",1);
    memcpy(mutated,good,sizeof good); mutated[100].i1^=1; check("I1bitcorruption",0);
    memcpy(mutated,good,sizeof good); mutated[100].q2^=1; check("Q2bitcorruption",0);
    memcpy(mutated,good,sizeof good); mutated[100]=mutated[99]; check("duplicatedtuple",0);
    memcpy(mutated,good,sizeof good); memmove(&mutated[100],&mutated[101],3995*sizeof(mutated[0])); check("droppedtuple",0);
    memcpy(mutated,good,sizeof good); for(unsigned n=0;n<4096;n++){int16_t tmp=mutated[n].i1;mutated[n].i1=mutated[n].q1;mutated[n].q1=tmp;} check("IQswap",0);
    memcpy(mutated,good,sizeof good); mutated[100].i2^=0x8000; check("badsignextension",0);
    memset(mutated,0,sizeof mutated); check("constantzero",0);
    return 0;
}
