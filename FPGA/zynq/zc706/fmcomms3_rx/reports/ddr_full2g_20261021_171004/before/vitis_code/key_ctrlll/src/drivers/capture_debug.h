#ifndef CAPTURE_DEBUG_H
#define CAPTURE_DEBUG_H
#include "xil_types.h"

#define CAPTURE_DEBUG_VERSION 1U
#define CAPTURE_DEBUG_MAX_PROBES 16U
#define CAPTURE_DEBUG_PROBE_BYTES 4096U
#define CAPTURE_DEBUG_PHASES 3U
typedef struct {
    u32 crc[3]; /* volatile read A, volatile read B, memcpy */
    u32 bad[4], first_bad_offset, first_bad_value;
} capture_debug_measurement;
typedef struct {
    u32 offset;
    capture_debug_measurement phase[CAPTURE_DEBUG_PHASES];
} capture_debug_probe;
typedef struct {
    u32 version, base, bytes, count, phases;
    u32 changed_dma, changed_pl, unstable, copy_mismatch;
    capture_debug_probe probe[CAPTURE_DEBUG_MAX_PROBES];
} capture_debug_report;

/* Non-destructive bounded samples only: never a full-buffer validity verdict.
 * Phase 0=DMA completed; 1=DMA reset only; 2=full capture rearm completed.
 * Call only after DMA has finished writing the entire owned payload. */
void capture_debug_begin(capture_debug_report *report, u32 base, u32 bytes);
void capture_debug_measure(capture_debug_report *report, u32 phase);
void capture_debug_print(const capture_debug_report *report, const char *id);
int capture_debug_json(const capture_debug_report *report, const char *id,
                       char *out, unsigned capacity);
#endif
