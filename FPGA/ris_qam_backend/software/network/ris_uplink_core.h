#ifndef RIS_UPLINK_CORE_H
#define RIS_UPLINK_CORE_H
#include <stddef.h>
#include <stdint.h>

#define RIS_UPLINK_HEADER_BYTES 24u
#define RIS_UPLINK_MAX_PAYLOAD 1024u
#define RIS_UPLINK_MAX_DATAGRAM (RIS_UPLINK_HEADER_BYTES + RIS_UPLINK_MAX_PAYLOAD)
#define RIS_UPLINK_QUEUE_DEPTH 8u
#define RIS_UPLINK_JSON_BYTES 2400u

typedef struct {
    uint32_t sequence, sender_ms;
    uint16_t length;
    uint8_t payload_type;
    uint8_t payload[RIS_UPLINK_MAX_PAYLOAD];
} ris_uplink_record;

typedef struct {
    uint32_t datagrams, accepted, invalid, source_rejected;
    uint32_t queue_dropped, forwarded, subscribers, disconnects;
    unsigned head, count;
    ris_uplink_record records[RIS_UPLINK_QUEUE_DEPTH];
} ris_uplink_queue;

void ris_uplink_queue_init(ris_uplink_queue *queue);
/* source_ok must include receiving netif, destination IP, source IP and port. */
int ris_uplink_ingest(ris_uplink_queue *queue, const uint8_t *data,
                      size_t length, int source_ok);
const ris_uplink_record *ris_uplink_peek(const ris_uplink_queue *queue);
/* Call only after tcp_write(..., COPY) accepted an entire JSON line. */
void ris_uplink_forwarded(ris_uplink_queue *queue);
size_t ris_uplink_record_json(const ris_uplink_record *record,
                              char *output, size_t capacity);
size_t ris_uplink_stats_json(const ris_uplink_queue *queue, int ready,
                             int link_up, int init_error,
                             char *output, size_t capacity);
#endif
