#include "capture_debug.h"
#include "capture_format.h"
#include "xpseudo_asm.h"
#include "xil_printf.h"
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

static u32 samples[3][CAPTURE_DEBUG_PROBE_BYTES/4U] __attribute__((aligned(64)));

static void add_probe(capture_debug_report *r, u32 offset)
{
    u32 i;
    if (r->bytes < CAPTURE_DEBUG_PROBE_BYTES || offset > r->bytes - CAPTURE_DEBUG_PROBE_BYTES)
        return;
    offset &= ~(CAPTURE_DEBUG_PROBE_BYTES - 1U);
    for (i = 0U; i < r->count; ++i) if (r->probe[i].offset == offset) return;
    if (r->count < CAPTURE_DEBUG_MAX_PROBES) r->probe[r->count++].offset = offset;
}

void capture_debug_begin(capture_debug_report *r, u32 base, u32 bytes)
{
    static const u32 offsets[] = {
        0U, 0x80000U, 0xA5000U, 0xE4000U, 0x100000U, 0x164000U,
        0x180000U, 0x200000U, 0x300000U, 0xD84000U, 0x21C4000U };
    u32 i;
    memset(r, 0, sizeof(*r));
    r->version = CAPTURE_DEBUG_VERSION; r->base = base; r->bytes = bytes;
    for (i = 0U; i < sizeof(offsets)/sizeof(offsets[0]); ++i) add_probe(r, offsets[i]);
    add_probe(r, bytes/4U); add_probe(r, bytes/2U); add_probe(r, bytes/4U*3U);
    if (bytes >= CAPTURE_DEBUG_PROBE_BYTES) add_probe(r, bytes-CAPTURE_DEBUG_PROBE_BYTES);
}

void capture_debug_measure(capture_debug_report *r, u32 phase)
{
    u32 i, pass, word;
    if (phase >= CAPTURE_DEBUG_PHASES || r->version != CAPTURE_DEBUG_VERSION) return;
    for (i = 0U; i < r->count; ++i) {
        capture_debug_probe *p = &r->probe[i];
        capture_debug_measurement *m = &p->phase[phase];
        const volatile u32 *source = (const volatile u32 *)(UINTPTR)(r->base+p->offset);
        memset(m, 0, sizeof(*m)); m->first_bad_offset = 0xFFFFFFFFU;
        for (pass = 0U; pass < 2U; ++pass) {
            dsb();
            for (word = 0U; word < CAPTURE_DEBUG_PROBE_BYTES/4U; ++word)
                samples[pass][word] = source[word];
            dsb();
        }
        memcpy(samples[2], (const void *)(UINTPTR)(r->base+p->offset), CAPTURE_DEBUG_PROBE_BYTES);
        dsb();
        for (pass = 0U; pass < 3U; ++pass) m->crc[pass] = capture_crc32(samples[pass], CAPTURE_DEBUG_PROBE_BYTES);
        if (m->crc[0] != m->crc[1]) r->unstable |= 1U << i;
        if (m->crc[0] != m->crc[2]) r->copy_mismatch |= 1U << i;
        if (phase == 1U && m->crc[0] != p->phase[0].crc[0]) r->changed_dma |= 1U << i;
        if (phase == 2U && m->crc[0] != p->phase[1].crc[0]) r->changed_pl |= 1U << i;
        for (word = 0U; word < CAPTURE_DEBUG_PROBE_BYTES/4U; ++word) {
            u32 half;
            for (half = 0U; half < 2U; ++half) {
                u32 value = (samples[0][word] >> (half*16U)) & 0xFFFFU;
                if (value > 0x07FFU && value < 0xF800U) {
                    ++m->bad[(word*2U+half) & 3U];
                    if (m->first_bad_offset == 0xFFFFFFFFU) {
                        m->first_bad_offset = p->offset + word*4U + half*2U;
                        m->first_bad_value = value;
                    }
                }
            }
        }
    }
    r->phases |= 1U << phase;
}

