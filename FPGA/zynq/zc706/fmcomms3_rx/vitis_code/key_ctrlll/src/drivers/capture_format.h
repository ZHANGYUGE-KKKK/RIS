#ifndef CAPTURE_FORMAT_H
#define CAPTURE_FORMAT_H
#include <stdint.h>
#define CAPTURE_BD_BASE UINT32_C(0x00000000)
#define CAPTURE_DATA_BASE UINT32_C(0x00400000)
#define CAPTURE_MAX_BYTES UINT32_C(0x7FC00000)
#define CAPTURE_PACKET_BYTES UINT32_C(32768)
#define CAPTURE_TUPLE_BYTES UINT32_C(8)
#define CAPTURE_SAMPLE_RATE UINT32_C(15360000)
#define CAPTURE_CHUNK_BYTES UINT32_C(262144)
typedef struct {
    uint32_t bytes, packets, descriptor_bytes, tuples, duration_us, timeout_us;
} capture_layout;
/* Length must contain whole existing 4096-tuple AXIS packets. */
int capture_make_layout(uint32_t bytes, capture_layout *layout);
uint32_t capture_crc32(const void *data, uint32_t bytes);
#endif
