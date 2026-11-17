#include "rx_uplink_packet.h"
#include <string.h>

static void put_be32(uint8_t *p, uint32_t value)
{
    p[0] = (uint8_t)(value >> 24);
    p[1] = (uint8_t)(value >> 16);
    p[2] = (uint8_t)(value >> 8);
    p[3] = (uint8_t)value;
}

static uint32_t crc_bytes(uint32_t crc, const uint8_t *data, size_t length)
{
    for (size_t i = 0; i < length; ++i) {
        crc ^= data[i];
        for (unsigned bit = 0; bit < 8U; ++bit)
            crc = (crc >> 1) ^ ((crc & 1U) ? 0xedb88320U : 0U);
    }
    return crc;
}

size_t rx_uplink_encode(uint8_t *frame, size_t capacity, uint32_t sequence,
                        uint32_t sender_ms, unsigned type,
                        const uint8_t *payload, size_t length)
{
    uint32_t crc;

    if (!frame || type > 1U || length > RX_UPLINK_MAX_PAYLOAD ||
        capacity < RX_UPLINK_HEADER_BYTES + length || (length && !payload))
        return 0;
    memcpy(frame, "RUP1", 4U);
    frame[4] = 1U;
    frame[5] = RX_UPLINK_HEADER_BYTES;
    frame[6] = (uint8_t)type;
    frame[7] = 0U;
    put_be32(frame + 8U, sequence);
    frame[12] = (uint8_t)(length >> 8);
    frame[13] = (uint8_t)length;
    frame[14] = frame[15] = 0U;
    put_be32(frame + 16U, sender_ms);
    crc = crc_bytes(0xffffffffU, frame, 20U);
    put_be32(frame + 20U, crc_bytes(crc, payload, length) ^ 0xffffffffU);
    if (length) memcpy(frame + RX_UPLINK_HEADER_BYTES, payload, length);
    return RX_UPLINK_HEADER_BYTES + length;
}