void capture_debug_print(const capture_debug_report *r, const char *id)
{
    u32 i, phase;
    xil_printf("RXDBG CAPTURE id=%s version=%u phases=%x probes=%u sampled_bytes=%u total_bytes=%u (sampled only)\r\n",
        id, r->version, r->phases, r->count, r->count*CAPTURE_DEBUG_PROBE_BYTES, r->bytes);
    xil_printf("RXDBG SUMMARY changed_dma=%04x changed_pl=%04x unstable=%04x memcpy_diff=%04x\r\n",
        r->changed_dma, r->changed_pl, r->unstable, r->copy_mismatch);
    for (i = 0U; i < r->count; ++i) {
        xil_printf("RXDBG PROBE %u offset=%08x address=%08x\r\n", i, r->probe[i].offset, r->base+r->probe[i].offset);
        for (phase = 0U; phase < CAPTURE_DEBUG_PHASES; ++phase) {
            const capture_debug_measurement *m = &r->probe[i].phase[phase];
            if (!(r->phases & (1U << phase))) continue;
            xil_printf("RXDBG phase=%u CRC=%08x/%08x/%08x bad_I1Q1I2Q2=%u/%u/%u/%u first_offset=%08x raw=%04x\r\n",
                phase, m->crc[0], m->crc[1], m->crc[2], m->bad[0], m->bad[1], m->bad[2], m->bad[3],
                m->first_bad_offset, m->first_bad_value);
        }
    }
    xil_printf("RXDBG phase 0=DMA_done 1=DMA_reset 2=PL_rearm; CRC=A/B/memcpy; zero masks do not certify the whole buffer\r\n");
}

static void append(char *out, unsigned capacity, unsigned *used, const char *fmt, ...)
    __attribute__((format(printf, 4, 5)));
static void append(char *out, unsigned capacity, unsigned *used, const char *fmt, ...)
{
    int n;
    va_list args;
    if (*used >= capacity) return;
    va_start(args, fmt); n = vsnprintf(out+*used, capacity-*used, fmt, args); va_end(args);
    if (n < 0 || (unsigned)n >= capacity-*used) *used = capacity;
    else *used += (unsigned)n;
}

int capture_debug_json(const capture_debug_report *r, const char *id, char *out, unsigned capacity)
{
    unsigned used = 0U;
    u32 i, phase;
    append(out, capacity, &used,
        "{\"ok\":true,\"capture_id\":\"%s\",\"version\":%u,\"sampled_only\":true,\"base\":%u,\"bytes\":%u,"
        "\"phases\":%u,\"changed_dma\":%u,\"changed_pl\":%u,\"unstable\":%u,\"memcpy_diff\":%u,\"probes\":[",
        id, (unsigned)r->version, (unsigned)r->base, (unsigned)r->bytes, (unsigned)r->phases, (unsigned)r->changed_dma, (unsigned)r->changed_pl, (unsigned)r->unstable, (unsigned)r->copy_mismatch);
    for (i = 0U; i < r->count; ++i) {
        append(out, capacity, &used, "%s{\"offset\":%u,\"length\":4096,\"measurements\":[", i ? "," : "", (unsigned)r->probe[i].offset);
        for (phase = 0U; phase < CAPTURE_DEBUG_PHASES; ++phase) {
            const capture_debug_measurement *m = &r->probe[i].phase[phase];
            append(out, capacity, &used, "%s[%u,%u,%u,%u,%u,%u,%u,%u,%u]", phase ? "," : "",
                (unsigned)m->crc[0], (unsigned)m->crc[1], (unsigned)m->crc[2], (unsigned)m->bad[0], (unsigned)m->bad[1], (unsigned)m->bad[2], (unsigned)m->bad[3], (unsigned)m->first_bad_offset, (unsigned)m->first_bad_value);
        }
        append(out, capacity, &used, "]}");
    }
    append(out, capacity, &used, "]}\n");
    return used < capacity ? (int)used : -1;
}
