#include "capture_store.h"
#include "../ad_config/rf_profile.h"
#include <stdio.h>
#include <string.h>
capture_store_record capture_store;
static dma_9361_device *dma;
static gpio_9361_device *gpio;
static int (*rearm_capture)(void);
static int (*read_configuration)(u8 *);
static int preparing;

void capture_store_init(dma_9361_device *d, gpio_9361_device *g,
                        int (*rearm)(void), int (*read_rf)(u8 *))
{
    dma = d; gpio = g; rearm_capture = rearm; read_configuration = read_rf;
    memset(&capture_store, 0, sizeof(capture_store));
    capture_store.state = CAP_STORE_EMPTY;
    capture_store.reset_verified = 1;
}
static void finish(int result)
{
    XTime now;
    int reset;
    XTime_GetTime(&now);
    capture_store.elapsed_us = (u32)((now - capture_store.start) * 1000000U / COUNTS_PER_SECOND);
    capture_store.completed_packets = dma->completed_packets;
    capture_store.received_bytes = dma->received_bytes;
    capture_store.dma_status = dma->last_dma_status;
    capture_store.bd_status = dma->last_bd_status;
    capture_store.capture_status = dma->last_capture_status;
    (void)gpio_9361_get_status(gpio, &capture_store.tail_status);
    if (!result && (capture_store.received_bytes != capture_store.layout.bytes ||
        capture_store.completed_packets != capture_store.layout.packets))
        result = DMA_9361_ERR_PACKET;
    if (!result && (read_configuration(capture_store.rf_after) ||
        memcmp(capture_store.rf_before, capture_store.rf_after, CAPTURE_RF_REGS)))
        result = DMA_9361_ERR_CONFIG;
    reset = rearm_capture();
    capture_store.reset_verified = reset == 0;
    if (reset) result = DMA_9361_ERR_RESET_REQUIRED;
    capture_store.result = result;
    capture_store.state = result ? CAP_STORE_FAILED : CAP_STORE_READY;
}
int capture_store_begin(u32 bytes)
{
    capture_layout layout;
    XTime now;
    int result;
    if (!dma || capture_store.state == CAP_STORE_UNAVAILABLE) return DMA_9361_ERR_NOT_READY;
    if (capture_store.state == CAP_STORE_CAPTURING ||
        capture_store.state == CAP_STORE_READY) return DMA_9361_ERR_STATE;
    if (!capture_store.reset_verified) return DMA_9361_ERR_NOT_READY;
    if (capture_make_layout(bytes, &layout)) return DMA_9361_ERR_ARGUMENT;
    memset(&capture_store, 0, sizeof(capture_store));
    capture_store.layout = layout;
    capture_store.state = CAP_STORE_CAPTURING;
    capture_store.result = DMA_9361_PENDING;
    preparing = 1;
    XTime_GetTime(&now);
    snprintf(capture_store.id, sizeof(capture_store.id), "%08x%08x",
             (unsigned)(now >> 32), (unsigned)now);
    capture_store.start = now;
    result = read_configuration(capture_store.rf_before);
    if (!result) result = dma_9361_prepare(dma, CAPTURE_BD_BASE,
                                           CAPTURE_DATA_BASE, layout.packets);
    if (!result) result = dma_9361_start(dma);
    XTime_GetTime(&capture_store.start); /* acquisition timeout excludes prepare */
    preparing = 0;
    if (result) finish(result);
    return result;
}
void capture_store_poll(void)
{
    XTime now;
    int result;
    if (preparing || capture_store.state != CAP_STORE_CAPTURING) return;
    result = dma_9361_poll(dma);
    capture_store.completed_packets = dma->completed_packets;
    capture_store.received_bytes = dma->received_bytes;
    if (result != DMA_9361_PENDING) { finish(result); return; }
    XTime_GetTime(&now);
    if (now - capture_store.start >= (XTime)capture_store.layout.timeout_us *
                                    COUNTS_PER_SECOND / 1000000U)
        finish(DMA_9361_ERR_TIMEOUT);
}
void capture_store_abort(void)
{
    if (capture_store.state == CAP_STORE_CAPTURING && !preparing)
        finish(DMA_9361_ERR_ABORTED);
}
int capture_store_release(const char *id)
{
    if (capture_store.state != CAP_STORE_READY || strcmp(capture_store.id, id)) return -1;
    capture_store.state = CAP_STORE_EMPTY;
    return 0;
}
int capture_store_read(const char *id, u32 offset, u32 bytes, void *dst)
{
    if (capture_store.state != CAP_STORE_READY || strcmp(capture_store.id, id) ||
        !bytes || bytes > CAPTURE_CHUNK_BYTES || (offset | bytes) % CAPTURE_TUPLE_BYTES ||
        offset > capture_store.layout.bytes || bytes > capture_store.layout.bytes - offset)
        return -1;
    memcpy(dst, (const void *)(UINTPTR)(CAPTURE_DATA_BASE + offset), bytes);
    return 0;
}
int capture_store_keys_blocked(void)
{ return capture_store.state == CAP_STORE_CAPTURING; }
int capture_store_urgent(void)
{
    return capture_store.state == CAP_STORE_CAPTURING && !preparing &&
        capture_store.layout.packets - capture_store.completed_packets <= 8U;
}
const char *capture_store_state_name(void)
{
    static const char *const names[] = {"unavailable", "empty", "capturing", "ready", "failed"};
    return names[capture_store.state];
}
int capture_store_json(char *b, unsigned capacity)
{
    return snprintf(b, capacity,
        "{\"ok\":true,\"protocol\":1,\"state\":\"%s\",\"capture_id\":\"%s\","
        "\"bytes\":%u,\"received_bytes\":%u,\"tuples\":%u,\"packets\":%u,\"completed_packets\":%u,"
        "\"sample_rate_hz\":%u,\"rx_lo_config_hz\":%u,\"rf_profile\":\"%s\",\"channels\":2,"
        "\"order\":[\"I1\",\"Q1\",\"I2\",\"Q2\"],\"dtype\":\"int16\",\"byte_order\":\"little\","
        "\"valid_bits\":12,\"data_base\":%u,\"max_bytes\":%u,\"chunk_bytes\":%u,"
        "\"duration_us\":%u,\"elapsed_us\":%u,\"result\":%d,\"reset_verified\":%d,"
        "\"dma_status\":%u,\"bd_status\":%u,\"capture_status\":%u,\"tail_status\":%u,"
        "\"rf_regs\":[6,16,250,251,253,265,268,1012,1013,1014,3,4,688,693],"
        "\"rf_before\":[%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u],"
        "\"rf_after\":[%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u]}\n",
        capture_store_state_name(), capture_store.id,
        (unsigned)capture_store.layout.bytes, (unsigned)capture_store.received_bytes,
        (unsigned)capture_store.layout.tuples, (unsigned)capture_store.layout.packets,
        (unsigned)capture_store.completed_packets, (unsigned)CAPTURE_SAMPLE_RATE,
        (unsigned)RX_RF_LO_HZ, RX_RF_PROFILE_NAME,
        (unsigned)CAPTURE_DATA_BASE, (unsigned)CAPTURE_MAX_BYTES, (unsigned)CAPTURE_CHUNK_BYTES,
        (unsigned)capture_store.layout.duration_us, (unsigned)capture_store.elapsed_us,
        capture_store.result, capture_store.reset_verified,
        (unsigned)capture_store.dma_status,(unsigned)capture_store.bd_status,
        (unsigned)capture_store.capture_status,(unsigned)capture_store.tail_status,
        capture_store.rf_before[0],capture_store.rf_before[1],capture_store.rf_before[2],capture_store.rf_before[3],
        capture_store.rf_before[4],capture_store.rf_before[5],capture_store.rf_before[6],capture_store.rf_before[7],
        capture_store.rf_before[8],capture_store.rf_before[9],capture_store.rf_before[10],capture_store.rf_before[11],
        capture_store.rf_before[12],capture_store.rf_before[13],
        capture_store.rf_after[0],capture_store.rf_after[1],capture_store.rf_after[2],capture_store.rf_after[3],
        capture_store.rf_after[4],capture_store.rf_after[5],capture_store.rf_after[6],capture_store.rf_after[7],
        capture_store.rf_after[8],capture_store.rf_after[9],capture_store.rf_after[10],capture_store.rf_after[11],
        capture_store.rf_after[12],capture_store.rf_after[13]);
}
