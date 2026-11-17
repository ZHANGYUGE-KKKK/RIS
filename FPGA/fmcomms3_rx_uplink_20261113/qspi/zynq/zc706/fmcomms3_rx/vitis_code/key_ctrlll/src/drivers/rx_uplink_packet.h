#ifndef RX_UPLINK_PACKET_H
#define RX_UPLINK_PACKET_H

#include <stddef.h>
#include <stdint.h>

#define RX_UPLINK_HEADER_BYTES 24U
#define RX_UPLINK_MAX_PAYLOAD 1024U

/* Encode one RUP1 frame. The output buffer must not overlap the payload. */
size_t rx_uplink_encode(uint8_t *frame, size_t capacity, uint32_t sequence,
                        uint32_t sender_ms, unsigned type,
                        const uint8_t *payload, size_t length);

#endif
