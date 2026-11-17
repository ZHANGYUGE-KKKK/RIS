#include "capture_format.h"
#include <stddef.h>
int capture_make_layout(uint32_t bytes, capture_layout *p)
{
    uint64_t duration;
    if (!p || !bytes || bytes > CAPTURE_MAX_BYTES || bytes % CAPTURE_PACKET_BYTES)
        return -1;
    p->bytes = bytes;
    p->packets = bytes / CAPTURE_PACKET_BYTES;
    p->descriptor_bytes = p->packets * 64U;
    p->tuples = bytes / CAPTURE_TUPLE_BYTES;
    if (p->descriptor_bytes > CAPTURE_DATA_BASE - CAPTURE_BD_BASE) return -1;
    duration = ((uint64_t)p->tuples * 1000000U + CAPTURE_SAMPLE_RATE - 1U) /
               CAPTURE_SAMPLE_RATE;
    p->duration_us = (uint32_t)duration;
    p->timeout_us = (uint32_t)(duration * 3U + 2000000U);
    return 0;
}
uint32_t capture_crc32(const void *data, uint32_t bytes)
{
    static uint32_t table[256];
    static int initialized;
    const unsigned char *p = data;
    uint32_t crc = UINT32_C(0xFFFFFFFF), i, bit;
    if (!initialized) {
        for (i = 0; i < 256U; ++i) {
            uint32_t v = i;
            for (bit = 0; bit < 8U; ++bit)
                v = (v >> 1) ^ ((v & 1U) ? UINT32_C(0xEDB88320) : 0U);
            table[i] = v;
        }
        initialized = 1;
    }
    for (i = 0; i < bytes; ++i) crc = table[(crc ^ p[i]) & 255U] ^ (crc >> 8);
    return crc ^ UINT32_C(0xFFFFFFFF);
}
