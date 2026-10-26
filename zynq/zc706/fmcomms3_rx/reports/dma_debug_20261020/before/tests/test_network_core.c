/* Compile the real layout, capture state machine and command dispatcher with
 * a fake DMA/timer. The TCP tests call the same dispatcher via a shared lib. */
#include "capture_store.h"
#include "rx_control.h"
#include "rx_network.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <stdlib.h>

static dma_9361_device device;
static gpio_9361_device gpio;
static XTime clock_ticks;
static int dma_result, reset_result, change_config, auto_complete, polls;
static unsigned char response[RX_NET_FRAME_BYTES];
static char pending[RX_NET_COMMAND_BYTES];
static int pending_valid;
static u32 response_bytes;
static char queued_key;
void XTime_GetTime(XTime *now) { clock_ticks += 1000; *now = clock_ticks; }
int dma_9361_prepare(dma_9361_device *d, UINTPTR bd, UINTPTR buf, u32 count)
{
    assert(bd == CAPTURE_BD_BASE && buf == CAPTURE_DATA_BASE);
    d->packet_count = count; d->completed_packets = d->received_bytes = 0;
    d->buffer_base = buf; d->buffer_bytes = count * CAPTURE_PACKET_BYTES;
    if (d->buffer_bytes <= 8U*1024U*1024U) {
        u32 i;
        s16 *p = (s16 *)buf;
        for (i = 0; i < d->buffer_bytes / 2U; ++i)
            p[i] = (s16)(((i + i / 4096U) & 4095U) - 2048U);
    }
    return 0;
}
int dma_9361_start(dma_9361_device *d)
{ (void)d; polls = 0; if (auto_complete) dma_result = DMA_9361_PENDING; return 0; }
int dma_9361_poll(dma_9361_device *d)
{
    if (auto_complete && ++polls >= 3) dma_result = 0;
    if (!dma_result) { d->completed_packets = d->packet_count; d->received_bytes = d->buffer_bytes; }
    return dma_result;
}
int gpio_9361_get_status(gpio_9361_device *g, u32 *status)
{ (void)g; *status = 3; return 0; }
static int rearm(void) { return reset_result; }
static int config(u8 *v)
{
    memset(v, 0, CAPTURE_RF_REGS);
    v[0] = (u8)change_config; v[2]=0xe0; v[5]=v[6]=76;
    v[7]=0x53; v[9]=0x30; v[12]=v[13]=76;
    return 0;
}
void rx_network_poll(void) {}
int rx_network_take_request(char *cmd, u32 *ticket)
{
    if (!pending_valid) return 0;
    strcpy(cmd, pending); *ticket = 1; pending_valid = 0; return 1;
}
unsigned char *rx_network_frame(void) { return response; }
void rx_network_reply(u32 ticket, u32 n) { assert(ticket == 1); response_bytes = n; }
int rx_network_queue_key(char key) { queued_key = key; return 0; }
u32 rx_network_link_mbps(void) { return 1000; }
u32 rx_network_log_overruns(void) { return 0; }
void test_reset(void)
{
    static int mapped;
    if (!mapped) {
        void *p = mmap((void *)(UINTPTR)CAPTURE_DATA_BASE, 8U*1024U*1024U,
                       PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0);
        assert(p == (void *)(UINTPTR)CAPTURE_DATA_BASE); mapped=1;
    }
    memset(&device,0,sizeof(device));
    reset_result=change_config=auto_complete=0; dma_result=DMA_9361_PENDING;
    capture_store_init(&device,&gpio,rearm,config);
}
unsigned test_rpc(const char *cmd, const void **reply)
{
    unsigned attempts;
    if (strlen(cmd) >= sizeof(pending)) return 0;
    strcpy(pending,cmd); pending_valid=1; response_bytes=0;
    /* Model the real foreground loop: short captures temporarily defer
     * network commands until their final DMA packets have completed. */
    for (attempts=0; attempts<16U && pending_valid; ++attempts) rx_control_poll();
    *reply=response; return response_bytes;
}
void test_auto_complete(void) { auto_complete=1; dma_result=DMA_9361_PENDING; }
#ifdef TEST_MAIN
int main(void)
{
    capture_layout l;
    unsigned char block[64];
    char id[17], json[2048];
    const void *reply;
    assert(capture_make_layout(0,&l));
    assert(capture_make_layout(CAPTURE_MAX_BYTES+32768U,&l));
    assert(capture_make_layout(1,&l));
    assert(!capture_make_layout(CAPTURE_MAX_BYTES,&l));
    assert(l.packets==32640 && l.descriptor_bytes==2088960 && l.tuples==133693440);
    assert(l.duration_us==8704000 && l.timeout_us==28112000);
    assert(capture_crc32("123456789",9)==0xcbf43926U);
    test_reset();
    assert(!capture_store_begin(8U*1024U*1024U));
    assert(capture_store_begin(32768)==DMA_9361_ERR_STATE);
    assert(capture_store_read(capture_store.id,0,8,block));
    dma_result=0; capture_store_poll();
    assert(capture_store.state==CAP_STORE_READY && capture_store.reset_verified);
    strcpy(id,capture_store.id);
    assert(!capture_store_read(id,0,sizeof(block),block));
    assert(((s16 *)block)[0]==-2048 && ((s16 *)block)[3]==-2045);
    assert(!capture_store_read(id,CAPTURE_CHUNK_BYTES,sizeof(block),block));
    assert(((s16 *)block)[0]==-2016); /* detect repeated/wrong source offsets */
    assert(capture_store_read("bad",0,8,block));
    assert(capture_store_read(id,1,8,block));
    assert(capture_store_read(id,0,9,block));
    assert(capture_store_read(id,0xfffffff8U,8,block));
    assert(capture_store_read(id,8U*1024U*1024U-8U,16,block));
    assert(capture_store_begin(32768)==DMA_9361_ERR_STATE);
    assert(capture_store_release("bad"));
    assert(!capture_store_release(id));
    dma_result=DMA_9361_PENDING;
    assert(!capture_store_begin(32768));
    change_config=1; dma_result=0; capture_store_poll();
    assert(capture_store.state==CAP_STORE_FAILED && capture_store.result==DMA_9361_ERR_CONFIG);
    test_reset(); assert(!capture_store_begin(32768));
    clock_ticks += capture_store.layout.timeout_us+1U; capture_store_poll();
    assert(capture_store.result==DMA_9361_ERR_TIMEOUT && capture_store.state==CAP_STORE_FAILED);
    test_reset(); assert(!capture_store_begin(32768)); capture_store_abort();
    assert(capture_store.result==DMA_9361_ERR_ABORTED);
    test_reset(); assert(!capture_store_begin(32768)); reset_result=-1; dma_result=0;
    capture_store_poll();
    assert(capture_store.state==CAP_STORE_FAILED && !capture_store.reset_verified);
    assert(capture_store_begin(32768)==DMA_9361_ERR_NOT_READY);
    test_reset(); assert(!capture_store_begin(CAPTURE_MAX_BYTES));
    dma_result=0; capture_store_poll();
    assert(capture_store.received_bytes==CAPTURE_MAX_BYTES);
    assert(capture_store_json(json,sizeof(json))>0);
    assert(strstr(json,"1069547520") && strstr(json,"133693440"));
    assert(test_rpc("STATUS",&reply)>0 && strstr(reply,"\"link_mbps\":1000"));
    assert(test_rpc("READ nope 0 262152",&reply)>0 && strstr(reply,"\"ok\":false"));
    assert(test_rpc("CAPTURE 4294967296",&reply)>0 && strstr(reply,"\"ok\":false"));
    assert(test_rpc("CAPTURE -1",&reply)>0 && strstr(reply,"\"ok\":false"));
    assert(test_rpc("KEY s",&reply)>0 && queued_key=='s');
    puts("PASS: maximum layout, CRC32, capture ownership, timeout, abort, RF/reset failures and command bounds");
    return 0;
}
#endif
