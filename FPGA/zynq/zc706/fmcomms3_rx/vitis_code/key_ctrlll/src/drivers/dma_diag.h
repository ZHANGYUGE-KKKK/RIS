#ifndef DMA_DIAG_H
#define DMA_DIAG_H
#include "xil_types.h"

#define DMA_DIAG_VERSION 1U
#define DMA_DIAG_FLAGS   0x001U
#define DMA_DIAG_LENGTH  0x002U
#define DMA_DIAG_ID      0x004U
#define DMA_DIAG_BUFFER  0x008U
#define DMA_DIAG_NEXT    0x010U
#define DMA_DIAG_CONTROL 0x020U
#define DMA_DIAG_HWERROR 0x040U

enum dma_diag_stage { DMA_DIAG_NONE, DMA_DIAG_PREPARE,
    DMA_DIAG_SUBMIT, DMA_DIAG_RECEIVE, DMA_DIAG_DONE };
typedef struct {
    u32 stage, issues, index, address, expected_next, expected_buffer, max_length;
    u32 raw[16], repeat[16], changed_words;
    u32 control, status, current, tail;
    u32 prepared_checked, submitted_checked, completed_checked;
    int result;
} dma_diag_record;

/* Raw BD layout is the AXI DMA non-multichannel, 32-bit-address layout.
 * Stage RECEIVE checks one complete 32-KiB packet per descriptor.
 * Unlike XAxiDma_BdGetSts, raw[7] retains the actual-length field. */
u32 dma_diag_check(const u32 raw[16], u32 expected_next, u32 expected_buffer,
                  u32 index, u32 bytes, u32 max_length, u32 receiving);
void dma_diag_print(const dma_diag_record *record, const char *tag);
#endif
