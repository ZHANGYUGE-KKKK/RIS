#include "ris_uplink_core.h"
#include <stdio.h>
#include <string.h>

static uint16_t be16(const uint8_t *p)
{ return (uint16_t)((uint16_t)p[0] << 8 | p[1]); }
static uint32_t be32(const uint8_t *p)
{ return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 |
         (uint32_t)p[2] << 8 | p[3]; }
static uint32_t crc_bytes(uint32_t crc, const uint8_t *data, size_t n)
{
    size_t i;
    for (i=0; i<n; ++i) {
        unsigned bit;
        crc ^= data[i];
        for (bit=0; bit<8; ++bit)
            crc=(crc>>1) ^ ((crc&1u) ? 0xedb88320u : 0u);
    }
    return crc;
}
void ris_uplink_queue_init(ris_uplink_queue *q) { memset(q,0,sizeof(*q)); }
int ris_uplink_ingest(ris_uplink_queue *q, const uint8_t *p, size_t n,
                      int source_ok)
{
    uint16_t length;
    uint32_t crc;
    ris_uplink_record *record;
    ++q->datagrams;
    if (!source_ok) { ++q->source_rejected; return 0; }
    if (!p || n<RIS_UPLINK_HEADER_BYTES || n>RIS_UPLINK_MAX_DATAGRAM)
        goto invalid;
    length=be16(p+12);
    if (memcmp(p,"RUP1",4) || p[4]!=1 || p[5]!=RIS_UPLINK_HEADER_BYTES ||
        p[6]>1 || p[7] || be16(p+14) || length>RIS_UPLINK_MAX_PAYLOAD ||
        n!=RIS_UPLINK_HEADER_BYTES+(size_t)length) goto invalid;
    crc=crc_bytes(0xffffffffu,p,20);
    crc=crc_bytes(crc,p+RIS_UPLINK_HEADER_BYTES,length)^0xffffffffu;
    if (crc!=be32(p+20)) goto invalid;
    if (q->count==RIS_UPLINK_QUEUE_DEPTH) { ++q->queue_dropped; return 0; }
    record=&q->records[(q->head+q->count)%RIS_UPLINK_QUEUE_DEPTH];
    record->sequence=be32(p+8); record->sender_ms=be32(p+16);
    record->length=length; record->payload_type=p[6];
    memcpy(record->payload,p+RIS_UPLINK_HEADER_BYTES,length);
    ++q->count; ++q->accepted;
    return 1;
invalid:
    ++q->invalid;
    return 0;
}
const ris_uplink_record *ris_uplink_peek(const ris_uplink_queue *q)
{ return q->count ? &q->records[q->head] : NULL; }
void ris_uplink_forwarded(ris_uplink_queue *q)
{
    if (!q->count) return;
    q->head=(q->head+1u)%RIS_UPLINK_QUEUE_DEPTH;
    --q->count; ++q->forwarded;
}
size_t ris_uplink_record_json(const ris_uplink_record *r, char *out, size_t cap)
{
    static const char hex[]="0123456789abcdef";
    size_t n,i;
    int written;
    if (!r || !out || !cap || r->length>RIS_UPLINK_MAX_PAYLOAD) return 0;
    written=snprintf(out,cap,"{\"type\":\"uplink\",\"protocol\":\"RUP1\","
        "\"sequence\":%lu,\"sender_ms\":%lu,\"payload_type\":%u,"
        "\"length\":%u,\"payload_hex\":\"",
        (unsigned long)r->sequence,(unsigned long)r->sender_ms,
        (unsigned)r->payload_type,(unsigned)r->length);
    if (written<0 || (size_t)written>=cap) return 0;
    n=(size_t)written;
    if ((size_t)r->length*2u+4u>cap-n) return 0;
    for (i=0;i<r->length;++i) {
        out[n++]=hex[r->payload[i]>>4]; out[n++]=hex[r->payload[i]&15u];
    }
    out[n++]='"'; out[n++]='}'; out[n++]='\n'; out[n]=0;
    return n;
}
size_t ris_uplink_stats_json(const ris_uplink_queue *q, int ready,
                             int link_up, int init_error, char *out, size_t cap)
{
    int n=snprintf(out,cap,"{\"type\":\"uplink_status\",\"protocol\":\"RUP1\","
        "\"ready\":%s,\"link_up\":%s,\"init_error\":%d,"
        "\"datagrams\":%lu,\"accepted\":%lu,\"invalid\":%lu,"
        "\"source_rejected\":%lu,\"queue_dropped\":%lu,"
        "\"forwarded\":%lu,\"queued\":%u,\"queue_capacity\":%u,"
        "\"subscribers\":%lu,\"disconnects\":%lu}\n",
        ready ? "true":"false",link_up ? "true":"false",init_error,
        (unsigned long)q->datagrams,(unsigned long)q->accepted,
        (unsigned long)q->invalid,(unsigned long)q->source_rejected,
        (unsigned long)q->queue_dropped,(unsigned long)q->forwarded,
        q->count,RIS_UPLINK_QUEUE_DEPTH,(unsigned long)q->subscribers,
        (unsigned long)q->disconnects);
    return n>=0 && (size_t)n<cap ? (size_t)n : 0;
}
